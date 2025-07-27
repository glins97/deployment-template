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

### 1. Configure the Project

1. **Create `config.json`** from the template and update with your project details:
```bash
cp config.example.json config.json
# Add your project-specific environment variables
```


2. **Create `.env` file** based on `.env.example`:
```bash
cp .env.example .env
# Add your project-specific environment variables
```

**Note**: The setup script will guide you through creating both `config.json` and `.env` from their templates.

### 2. Run Setup Script

Execute the main setup script to automatically configure everything:

```bash
./setup.sh
```

This script will:
- ✅ Validate your configuration
- ✅ Check prerequisites
- ✅ Create Terraform S3 backend
- ✅ Generate EC2 key pairs
- ✅ Setup GitHub environments (dev, hml, prd)
- ✅ Upload secrets to GitHub

### 3. Deploy Infrastructure

1. Go to your GitHub repository's **Actions** tab
2. Run the **"Setup Initial Infrastructure"** workflow first (one-time setup)
3. Run the **"Deploy Infrastructure and Application"** workflow

## 📁 Project Structure

```
deployment-template/
├── config.example.json        # Configuration template
├── config.json                # Main configuration file (created from template)
├── setup.sh                   # Main setup script
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
│   ├── deploy.yml           # Main deployment workflow
│   └── setup-infrastructure.yml # Initial setup workflow
├── scripts/                  # Utility scripts
│   ├── setup-github-environments.sh
│   └── env-to-secrets.sh
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

### Initial Setup Workflow (`setup-infrastructure.yml`)

One-time setup for:
- Terraform state S3 bucket
- EC2 key pairs
- DynamoDB table for state locking

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