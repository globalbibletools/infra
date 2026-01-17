resource "aws_route53_record" "developer_docs_record" {
  zone_id = aws_route53_zone.main.id
  name    = "developers"
  type    = "CNAME"
  ttl     = "600"
  records = ["globalbibletools.github.io"]
}

resource "aws_route53_record" "developer_docs_verification" {
  zone_id = aws_route53_zone.main.id
  name    = "_gh-globalbibletools-o.developers"
  type    = "TXT"
  ttl     = "600"
  records = ["7200adc8c4"]
}

