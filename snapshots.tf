resource "aws_s3_bucket" "snapshots-local" {
  bucket = "gbt-snapshots-local"
  region = "us-east-1"
}

data "aws_iam_policy_document" "snapshots_local_access" {
  statement {
    effect = "Allow"

    actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:CreateMultipartUpload",
        "s3:UploadPart",
        "s3:CompleteMultipartUpload",
        "s3:AbortMultipartUpload"
    ]

    resources = [
      "${aws_s3_bucket.snapshots-local.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "snapshots_local_access" {
  name = "snapshots_local_access"
  path = "/"
  description = "Gives S3 access for local snapshots"

  policy = data.aws_iam_policy_document.snapshots_local_access.json
}

resource "aws_iam_user_policy_attachment" "local_developer" {
  user       = aws_iam_user.local_developer.name
  policy_arn = aws_iam_policy.snapshots_local_access.arn
}

