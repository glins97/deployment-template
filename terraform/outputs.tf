output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "frontend_bucket_name" {
  description = "Name of the S3 bucket for frontend"
  value       = module.frontend.bucket_name
}

output "frontend_cloudfront_id" {
  description = "CloudFront distribution ID"
  value       = module.frontend.cloudfront_id
}

output "frontend_domain" {
  description = "Frontend domain URL"
  value       = module.frontend.domain_url
}

output "backend_alb_dns" {
  description = "Application Load Balancer DNS name"
  value       = module.backend.alb_dns_name
}

output "backend_domain" {
  description = "Backend domain URL"
  value       = module.backend.domain_url
}

output "backend_instance_id" {
  description = "EC2 instance ID for backend"
  value       = module.backend.instance_id
}