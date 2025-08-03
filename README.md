# Deployment Template

A complete automation template for deploying full-stack applications (React + Django + PostgreSQL) to AWS using GitHub Actions.

## 🚀 What This Template Provides

- **Frontend**: React app deployed to S3 + CloudFront with automatic HTTPS
- **Backend**: Django API deployed to EC2 with Docker Compose
- **Database**: PostgreSQL running in Docker on the same EC2 instance
- **Infrastructure**: Complete AWS infrastructure via Terraform
- **CI/CD**: GitHub Actions workflows for automated deployment
- **Multi-Environment**: Support for dev, staging (hml), and production environments

## 📋 Prerequisites

Before using this template, ensure you have:

- AWS Account with programmatic access
- Domain name with Route53 hosted zone (or ability to create one)
- GitHub repository
- GitHub CLI (`gh`) installed locally

## 🛠️ Quick Start

1. **Clone this template**:
   ```bash
   git clone <this-repo>
   cd deployment-template
   ```

2. **Configure your project**:
   ```bash
   cp config.example.json config.json
   cp .env.example .env
   ```
   
   Edit `config.json` with your project details:
   ```json
   {
     "project": {
       "name": "my-app",
       "description": "My awesome app",
       "domain": "myapp.com"
     },
     "aws": {
       "region": "us-east-1",
       "profile": "default"
     },
     "environments": ["dev", "hml", "prd"],
     "infrastructure": {
       "instance_types": {
         "dev": "t4g.micro",
         "hml": "t4g.micro", 
         "prd": "t4g.small"
       }
     },
     "deployment": {
       "branches": {
         "production": "prd",
         "staging": "hml", 
         "development": "dev"
       }
     }
   }
   ```

3. **Set up GitHub environments and secrets**:
   ```bash
   ./setup-github-environments.sh
   ```

4. **Deploy everything automatically**:
   ```bash
   git add .
   git commit -m "Initial setup"
   git push origin dev  # Triggers dev deployment with auto-setup
   ```

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CloudFront    │────│       S3         │    │      EC2        │
│   (Frontend)    │    │   (React App)    │    │  Django + DB    │
│  myapp.com      │    │                  │    │  myapp.com/api  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                                              │
         │              ┌──────────────────┐            │
         └──────────────│   Route53 DNS    │────────────┘
                        │                  │
                        └──────────────────┘
```

## 📁 Project Structure

```
.
├── README.md                     # This file
├── CLAUDE.md                     # AI assistant instructions
├── config.json                   # Project configuration (create from example)
├── .env                          # Environment variables (create from example)
├── setup-github-environments.sh  # Setup script for GitHub
├── frontend/                     # React application
│   ├── src/
│   ├── package.json
│   └── ...
├── backend/                      # Django application
│   ├── src/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── ...
├── docker-compose.yml            # Local development setup
├── terraform/                    # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/
│       ├── frontend/
│       ├── backend/
│       └── dns/
└── .github/
    └── workflows/
        ├── infrastructure.yml    # Creates/updates AWS infrastructure
        ├── deploy.yml           # Deploys applications
        └── destroy.yml          # Destroys infrastructure (for cleanup)
```

## 🌍 Environments

The template supports three environments:

- **dev**: Development environment (triggered by pushes to `dev` branch)
  - URL: `dev.myapp.com`
  - API: `dev.myapp.com/api`

- **hml**: Staging/Homologation environment (triggered by pushes to `hml` branch)
  - URL: `hml.myapp.com`
  - API: `hml.myapp.com/api`

- **prd**: Production environment (triggered by pushes to `prd` branch)
  - URL: `myapp.com`
  - API: `myapp.com/api`

## 🔧 Configuration Files

### config.json
Main project configuration file:
- **project**: name, description, and domain
- **aws**: region and profile settings
- **environments**: list of supported environments (dev, hml, prd)
- **infrastructure**: EC2 instance types per environment
- **deployment**: branch mapping for each environment

### .env
Environment variables for the application:
- Database configuration
- Django settings
- API keys and secrets
- CORS settings

## 🚀 Deployment Process

1. **Infrastructure Creation**: Terraform creates all AWS resources
2. **Application Build**: React app is built with environment-specific configs
3. **Frontend Deployment**: Built files uploaded to S3, CloudFront invalidated
4. **Backend Deployment**: Django app deployed to EC2 via Docker Compose
5. **Health Checks**: Automated verification that services are running

## 🗑️ Cleanup

To completely remove all infrastructure:

1. **Via GitHub Actions** (recommended):
   ```bash
   gh workflow run destroy.yml -f environment=dev
   ```

2. **Manual cleanup**:
   ```bash
   cd terraform
   terraform workspace select dev
   terraform destroy
   ```

## 💰 Cost Estimation

Typical monthly costs per environment:
- EC2 t3.small: ~$15-20
- CloudFront: ~$1-5 (depending on traffic)
- Route53: ~$0.50
- S3: ~$1-3
- **Total per environment**: ~$18-30/month

## 🔒 Security Features

- HTTPS everywhere via CloudFront and ACM certificates
- Security groups restrict access to necessary ports only
- Environment isolation via separate AWS resources
- Secrets managed via GitHub environments
- No hardcoded credentials in code

## 📚 Customization

This template is designed to be easily customizable:

1. **Add new environments**: Update `config.json` and create corresponding branches
2. **Change instance types**: Modify the EC2 instance type in Terraform variables
3. **Add new services**: Extend the Docker Compose setup
4. **Custom domains**: Update DNS configuration in Terraform
5. **Monitoring**: Add CloudWatch alarms and dashboards

## 🐛 Troubleshooting

### Common Issues

1. **Domain not resolving**: Check Route53 hosted zone configuration
2. **SSL certificate issues**: Ensure domain validation is complete
3. **EC2 connection issues**: Verify security group rules
4. **GitHub Actions failing**: Check secrets and environment variables

### Useful Commands

```bash
# Check infrastructure status
gh workflow run infrastructure.yml -f environment=dev

# View deployment logs
gh run list --workflow=deploy.yml

# Debug EC2 instance
aws ssm start-session --target <instance-id>
```

## 🤝 Contributing

This template is designed to be a starting point. Feel free to:
- Fork and customize for your needs
- Submit improvements via pull requests
- Report issues and bugs
- Share your customizations with the community

## 📄 License

This template is open source and available under the MIT License.