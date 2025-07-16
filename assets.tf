resource "aws_s3_bucket" "gbt_audio" {
  bucket = "gbt-audio"
}
// TODO: remove after importing
import {
  to = aws_s3_bucket.gbt_audio
  id = "gbt-audio"
}

resource "aws_cloudfront_distribution" "assets" {
  enabled = false

  origin {
    domain_name = aws_s3_bucket.gbt_audio.bucket_regional_domain_name
    origin_id = "audio"
  }

  default_cache_behavior {
    allowed_methods = ["HEAD", "OPTIONS", "GET"]
    cached_methods = ["GET", "HEAD"]
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" // AWS Caching Optimized policy
    target_origin_id = "audio"
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_route53_record" "assets" {
  for_each = {
    for dvo in aws_acm_certificate.assets.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}
resource "aws_acm_certificate" "assets" {
  domain_name = "assets.globalbibletools.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_acm_certificate_validation" "assets" {
  certificate_arn = aws_acm_certificate.assets.arn
  validation_record_fqdns = [for record in aws_route53_record.assets : record.fqdn]
}
