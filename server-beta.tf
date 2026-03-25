resource "aws_ecr_repository" "platform_beta" {
  name = "globalbibletools-platform-beta"
}

resource "aws_ecr_lifecycle_policy" "platform_beta" {
    repository = aws_ecr_repository.platform_beta.name
    policy = data.aws_ecr_lifecycle_policy_document.platform.json
}

resource "aws_apprunner_service" "server_beta" {
  service_name = "Platform - Beta"

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
          VITE_FATHOM_ID               = var.fathom_id
          ACCESS_KEY_ID                = aws_iam_access_key.app_prod.id
          DATABASE_URL                 = local.database_url
          EMAIL_FROM                   = "\"Global Bible Tools\" <info@globalbibletools.com>"
          EMAIL_SERVER                 = local.smtp_url
          GOOGLE_TRANSLATE_CREDENTIALS = google_service_account_key.default.private_key
          HOSTNAME                     = "0.0.0.0"
          LANGUAGE_IMPORT_QUEUE_URL    = aws_sqs_queue.import.url
          ORIGIN                       = "https://beta.globalbibletools.com"
          SECRET_ACCESS_KEY            = aws_iam_access_key.app_prod.secret
          OPENAI_KEY                   = var.openai_key
          JOB_QUEUE_URL                = aws_sqs_queue.jobs.url
          BIBLE_SYSTEMS_API_KEY        = var.global_bible_systems_api_key
        }
      }
      image_identifier      = "${aws_ecr_repository.platform_beta.repository_url}:latest"
      image_repository_type = "ECR"
    }
  }
}

resource "aws_cloudwatch_log_group" "server_application_beta" {
  name = "/aws/apprunner/Platform/${aws_apprunner_service.server_beta.service_id}/application"

  depends_on = [aws_apprunner_service.server_beta]
}

resource "aws_cloudwatch_log_group" "server_service_beta" {
  name = "/aws/apprunner/Platform/${aws_apprunner_service.server_beta.service_id}/service"

  depends_on = [aws_apprunner_service.server_beta]
}
