# Frontend outputs
output "frontend_bucket_name" {
  description = "Name of the S3 bucket for frontend assets"
  value       = module.frontend.bucket_name
}

output "frontend_cloudfront_id" {
  description = "CloudFront distribution ID"
  value       = module.frontend.cloudfront_distribution_id
}

output "frontend_cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = module.frontend.cloudfront_domain_name
}

output "frontend_domain" {
  description = "Frontend domain name"
  value       = local.frontend_domain
}

# Backend outputs
output "backend_instance_id" {
  description = "EC2 instance ID for the backend"
  value       = module.backend.instance_id
}

output "backend_instance_ip" {
  description = "Public IP of the backend instance"
  value       = module.backend.instance_public_ip
}

output "backend_security_group_id" {
  description = "Security group ID for the backend"
  value       = module.backend.security_group_id
}

# VPC outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# DNS outputs
output "api_domain" {
  description = "API domain name"
  value       = local.api_domain
}

# SSL Certificate
output "ssl_certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = module.frontend.certificate_arn
}