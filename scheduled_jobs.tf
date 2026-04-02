data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "scheduled_jobs_role" {
  name               = "scheduled_jobs_role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
  path               = "/service-role/"
}
data "aws_iam_policy_document" "scheduled_jobs_role" {
  statement {
    effect  = "Allow"
    actions = ["SQS:SendMessage"]

    resources = [aws_sqs_queue.jobs.arn]
  }
}
resource "aws_iam_policy" "scheduled_jobs_role_queue" {
  name   = "ScheduledJobCreator"
  policy = data.aws_iam_policy_document.scheduled_jobs_role.json
  path   = "/service-role/"
}
resource "aws_iam_role_policy_attachment" "scheduled_jobs_role" {
  role       = aws_iam_role.scheduled_jobs_role.name
  policy_arn = aws_iam_policy.scheduled_jobs_role_queue.arn
}

resource "aws_scheduler_schedule" "export_analytics_schedule" {
  name       = "export-analytics"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 6 ? * 2 *)"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:sqs:sendMessage"
    role_arn = aws_iam_role.scheduled_jobs_role.arn
    input = jsonencode({
      QueueUrl = aws_sqs_queue.jobs.url,
      MessageBody = jsonencode({
        type = "export_analytics",
      })
    })
  }
}

resource "aws_scheduler_schedule" "recompute_book_progress_schedule" {
  name       = "recompute-book-progress"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 6 ? * * *)"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:sqs:sendMessage"
    role_arn = aws_iam_role.scheduled_jobs_role.arn
    input = jsonencode({
      QueueUrl = aws_sqs_queue.jobs.url,
      MessageBody = jsonencode({
        type = "update_book_completion_progress",
      })
    })
  }
}

resource "aws_scheduler_schedule" "queue_github_export_run_schedule" {
  name       = "github-export"
  group_name = "default"
  description = "Exports data to GitHub on a weekly basis"

  flexible_time_window {
      mode = "FLEXIBLE"
      maximum_window_in_minutes = 30
  }

  schedule_expression = "cron(0 0 ? * 2 *)"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:sqs:sendMessage"
    role_arn = aws_iam_role.scheduled_jobs_role.arn
    input = jsonencode({
      QueueUrl = aws_sqs_queue.jobs.url,
      MessageBody = jsonencode({
        type = "export_glosses",
        payload = {
          windowDays = 8
        }
      })
    })
  }
}
