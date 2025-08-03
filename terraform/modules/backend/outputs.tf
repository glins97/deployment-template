output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.backend.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.backend.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.backend.private_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.backend.id
}

output "elastic_ip" {
  description = "Elastic IP address"
  value       = aws_eip.backend.public_ip
}