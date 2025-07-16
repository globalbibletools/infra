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
