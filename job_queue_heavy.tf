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

