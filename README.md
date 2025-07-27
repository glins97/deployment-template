# Full Stack Deployment Template

A comprehensive deployment template for full-stack applications with React frontend and backend services, featuring automated CI/CD pipelines and AWS infrastructure management.

## 🚀 Features

- **Frontend**: React app deployed to S3 + CloudFront with custom domain and SSL
- **Backend**: EC2 instances running Docker Compose with Application Load Balancer
- **Infrastructure**: Terraform modules for AWS resources
- **CI/CD**: GitHub Actions workflows for automated deployment
- **Multi-Environment**: Automatic setup for dev, hml, and prd environments
- **Security**: SSL certificates, private subnets, and secure secret management

## 📋 Prerequisites

Before using this template, ensure you have:

- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate permissions
- [GitHub CLI](https://cli.github.com/) installed and authenticated
- [Terraform](https://www.terraform.io/) >= 1.0
- [jq](https://stedolan.github.io/jq/) for JSON processing
- A domain name with DNS managed by Route 53

## 🛠️ Quick Start

### 1. Repository Setup

Execute the repository setup to configure environments and secrets:

```bash
./setup.sh
```

**OR** use specific commands:
```bash
./setup.sh repository       # Repository & environment setup
./setup.sh infrastructure   # Infrastructure setup (prefer GitHub Actions)
./setup.sh help             # Show usage
```

This will:
- ✅ Validate your configuration (creates `config.json` from template)
- ✅ Check prerequisites (GitHub CLI, AWS CLI)
- ✅ Validate Route53 hosted zones
- ✅ Setup `.env` file (creates from template)
- ✅ Create GitHub environments (dev, hml, prd)
- ✅ Upload AWS credentials and project secrets to GitHub

### 2. Infrastructure Setup

Run infrastructure setup locally (requires config.json):

```bash
./setup.sh infrastructure
```

This creates:
- Terraform S3 backend bucket with versioning and encryption
- DynamoDB table for state locking
- EC2 key pairs and uploads them to GitHub secrets

### 3. Deploy Application

1. After local infrastructure setup completes
2. Go to GitHub Actions and run the **"Deploy"** workflow
3. Your application will be deployed to all environments

## 📁 Project Structure

```
deployment-template/
├── config.example.json        # Configuration template
├── config.json                # Main configuration file (created from template)
├── setup.sh                   # Setup orchestrator (110 lines)
├── .env.example               # Environment variables template
├── .env                       # Environment variables (created from template)
├── docker-compose.yml         # Docker services configuration
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   └── modules/              # Terraform modules
│       ├── vpc/              # VPC and networking
│       ├── frontend/         # S3 + CloudFront
│       └── backend/          # EC2 + ALB
├── .github/workflows/        # CI/CD pipelines
│   └── deploy.yml           # Main deployment workflow
├── scripts/                  # Setup scripts
│   ├── setup-repository.sh   # Repository & environment setup (all-in-one)
│   └── setup-infrastructure.sh # Infrastructure setup
├── frontend/                 # React application
└── backend/                  # Backend application
```

## 🔧 Infrastructure Details

### Frontend (S3 + CloudFront)
- Static React app hosted on S3
- CloudFront CDN for global distribution
- SSL certificate from ACM
- Custom domain with Route 53

### Backend (EC2 + ALB)
- EC2 instances running Docker Compose
- Application Load Balancer with SSL termination
- Auto Scaling Group for high availability
- Private subnets for security

### Networking
- VPC with public and private subnets
- NAT Gateways for outbound internet access
- Security Groups with minimal required access
- Route 53 DNS management

## 🔄 CI/CD Workflows

### Main Deployment Workflow (`deploy.yml`)

Triggered on:
- Push to `main` branch → deploys to `prd`
- Push to `staging` branch → deploys to `hml`  
- Push to `develop` branch → deploys to `dev`
- Manual workflow dispatch

Steps:
1. **Deploy Infrastructure**: Terraform apply
2. **Deploy Frontend**: Build React app → Deploy to S3 → Invalidate CloudFront
3. **Deploy Backend**: Build Docker images → Deploy to EC2

**Note**: Infrastructure setup (S3 backend, EC2 keys, etc.) must be completed locally before running this workflow.

## 🔐 Environment Management

### GitHub Environments
- **dev**: Development environment
- **hml**: Homologation/Staging environment  
- **prd**: Production environment (with deployment protection)

### Secrets Management

**Deployment Secrets** (managed by setup script):
- `AWS_ACCESS_KEY_ID` - AWS credentials for deployment
- `AWS_SECRET_ACCESS_KEY` - AWS credentials for deployment  
- `EC2_KEY_NAME` - EC2 key pair name (auto-generated)
- `EC2_PRIVATE_KEY` - EC2 private key (auto-generated)

**Project Secrets** (from your .env file):
- Add only the environment variables your specific project needs
- Examples: `DATABASE_URL`, `JWT_SECRET`, `API_KEY`, etc.
- Do NOT add deployment-related secrets to .env

## 📝 Customization

### Adding New Services
1. Update `docker-compose.yml` with new services
2. Add any required environment variables to `.env.example`
3. Update security groups in Terraform if needed

### Custom Domains
1. Ensure your domain is managed by Route 53
2. Update domains in `config.json`
3. SSL certificates will be automatically created and validated

### Scaling Configuration
Update instance types in `config.json`:
```json
{
  "infrastructure": {
    "backend": {
      "instance_type": {
        "dev": "t3.small",
        "hml": "t3.medium",
        "prd": "t3.large"
      }
    }
  }
}
```

## 🛠️ Manual Operations

### Run Individual Setup Scripts

```bash
# Repository setup (includes GitHub environments and secrets)
./scripts/setup-repository.sh

# Infrastructure setup (run locally only)
./scripts/setup-infrastructure.sh
```

**Note**: Infrastructure setup must be run locally because it requires `config.json` which contains project-specific configuration and is not committed to the repository.

### Access EC2 Instances
```bash
# Get instance IP from AWS console or Terraform outputs
ssh -i /path/to/key.pem ubuntu@<instance-ip>
```

### View Application Logs
```bash
# On EC2 instance
cd /opt/app
docker-compose logs -f
```

### Update Secrets
```bash
# Update .env file then run:
./scripts/env-to-secrets.sh
```

## 🚨 Troubleshooting

### Common Issues

1. **Terraform state lock**:
   ```bash
   # Force unlock (use carefully)
   terraform force-unlock <lock-id>
   ```

2. **SSL certificate validation stuck**:
   - Ensure Route 53 hosted zone exists
   - Check DNS propagation
   - Verify domain ownership

3. **EC2 deployment fails**:
   - Check security groups allow SSH (port 22)
   - Verify EC2 key pair exists
   - Check instance logs in AWS console

4. **GitHub Actions fails**:
   - Verify all secrets are set correctly
   - Check AWS permissions
   - Review workflow logs for specific errors

5. **GitHub CLI variables not supported**:
   - The scripts automatically detect GitHub CLI capabilities
   - If `gh variable` isn't available, everything is stored as secrets
   - Update GitHub CLI for variable support: `gh extension upgrade cli`

### Cleanup Resources
To destroy all infrastructure:
```bash
cd terraform
terraform destroy -auto-approve
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [HashiCorp Terraform](https://www.terraform.io/)
- [GitHub Actions](https://github.com/features/actions)
- [AWS](https://aws.amazon.com/)

---

**Happy Deploying! 🚀**

For support or questions, please open an issue in this repository.