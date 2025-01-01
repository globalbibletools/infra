resource "aws_ecr_repository" "github_export_worker" {
  name = "globalbibletools-github-export-worker"
}
data "aws_ecr_image" "github_export_worker_latest" {
  repository_name = aws_ecr_repository.github_export_worker.name
  image_tag       = "latest"
}

resource "aws_cloudwatch_log_group" "github_export_lambda" {
  name = "/aws/lambda/github_export"
}

resource "aws_iam_role" "github_export_lambda" {
  name               = "github_export_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  path               = "/service-role/"
}

data "aws_iam_policy_document" "github_export_lambda_role" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.github_export_lambda.arn}:*"]
  }
}
resource "aws_iam_policy" "github_export_lambda_role" {
  name   = "AWSLambdaBasicExecutionRole-c86916e6-47a5-4873-8cd8-644f0d87cf0f"
  policy = data.aws_iam_policy_document.github_export_lambda_role.json
  path   = "/service-role/"
}

resource "aws_iam_role_policy_attachment" "github_export_lambda_role" {
  role       = aws_iam_role.github_export_lambda.name
  policy_arn = aws_iam_policy.github_export_lambda_role.arn
}


resource "aws_sqs_queue" "github_export" {
  name                        = "github_export.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = 300
}

data "aws_iam_policy_document" "github_export" {
  policy_id = "__default_policy_ID"

  statement {
    sid     = "__owner_statement"
    effect  = "Allow"
    actions = ["SQS:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = [aws_sqs_queue.github_export.arn]
  }

  statement {
    sid     = "__sender_statement"
    effect  = "Allow"
    actions = ["SQS:SendMessage"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.github_export_lambda.arn]
    }
    resources = [aws_sqs_queue.github_export.arn]
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
      identifiers = [aws_iam_role.github_export_lambda.arn]
    }
    resources = [aws_sqs_queue.github_export.arn]
  }
}
resource "aws_sqs_queue_policy" "github_export" {
  queue_url = aws_sqs_queue.github_export.id
  policy    = data.aws_iam_policy_document.github_export.json
}

resource "aws_lambda_function" "github_import" {
  function_name = "github_export"
  role = aws_iam_role.github_export_lambda.arn
  package_type = "Image"
  image_uri = data.aws_ecr_image.github_export_worker_latest.image_uri
  memory_size = 512
  timeout = 300

  environment {
      variables = {
          DATABASE_URL = local.database_url
          GITHUB_EXPORT_QUEUE_URL = aws_sqs_queue.github_export.url
          GITHUB_TOKEN = var.github_token
      }
  }
}

resource "aws_lambda_event_source_mapping" "github_import_sqs_trigger" {
  event_source_arn = aws_sqs_queue.github_export.arn
  function_name    = aws_lambda_function.github_import.arn
  batch_size = 1
}

data "aws_iam_policy_document" "eventbridge_scheduler_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
    condition {
        test = "StringEquals"
        variable = "aws:SourceAccount"
        values = [data.aws_caller_identity.current.id]
    }
  }
}
resource "aws_iam_role" "github_export_schedule" {
  name               = "github_export_schedule_role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_scheduler_assume_role.json
  path               = "/service-role/"
}

data "aws_iam_policy_document" "github_export_schedule_role" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [
        "${aws_lambda_function.github_import.arn}:*",
        aws_lambda_function.github_import.arn,
    ]
  }
}
resource "aws_iam_policy" "github_export_schedule_role" {
  name   = "Amazon-EventBridge-Scheduler-Execution-Policy-6aa55f83-dbcb-4fc3-b79b-d04acb8720d4"
  policy = data.aws_iam_policy_document.github_export_schedule_role.json
  path   = "/service-role/"
}

resource "aws_iam_role_policy_attachment" "github_export_schedule_role" {
  role       = aws_iam_role.github_export_schedule.name
  policy_arn = aws_iam_policy.github_export_schedule_role.arn
}

resource "aws_scheduler_schedule" "github_export" {
  name       = "github_export"
  group_name = "default"
  description = "Exports data to GitHub on a weekly basis"

  flexible_time_window {
      mode = "FLEXIBLE"
      maximum_window_in_minutes = 30
  }

  schedule_expression = "cron(0 0 ? * 2 *)"
  schedule_expression_timezone = "America/Chicago"

  target {
    arn      = aws_lambda_function.github_import.arn
    role_arn = aws_iam_role.github_export_schedule.arn

    retry_policy {
      maximum_retry_attempts = 0
    }
  }
}
