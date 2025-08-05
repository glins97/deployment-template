variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, hml, prd)"
  type        = string
}

variable "domain" {
  description = "Domain name for the frontend"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

variable "backend_instance_dns" {
  description = "Public DNS name of the backend EC2 instance"
  type        = string
}