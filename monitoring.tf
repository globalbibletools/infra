locals {
  job_queue_namespace = "JobQueue"
  handled_failure_count_metric = "HandledFailureCount"
}

resource "aws_cloudwatch_log_metric_filter" "job_failed" {
  name           = "job-failed-filter"
  log_group_name = aws_cloudwatch_log_group.job_worker_lambda.name

  pattern = "\"msg\":\"Job failed\""

  metric_transformation {
    name      = local.handled_failure_count_metric
    namespace = local.job_queue_namespace
    value     = "1"
  }
} 

resource "aws_cloudwatch_metric_alarm" "job_failed" {
  alarm_name          = "job-failed-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = local.handled_failure_count_metric
  namespace           = local.job_queue_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_description = "Triggers when Job fails"

  // TODO: bring the SNS into terraform
  alarm_actions = [
    "arn:aws:sns:us-east-1:188245254368:devops_alerts"
  ]
}
