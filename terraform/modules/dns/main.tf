# Route53 Record for Frontend (points to CloudFront)
resource "aws_route53_record" "frontend" {
  zone_id = var.hosted_zone_id
  name    = var.frontend_domain
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront hosted zone ID (global)
    evaluate_target_health = false
  }

  depends_on = [var.cloudfront_domain_name]
}

# Route53 Record for API (points to EC2 via A record)
# Note: In this setup, CloudFront handles /api routing, so this is primarily for direct access
resource "aws_route53_record" "api" {
  zone_id = var.hosted_zone_id
  name    = "api.${var.api_domain}"
  type    = "A"
  ttl     = 300
  records = [var.backend_instance_ip]
}