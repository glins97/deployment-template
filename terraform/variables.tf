variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, hml, prd)"
  type        = string
  validation {
    condition     = contains(["dev", "hml", "prd"], var.environment)
    error_message = "Environment must be dev, hml, or prd."
  }
}

variable "domain" {
  description = "Root domain for the project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for backend"
  type        = string
  default     = "t3.small"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair for EC2 access"
  type        = string
  default     = ""
}

variable "github_actions_ips" {
  description = "GitHub Actions IP ranges for SSH access"
  type        = list(string)
  default = [
    "0.0.0.0/0"  # For simplicity, restrict this in production
  ]
}