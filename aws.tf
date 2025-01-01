data "tls_certificate" "tfc_certificate" {
  url = "https://app.terraform.io"
}
resource "aws_iam_openid_connect_provider" "tfc_provider" {
  url             = data.tls_certificate.tfc_certificate.url
  client_id_list  = ["aws.workload.identity"]
  thumbprint_list = [data.tls_certificate.tfc_certificate.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "tfc_assume_role_policy" {
  version = "2012-10-17"
  statement {
    sid     = "assumerole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.tfc_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "app.terraform.io:aud"
      values   = [one(aws_iam_openid_connect_provider.tfc_provider.client_id_list)]
    }
    condition {
      test     = "StringLike"
      variable = "app.terraform.io:sub"
      values   = ["organization:${var.terraform_organization}:project:*:workspace:*:run_phase:*"]
    }
  }
}
resource "aws_iam_role" "tfc_role" {
  name               = "tfc-role"
  assume_role_policy = data.aws_iam_policy_document.tfc_assume_role_policy.json
}

# Policy for what AWS terraform role has access to
# TODO: replace with narrow polify
resource "aws_iam_role_policy_attachment" "tfc_policy_attachment" {
  role       = aws_iam_role.tfc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
