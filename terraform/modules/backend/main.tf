locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Backend
resource "aws_security_group" "backend" {
  name_prefix = "${local.name_prefix}-backend-"
  vpc_id      = var.vpc_id
  description = "Security group for backend EC2 instance"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # Django app port
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Django application"
  }

  # SSH access from GitHub Actions
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.github_actions_ips
    description = "SSH access from GitHub Actions"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-backend-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# User data script for EC2 instance
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
    environment  = var.environment
  }))
}

# EC2 Instance
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.ssh_key_name != "" ? var.ssh_key_name : null
  vpc_security_group_ids = [aws_security_group.backend.id]
  subnet_id             = var.public_subnet_id
  user_data             = local.user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-backend"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for Backend
resource "aws_eip" "backend" {
  instance = aws_instance.backend.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-backend-eip"
  })

  depends_on = [aws_instance.backend]
}