resource "aws_s3_bucket" "gloss_prediction" {
    bucket = "gloss-prediction" 
}

resource "aws_ecr_repository" "start_gloss_prediction_lambda" {
  name = "start_gloss_prediction_lambda"
}
data "aws_ecr_lifecycle_policy_document" "start_gloss_prediction_lambda" {
    rule {
        priority = 1
        description = "Removes all but the last three created images"

        selection {
            tag_status = "any"
            count_type = "imageCountMoreThan"
            count_number = 3
        }

        action {
            type = "expire"
        }
    }
}
resource "aws_ecr_lifecycle_policy" "start_gloss_prediction_lambda" {
    repository = aws_ecr_repository.start_gloss_prediction_lambda.name
    policy = data.aws_ecr_lifecycle_policy_document.start_gloss_prediction_lambda.json
}
data "aws_ecr_image" "start_gloss_prediction_lambda_latest" {
  repository_name = aws_ecr_repository.start_gloss_prediction_lambda.name
  image_tag       = "latest"
}

resource "aws_cloudwatch_log_group" "start_gloss_prediction_lambda" {
  name = "/aws/lambda/start_gloss_prediction"
}
data "aws_iam_policy_document" "start_gloss_prediction_lambda_logging" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.start_gloss_prediction_lambda.arn}:*"]
  }
}

resource "aws_iam_role" "start_gloss_prediction_lambda" {
  name               = "start_gloss_prediction_lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  path               = "/service-role/"
}
resource "aws_iam_role_policy" "start_gloss_prediction_lambda_logging" {
  name = "logging"
  role       = aws_iam_role.start_gloss_prediction_lambda.name
  policy = data.aws_iam_policy_document.start_gloss_prediction_lambda_logging.json
}

resource "aws_lambda_function" "start_gloss_prediction" {
  function_name = "start_gloss_prediction"
  role = aws_iam_role.start_gloss_prediction_lambda.arn
  package_type = "Image"
  image_uri = data.aws_ecr_image.start_gloss_prediction_lambda_latest.image_uri
  memory_size = 512
  timeout = 300

  environment {
      variables = {
      }
  }
}

resource "aws_lambda_permission" "start_gloss_prediction_lambda" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.start_gloss_prediction.arn
    principal = "s3.amazonaws.com"
    source_arn = aws_s3_bucket.gloss_prediction.arn
}

resource "aws_s3_bucket_notification" "gloss_prediction" {
    bucket = aws_s3_bucket.gloss_prediction.id

    lambda_function {
        lambda_function_arn = aws_lambda_function.start_gloss_prediction.arn
        events = ["s3:ObjectCreated:*"]
        filter_prefix = "input/"
    }

    depends_on = [aws_lambda_permission.start_gloss_prediction_lambda]
}

