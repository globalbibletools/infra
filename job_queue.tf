resource "aws_ecr_repository" "job_worker" {
  name = "globalbibletools-job-worker"
}
data "aws_ecr_lifecycle_policy_document" "job_worker" {
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
resource "aws_ecr_lifecycle_policy" "job_worker" {
  repository = aws_ecr_repository.job_worker.name
  policy     = data.aws_ecr_lifecycle_policy_document.job_worker.json
}
data "aws_ecr_image" "job_worker_latest" {
  repository_name = aws_ecr_repository.job_worker.name
  image_tag       = "latest"
}

resource "aws_cloudwatch_log_group" "job_worker_lambda" {
  name = "/aws/lambda/job_worker"
}

resource "aws_iam_role" "job_worker_lambda" {
  name               = "job_worker_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  path               = "/service-role/"
}
data "aws_iam_policy_document" "job_worker_lambda_role" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.job_worker_lambda.arn}:*"]
  }
}
resource "aws_iam_policy" "job_worker_lambda_role" {
  name   = "AWSLambdaBasicExecutionRole-job-worker"
  policy = data.aws_iam_policy_document.job_worker_lambda_role.json
  path   = "/service-role/"
}
resource "aws_iam_role_policy_attachment" "job_worker_lambda_role" {
  role       = aws_iam_role.job_worker_lambda.name
  policy_arn = aws_iam_policy.job_worker_lambda_role.arn
}

resource "aws_sqs_queue" "jobs" {
  name                       = "jobs"
  visibility_timeout_seconds = 300
}

data "aws_iam_policy_document" "job_worker" {
  policy_id = "__default_policy_ID"

  statement {
    sid     = "__owner_statement"
    effect  = "Allow"
    actions = ["SQS:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = [aws_sqs_queue.jobs.arn]
  }

  statement {
    sid     = "__sender_statement"
    effect  = "Allow"
    actions = ["SQS:SendMessage"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.job_worker_lambda.arn, aws_iam_user.app_prod.arn]
    }
    resources = [aws_sqs_queue.jobs.arn]
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
      identifiers = [aws_iam_role.job_worker_lambda.arn]
    }
    resources = [aws_sqs_queue.jobs.arn]
  }
}
resource "aws_sqs_queue_policy" "job_worker" {
  queue_url = aws_sqs_queue.jobs.id
  policy    = data.aws_iam_policy_document.job_worker.json
}

resource "aws_lambda_function" "job_worker" {
  function_name = "job_worker"
  role          = aws_iam_role.job_worker_lambda.arn
  package_type  = "Image"
  image_uri     = data.aws_ecr_image.job_worker_latest.image_uri
  memory_size   = 512
  timeout       = 300

  environment {
    variables = {
      DATABASE_URL  = local.database_url
      JOB_QUEUE_URL = aws_sqs_queue.jobs.url
      EMAIL_FROM    = "\"Global Bible Tools\" <info@globalbibletools.com>"
      EMAIL_SERVER  = local.smtp_url
    }
  }
}
resource "aws_lambda_event_source_mapping" "job_worker_sqs_trigger" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.job_worker.arn
  batch_size       = 1
}
