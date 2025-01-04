data "tls_certificate" "github_certificate" {
  url = "https://token.actions.githubusercontent.com"
}
resource "aws_iam_openid_connect_provider" "github_provider" {
  url             = data.tls_certificate.github_certificate.url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_certificate.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_assume_role" {
  version = "2012-10-17"
  statement {
    sid     = "assumerole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [one(aws_iam_openid_connect_provider.github_provider.client_id_list)]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:globalbibletools/*"]
    }
  }
}
resource "aws_iam_role" "github" {
  name               = "github-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

data "aws_iam_policy_document" "ecr_push" {
    version = "2012-10-17"

    statement {
        effect = "Allow"
          actions = [
            "ecr:CompleteLayerUpload",
            "ecr:GetAuthorizationToken",
            "ecr:UploadLayerPart",
            "ecr:InitiateLayerUpload",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage",
            "ecr:BatchGetImage"
          ]
          resources = [
            "*"
          ]
    }
}
resource "aws_iam_role_policy" "github_role_ecr" {
  name = "ecr_push"
  role = aws_iam_role.github.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

data "aws_iam_policy_document" "lambda_deploy" {
    version = "2012-10-17"

    statement {
        effect = "Allow"
          actions = [
            "lambda:UpdateFunctionCode"
          ]
          resources = [
            "*"
          ]
    }
}
resource "aws_iam_role_policy" "github_role_lambda" {
  name = "lambda_deploy"
  role = aws_iam_role.github.id
  policy = data.aws_iam_policy_document.lambda_deploy.json
}
