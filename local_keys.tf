resource "aws_iam_user" "local_developer" {
  name = "local_developer"
}

resource "aws_iam_access_key" "local_developer" {
  user = aws_iam_user.local_developer.name

  lifecycle {
    prevent_destroy = false
  }
}

# Output the access key and secret
output "local_developer_access_key_id" {
  value       = aws_iam_access_key.local_developer.id
  description = "Local Developer AWS Access Key ID"
}

output "local_developer_secret_access_key" {
  value       = aws_iam_access_key.local_developer.secret
  description = "Local Developer AWS Secret Access Key"
  sensitive   = true
}
