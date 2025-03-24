resource "aws_ecr_repository" "job_worker" {
  name = "globalbibletools-job-worker"
}
data "aws_ecr_lifecycle_policy_document" "job_worker" {
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
resource "aws_ecr_lifecycle_policy" "job_worker" {
  repository = aws_ecr_repository.job_worker.name
  policy     = data.aws_ecr_lifecycle_policy_document.job_worker.json
}
