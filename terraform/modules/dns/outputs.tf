output "frontend_record_name" {
  description = "Frontend DNS record name"
  value       = aws_route53_record.frontend.name
}

output "frontend_record_fqdn" {
  description = "Frontend DNS record FQDN"
  value       = aws_route53_record.frontend.fqdn
}

output "api_record_name" {
  description = "API DNS record name"
  value       = aws_route53_record.api.name
}

output "api_record_fqdn" {
  description = "API DNS record FQDN"
  value       = aws_route53_record.api.fqdn
}