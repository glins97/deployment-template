terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for state storage
  # This should be configured per environment
  backend "s3" {
    # These values should be set via terraform init -backend-config
    # or via environment variables
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_route53_zone" "main" {
  name         = local.root_domain
  private_zone = false
}

# Local values for resource naming
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Extract root domain from the provided domain (handles subdomains)
  # For example: test-abc.ljsft.xyz -> ljsft.xyz
  domain_parts = split(".", var.domain)
  root_domain  = length(local.domain_parts) > 2 ? join(".", slice(local.domain_parts, length(local.domain_parts) - 2, length(local.domain_parts))) : var.domain

  # Domain configuration
  frontend_domain = var.environment == "prd" ? var.domain : "${var.environment}.${var.domain}"
  api_domain      = var.environment == "prd" ? var.domain : "${var.environment}.${var.domain}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  availability_zones = var.availability_zones

  tags = local.common_tags
}

# Frontend Module (S3 + CloudFront)
module "frontend" {
  source = "./modules/frontend"

  project_name   = var.project_name
  environment    = var.environment
  domain         = local.frontend_domain
  hosted_zone_id = data.aws_route53_zone.main.zone_id

  tags = local.common_tags
}

# Backend Module (EC2)
module "backend" {
  source = "./modules/backend"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_ids[0]
  instance_type      = var.instance_type
  ssh_key_name       = var.ssh_key_name
  github_actions_ips = var.github_actions_ips

  tags = local.common_tags
}

# DNS Module
module "dns" {
  source = "./modules/dns"

  project_name           = var.project_name
  environment            = var.environment
  hosted_zone_id         = data.aws_route53_zone.main.zone_id
  frontend_domain        = local.frontend_domain
  api_domain             = local.api_domain
  cloudfront_domain_name = module.frontend.cloudfront_domain_name
  backend_instance_ip    = module.backend.instance_public_ip

  tags = local.common_tags
}