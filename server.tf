resource "aws_ecr_repository" "platform" {
  name = "globalbibletools-platform"
}

data "aws_iam_policy_document" "app_runner_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "app_runner_ecr" {
  name               = "AppRunnerECRAccessRole"
  path               = "/service-role/"
  description        = "This role gives App Runner permission to access ECR"
  assume_role_policy = data.aws_iam_policy_document.app_runner_assume_role.json
}

resource "aws_iam_role_policy_attachment" "app_runner_ecr_access" {
  role       = aws_iam_role.app_runner_ecr.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

data "aws_iam_policy_document" "apprunner_tasks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["tasks.apprunner.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "apprunner_tasks" {
  name               = "apprunner"
  assume_role_policy = data.aws_iam_policy_document.apprunner_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "apprunner_task_xray" {
  role       = aws_iam_role.apprunner_tasks.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_user" "app_prod" {
  name = var.api_user
}
resource "aws_iam_access_key" "app_prod" {
  user = aws_iam_user.app_prod.name
}

resource "aws_apprunner_auto_scaling_configuration_version" "server" {
  auto_scaling_configuration_name = "server-configuration"

  max_concurrency = 100
  max_size        = 1
  min_size        = 1
}

resource "aws_apprunner_service" "server" {
  service_name = "Platform"

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.server.arn

  instance_configuration {
     instance_role_arn = aws_iam_role.apprunner_tasks.arn
  }

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.app_runner_ecr.arn
    }

    image_repository {
      image_configuration {
        port = "3000"
        runtime_environment_variables = {
          ACCESS_KEY_ID                = aws_iam_access_key.app_prod.id
          DATABASE_URL                 = local.database_url
          EMAIL_FROM                   = "\"Global Bible Tools\" <info@globalbibletools.com>"
          EMAIL_SERVER                 = local.smtp_url
          GOOGLE_TRANSLATE_CREDENTIALS = var.google_translate_credentials
          HOSTNAME                     = "0.0.0.0"
          LANGUAGE_IMPORT_QUEUE_URL    = aws_sqs_queue.import.url
          ORIGIN                       = "https://globalbibletools.com"
          SECRET_ACCESS_KEY            = aws_iam_access_key.app_prod.secret
        }
      }
      image_identifier      = "${aws_ecr_repository.platform.repository_url}:latest"
      image_repository_type = "ECR"
    }
  }

  observability_configuration {
    observability_configuration_arn = "arn:aws:apprunner:us-east-1:188245254368:observabilityconfiguration/DefaultConfiguration/1/00000000000000000000000000000001"
    observability_enabled           = true
  }
}

resource "aws_cloudwatch_log_group" "server_application" {
  name = "/aws/apprunner/Platform/${aws_apprunner_service.server.service_id}/application"

  depends_on = [aws_apprunner_service.server]
}
import {
    to = aws_cloudwatch_log_group.server_application
    id = "/aws/apprunner/Platform/${aws_apprunner_service.server.service_id}/application"
}

resource "aws_cloudwatch_log_group" "server_service" {
  name = "/aws/apprunner/Platform/${aws_apprunner_service.server.service_id}/service"

  depends_on = [aws_apprunner_service.server]
}
import {
    to = aws_cloudwatch_log_group.server_service
    id = "/aws/apprunner/Platform/${aws_apprunner_service.server.service_id}/service"
}
