resource "aws_ecr_repository" "job_worker_heavy" {
  name = "globalbibletools-job-worker-heavy"
}
data "aws_ecr_lifecycle_policy_document" "job_worker_heavy" {
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
resource "aws_ecr_lifecycle_policy" "job_worker_heavy" {
  repository = aws_ecr_repository.job_worker_heavy.name
  policy     = data.aws_ecr_lifecycle_policy_document.job_worker_heavy.json
}

resource "aws_sqs_queue" "jobs_heavy" {
  name                       = "jobs_heavy"
  visibility_timeout_seconds = 600
}

resource "aws_sqs_queue" "jobs_heavy_dlq" {
  name                      = "jobs_heavy_dlq"
  message_retention_seconds = 1209600 # 14 days

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.jobs_heavy.arn]
  })
}

resource "aws_sqs_queue_redrive_policy" "jobs_heavy" {
  queue_url = aws_sqs_queue.jobs_heavy.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_heavy_dlq.arn
    maxReceiveCount     = 1
  })
}

resource "aws_cloudwatch_log_group" "job_worker_heavy_ecs" {
  name = "/aws/lambda/job_worker_heavy"
}

data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "job_queue_heavy_ecs_execution" {
  name               = "heavy-job-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.job_queue_heavy_ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_iam_role" "job_queue_heavy_ecs_task" {
  name = "heavy-job-worker-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}
data "aws_iam_policy_document" "job_worker_heavy" {
  policy_id = "__default_policy_ID"

  statement {
    sid     = "__owner_statement"
    effect  = "Allow"
    actions = ["SQS:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = [aws_sqs_queue.jobs_heavy.arn]
  }

  statement {
    sid     = "__sender_statement"
    effect  = "Allow"
    actions = ["SQS:SendMessage"]

    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.job_queue_heavy_ecs_task.arn,
        aws_iam_user.app_prod.arn
      ]
    }
    resources = [aws_sqs_queue.jobs_heavy.arn]
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
      identifiers = [aws_iam_role.job_queue_heavy_ecs_task.arn]
    }
    resources = [aws_sqs_queue.jobs_heavy.arn]
  }
}
resource "aws_sqs_queue_policy" "job_worker_heavy" {
  queue_url = aws_sqs_queue.jobs_heavy.id
  policy    = data.aws_iam_policy_document.job_worker_heavy.json
}

resource "aws_ecs_task_definition" "job_worker_heavy" {
  family                   = "job_worker_heavy"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"

  cpu    = 1024
  memory = 2048

  execution_role_arn = aws_iam_role.job_queue_heavy_ecs_execution.arn
  task_role_arn      = aws_iam_role.job_queue_heavy_ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.job_worker_heavy_image
      essential = true

      stopTimeout = 120

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.job_worker_heavy_ecs.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "job_worker_heavy"
        }
      }

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "WORKER_CONCURRENCY"
          value = "3"
        },
        {
          name = "DATABASE_URL"
          value = local.database_url
        },
        {
          name = "JOB_QUEUE_HEAVY_URL"
          value = aws_sqs_queue.jobs_heavy.url
        },
        {
          name = "EMAIL_FROM"
          value = "\"Global Bible Tools\" <info@globalbibletools.com>"
        },
        {
          name = "EMAIL_SERVER"
          value = local.smtp_url
        },
        {
          name = "SERVICE_NAME"
          value = "job-worker-heavy"
        },
        {
          name = "GOOGLE_TRANSLATE_CREDENTIALS"
          value = google_service_account_key.default.private_key
        },
        {
          name = "ANALYTICS_SPREADSHEET_ID"
          value = var.analytics_sheet_id
        },
        {
          name = "BIBLE_SYSTEMS_API_KEY"
          value = var.global_bible_systems_api_key
        },
        {
          name = "GITHUB_TOKEN"
          value = var.github_token
        },
        {
          name = "GITHUB_EXPORT_OWNER"
          value = "globalbibletools"
        },
        {
          name = "GITHUB_EXPORT_REPO"
          value = "data"
        },
        {
          name = "GITHUB_EXPORT_BRANCH"
          value = "main"
        }
      ]
    }
  ])
}

resource "aws_ecs_cluster" "job_worker_heavy" {
  name = "job-worker-heavy"
}

resource "aws_ecs_service" "job_worker_heavy" {
  name            = "worker"
  cluster         = aws_ecs_cluster.job_worker_heavy.id
  task_definition = aws_ecs_task_definition.job_worker_heavy.arn

  desired_count = 0

  launch_type = "FARGATE"

  platform_version = "LATEST"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  enable_execute_command = false

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.egress_only.id]

    assign_public_ip = true
  }
}

resource "aws_appautoscaling_target" "job_worker_heavy" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"

  resource_id = "service/${aws_ecs_cluster.job_worker_heavy.name}/${aws_ecs_service.job_worker_heavy.name}"

  min_capacity = 0
  max_capacity = 1
}
resource "aws_appautoscaling_policy" "job_worker_heavy_scale_up" {
  name               = "job-worker-heavy-scale-up"
  service_namespace  = aws_appautoscaling_target.job_worker_heavy.service_namespace
  scalable_dimension = aws_appautoscaling_target.job_worker_heavy.scalable_dimension
  resource_id        = aws_appautoscaling_target.job_worker_heavy.resource_id

  policy_type = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type = "ExactCapacity"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}
resource "aws_appautoscaling_policy" "job_worker_heavy_scale_down" {
  name              = "job-worker-heavy-scale-down"
  service_namespace = aws_appautoscaling_target.job_worker_heavy.service_namespace

  scalable_dimension = aws_appautoscaling_target.job_worker_heavy.scalable_dimension
  resource_id        = aws_appautoscaling_target.job_worker_heavy.resource_id

  policy_type = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type = "ExactCapacity"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "job_queue_heavy_has_messages" {
  alarm_name          = "job-queue-heavy-has-messages"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 1
  period              = 60

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"

  dimensions = {
    QueueName = aws_sqs_queue.jobs_heavy.name
  }

  alarm_actions = [aws_appautoscaling_policy.job_worker_heavy_scale_up.arn]
}
resource "aws_cloudwatch_metric_alarm" "job_queue_heavy_idle" {
  alarm_name          = "job-queue-heavy-idle"
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = 0

  evaluation_periods = 20

  treat_missing_data = "notBreaching"

  metric_query {
    id = "m1"

    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"

      dimensions = {
        QueueName = aws_sqs_queue.jobs_heavy.name
      }

      period = 60
      stat   = "Sum"
    }
  }

  metric_query {
    id = "m2"

    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesNotVisible"

      dimensions = {
        QueueName = aws_sqs_queue.jobs_heavy.name
      }

      period = 60
      stat   = "Sum"
    }
  }

  metric_query {
    id = "e1"
    expression  = "m1 + m2"
    return_data = true
  }

  alarm_actions = [aws_appautoscaling_policy.job_worker_heavy_scale_down.arn]
}
