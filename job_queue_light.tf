resource "aws_ecr_repository" "job_worker_light" {
  name = "globalbibletools-job-worker-light"
}
data "aws_ecr_lifecycle_policy_document" "job_worker_light" {
  rule {
    priority    = 1
    description = "Removes all but the last three created images"

    selection {
      tag_status   = "any"
      count_type   = "imageCountMoreThan"
      count_number = 3
    }

    action {
      type = "expire"
    }
  }
}
resource "aws_ecr_lifecycle_policy" "job_worker_light" {
  repository = aws_ecr_repository.job_worker_light.name
  policy     = data.aws_ecr_lifecycle_policy_document.job_worker_light.json
}
data "aws_ecr_image" "job_worker_light_latest" {
  repository_name = aws_ecr_repository.job_worker_light.name
  image_tag       = "latest"
}

resource "aws_cloudwatch_log_group" "job_worker_light_lambda" {
  name = "/aws/lambda/job_worker_light"
}

resource "aws_iam_role" "job_worker_light_lambda" {
  name               = "job_worker_light_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  path               = "/service-role/"
}
data "aws_iam_policy_document" "job_worker_light_lambda_role" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.job_worker_light_lambda.arn}:*"]
  }
}
resource "aws_iam_policy" "job_worker_light_lambda_role" {
  name   = "AWSLambdaBasicExecutionRole-job-worker-light"
  policy = data.aws_iam_policy_document.job_worker_light_lambda_role.json
  path   = "/service-role/"
}
resource "aws_iam_role_policy_attachment" "job_worker_light_lambda_role" {
  role       = aws_iam_role.job_worker_light_lambda.name
  policy_arn = aws_iam_policy.job_worker_light_lambda_role.arn
}

resource "aws_sqs_queue" "jobs_light" {
  name                       = "jobs_light"
  visibility_timeout_seconds = 600
}

resource "aws_sqs_queue" "jobs_light_dlq" {
  name                      = "jobs_light_dlq"
  message_retention_seconds = 1209600 # 14 days

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.jobs_light.arn]
  })
}

resource "aws_sqs_queue_redrive_policy" "jobs_light" {
  queue_url = aws_sqs_queue.jobs_light.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_light_dlq.arn
    maxReceiveCount     = 1
  })
}

data "aws_iam_policy_document" "job_worker_light" {
  policy_id = "__default_policy_ID"

  statement {
    sid     = "__owner_statement"
    effect  = "Allow"
    actions = ["SQS:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = [aws_sqs_queue.jobs_light.arn]
  }

  statement {
    sid     = "__sender_statement"
    effect  = "Allow"
    actions = ["SQS:SendMessage"]

    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.job_worker_light_lambda.arn,
        aws_iam_user.app_prod.arn
      ]
    }
    resources = [aws_sqs_queue.jobs_light.arn]
  }

  statement {
    sid    = "__receiver_statement"
    effect = "Allow"
    actions = [
      "SQS:ChangeMessageVisibility",
      "SQS:DeleteMessage",
      "SQS:ReceiveMessage",
      "sqs:GetQueueAttributes"
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.job_worker_light_lambda.arn]
    }
    resources = [aws_sqs_queue.jobs_light.arn]
  }
}
resource "aws_sqs_queue_policy" "job_worker_light" {
  queue_url = aws_sqs_queue.jobs_light.id
  policy    = data.aws_iam_policy_document.job_worker_light.json
}

resource "aws_lambda_function" "job_worker_light" {
  function_name = "job_worker_light"
  role          = aws_iam_role.job_worker_light_lambda.arn
  package_type  = "Image"
  image_uri     = data.aws_ecr_image.job_worker_light_latest.image_uri
  memory_size   = 512
  timeout       = 600

  environment {
    variables = {
      DATABASE_URL                 = local.database_url
      JOB_QUEUE_LIGHT_URL                = aws_sqs_queue.jobs_light.url
      EMAIL_FROM                   = "\"Global Bible Tools\" <info@globalbibletools.com>"
      EMAIL_SERVER                 = local.smtp_url
      SERVICE_NAME                 = "job-worker-light"
      GOOGLE_TRANSLATE_CREDENTIALS = google_service_account_key.default.private_key
      ANALYTICS_SPREADSHEET_ID     = var.analytics_sheet_id
      BIBLE_SYSTEMS_API_KEY        = var.global_bible_systems_api_key
      GITHUB_TOKEN                 = var.github_token
      GITHUB_EXPORT_OWNER          = "globalbibletools"
      GITHUB_EXPORT_REPO           = "data"
      GITHUB_EXPORT_BRANCH         = "main"
    }
  }
}
resource "aws_lambda_event_source_mapping" "job_worker_light_sqs_trigger" {
  event_source_arn = aws_sqs_queue.jobs_light.arn
  function_name    = aws_lambda_function.job_worker_light.arn
  batch_size       = 1
}
