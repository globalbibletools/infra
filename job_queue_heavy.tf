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
    redrivePermission = "byqueue",
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
