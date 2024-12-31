resource "aws_ecr_repository" "import_worker" {
  name = "globalbibletools-import-worker"
}
data "aws_ecr_image" "import_worker_latest" {
  repository_name = aws_ecr_repository.import_worker.name
  image_tag       = "latest"
}

resource "aws_cloudwatch_log_group" "import_lambda" {
  name = "/aws/lambda/import_glosses"
}

resource "aws_iam_role" "import_lambda" {
  name               = "import_glosses_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  # path               = "/service-role/"
}

resource "aws_iam_role_policy_attachment" "import_lambda_role" {
  role       = aws_iam_role.import_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_sqs_queue" "import" {
  name                        = "gloss_import.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = 900
}

data "aws_iam_policy_document" "import" {
  statement {
    sid    = "tail"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:GetQueueAttributes",
      "sqs:DeleteMessage"
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.import_lambda.arn]
    }
    resources = [aws_sqs_queue.import.arn]
  }

  statement {
    sid     = "head"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::188245254368:user/app-prod"]
    }
    resources = [aws_sqs_queue.import.arn]
  }
}
resource "aws_sqs_queue_policy" "import" {
  queue_url = aws_sqs_queue.import.id
  policy    = data.aws_iam_policy_document.import.json
}

resource "aws_lambda_function" "import" {
  function_name = "import_glosses"
  role = aws_iam_role.import_lambda.arn
  package_type = "Image"
  image_uri = data.aws_ecr_image.import_worker_latest.image_uri
  memory_size = 128
  timeout = 900

  environment {
      variables = {
          DATABASE_URL = local.database_url
      }
  }
}

resource "aws_lambda_event_source_mapping" "import_sqs_trigger" {
  event_source_arn = aws_sqs_queue.import.arn
  function_name    = aws_lambda_function.import.arn
  batch_size = 1
}

