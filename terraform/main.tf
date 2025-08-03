terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Frontend (S3 + CloudFront)
module "frontend" {
  source = "./modules/frontend"
  
  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.frontend_domain
}

# Backend (EC2 + ALB)
module "backend" {
  source = "./modules/backend"
  
  project_name    = var.project_name
  environment     = var.environment
  domain_name     = var.backend_domain
  instance_type   = var.instance_type
  key_name        = var.key_name
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets
}