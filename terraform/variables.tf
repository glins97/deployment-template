variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, hml, prd)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "frontend_domain" {
  description = "Frontend domain name"
  type        = string
}

variable "backend_domain" {
  description = "Backend domain name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for backend"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}