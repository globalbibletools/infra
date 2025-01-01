resource "aws_ses_domain_identity" "default" {
  domain = var.domain
}

resource "aws_iam_user" "smtp_user" {
  name = var.smtp_user
}
resource "aws_iam_access_key" "smtp_user" {
  user = aws_iam_user.smtp_user.name
}

data "aws_iam_policy_document" "ses_send" {
  statement {
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]
  }
}
resource "aws_iam_policy" "ses_send" {
  name   = "SES-Send"
  policy = data.aws_iam_policy_document.ses_send.json
}

resource "aws_iam_user_policy_attachment" "smtp_user" {
  user       = aws_iam_user.smtp_user.name
  policy_arn = aws_iam_policy.ses_send.arn
}

resource "aws_route53_record" "ses_verification" {
  zone_id = aws_route53_zone.main.id
  name    = "_amazonses.${var.domain}"
  type    = "TXT"
  records = [aws_ses_domain_identity.default.verification_token]
  ttl     = "600"
}
resource "aws_ses_domain_identity_verification" "this" {
  domain = aws_ses_domain_identity.default.id

  depends_on = [aws_route53_record.ses_verification]
}

resource "aws_ses_domain_dkim" "default" {
  domain = aws_ses_domain_identity.default.domain
}
resource "aws_route53_record" "ses_dkim_record" {
  count   = 3
  zone_id = aws_route53_zone.main.id
  name    = "${aws_ses_domain_dkim.default.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.default.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_ses_domain_mail_from" "default" {
  domain           = aws_ses_domain_identity.default.domain
  mail_from_domain = "${var.mail_from_subdomain}.${aws_ses_domain_identity.default.domain}"
}
resource "aws_route53_record" "ses_domain_mail_from_mx" {
  zone_id = aws_route53_zone.main.id
  name    = aws_ses_domain_mail_from.default.mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = ["10 feedback-smtp.us-east-1.amazonses.com"]
}
resource "aws_route53_record" "ses_domain_mail_from_txt" {
  zone_id = aws_route53_zone.main.id
  name    = aws_ses_domain_mail_from.default.mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_route53_record" "ses_dmarc" {
  zone_id = aws_route53_zone.main.id
  name    = "_dmarc.${aws_ses_domain_identity.default.domain}"
  type    = "TXT"
  ttl     = "300"
  records = ["v=DMARC1; p=none;"]
}

resource "aws_sns_topic" "ses_notifications" {
  name = var.ses_sns_topic
}
resource "aws_sns_topic_subscription" "ses_notifications_to_server" {
  topic_arn = aws_sns_topic.ses_notifications.arn
  protocol  = "https"
  endpoint  = var.bounce_subscription_url
  delivery_policy = jsonencode({
    "healthyRetryPolicy" : {
      "numRetries" : 3,
      "numNoDelayRetries" : null,
      "minDelayTarget" : 20,
      "maxDelayTarget" : 20,
      "numMinDelayRetries" : null,
      "numMaxDelayRetries" : null,
      "backoffFunction" : "linear"
    },
    "requestPolicy" : {
      "headerContentType" : "application/json"
    }
  })
}
data "aws_iam_policy_document" "ses_notifications" {
  version = "2012-10-17"
  statement {
    sid    = "send"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.ses_notifications.arn]
  }
}
resource "aws_sns_topic_policy" "ses_notifications" {
  arn    = aws_sns_topic.ses_notifications.arn
  policy = data.aws_iam_policy_document.ses_notifications.json
}

resource "aws_ses_identity_notification_topic" "bounce" {
  topic_arn         = aws_sns_topic.ses_notifications.arn
  notification_type = "Bounce"
  identity          = aws_ses_domain_identity.default.domain
}
resource "aws_ses_identity_notification_topic" "complaint" {
  topic_arn         = aws_sns_topic.ses_notifications.arn
  notification_type = "Complaint"
  identity          = aws_ses_domain_identity.default.domain
}

locals {
    smtp_url = "smtp://${aws_iam_access_key.smtp_user.id}:${aws_iam_access_key.smtp_user.ses_smtp_password_v4}@email-smtp.us-east-1.amazonaws.com:587"
}
