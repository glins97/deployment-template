# Claude AI Assistant Instructions

This document contains instructions for AI assistants working on this deployment template project.

## Project Overview

This is a **deployment template** for full-stack applications with:
- **Frontend**: React app deployed to S3 + CloudFront
- **Backend**: Django API deployed to EC2 with Docker Compose  
- **Database**: PostgreSQL in Docker on EC2
- **Infrastructure**: AWS resources via Terraform
- **CI/CD**: GitHub Actions automation
- **Environments**: dev, hml (staging), prd

## Key Architecture Decisions

### Infrastructure Approach
- **No Load Balancer**: CloudFront handles HTTPS termination and routing
- **Single EC2 Instance**: Backend + DB on same instance for cost efficiency
- **Terraform Modules**: Organized in `/terraform/modules/` for reusability
- **GitHub Actions**: All automation via workflows, no local scripts except setup

### URL Structure
- Frontend: `domain.com`, `dev.domain.com`, `hml.domain.com`
- Backend API: `domain.com/api`, `dev.domain.com/api`, `hml.domain.com/api`
- CloudFront routes `/api/*` to EC2, everything else to S3

### Environment Management
- GitHub Environments: dev, hml, prd with isolated secrets
- Terraform Workspaces: separate state per environment
- Branch-based deployment: prd→prd, hml→hml, dev→dev

## File Structure and Conventions

```
/
├── config.json              # Project configuration (from config.example.json)
├── .env                     # Environment variables (from .env.example)  
├── setup-github-environments.sh  # One-time setup script
├── terraform/               # Infrastructure as Code
│   ├── main.tf             # Root terraform configuration
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   └── modules/            # Reusable modules
│       ├── vpc/            # VPC, subnets, security groups
│       ├── frontend/       # S3 + CloudFront + ACM
│       ├── backend/        # EC2 instance + security groups
│       └── dns/            # Route53 hosted zone + records
├── .github/workflows/      # CI/CD automation
│   ├── infrastructure.yml  # Create/update infrastructure
│   ├── deploy.yml         # Deploy applications  
│   └── destroy.yml        # Clean up infrastructure
├── frontend/              # React application
└── backend/               # Django application
```

## Configuration Files

### config.json
```json
{
  "project": {
    "name": "my-app",           # Used for AWS resource naming
    "description": "...",       # Project description
    "domain": "myapp.com"       # Root domain for all environments
  },
  "aws": {
    "region": "us-east-1",      # AWS region
    "profile": "default"        # AWS CLI profile
  },
  "environments": ["dev", "hml", "prd"],  # Supported environments
  "infrastructure": {
    "instance_types": {         # EC2 instance types per environment
      "dev": "t4g.micro",
      "hml": "t4g.micro", 
      "prd": "t4g.small"
    }
  },
  "deployment": {
    "branches": {               # Branch mapping for deployments
      "production": "prd",
      "staging": "hml", 
      "development": "dev"
    }
  }
}
```

### .env (used for GitHub environment variables)
Contains all application configuration:
- Django settings (SECRET_KEY, DEBUG, ALLOWED_HOSTS)
- Database configuration
- CORS settings
- API keys and external service configurations

## Terraform Conventions

### Naming Convention
- Resources: `${var.project_name}-${var.environment}-${resource_type}`
- Example: `myapp-dev-frontend-bucket`, `myapp-prd-backend-instance`

### Variables Pattern
All modules should accept:
- `project_name` - from config.json
- `environment` - dev/hml/prd  
- `domain` - root domain from config.json

### Outputs Pattern
Always output resource identifiers needed for deployment:
- S3 bucket names
- CloudFront distribution IDs
- EC2 instance IDs
- Security group IDs

## GitHub Actions Conventions

### Workflow Triggers
- `infrastructure.yml`: Manual dispatch or on terraform changes
- `deploy.yml`: Branch pushes (main→prd, staging→hml, develop→dev)
- `destroy.yml`: Manual dispatch only (for cleanup)

### Environment Variables
Workflows should read from:
1. `config.json` for project configuration
2. GitHub environment secrets for credentials
3. Terraform outputs for resource identifiers

### Secrets Management
Required secrets per environment:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`  
- `EC2_PRIVATE_KEY` (for SSH deployment)
- All variables from `.env` file

## Development Guidelines

### When Working on This Project:

1. **Always test infrastructure changes in dev first**
2. **Use Terraform workspaces for environment isolation**
3. **Follow the existing naming conventions**
4. **Update both example files when adding new configuration**
5. **Test the complete flow: setup → infrastructure → deploy → destroy**

### Common Tasks:

#### Adding a New Environment
1. Add to `environments` array in config.json
2. Create corresponding branch
3. Run setup script to create GitHub environment
4. Test infrastructure creation

#### Adding New AWS Resources
1. Create/update appropriate Terraform module
2. Add outputs for deployment workflows
3. Update GitHub Actions if needed
4. Test in dev environment first

#### Modifying Application Configuration
1. Update `.env.example` with new variables
2. Update setup script to handle new variables
3. Update GitHub Actions to pass new environment variables
4. Document changes in README.md

## Testing Commands

When working on this project, use these commands for testing:

```bash
# Lint and typecheck (when available)
npm run lint              # Frontend linting
npm run typecheck         # Frontend type checking
python -m flake8          # Backend linting
python manage.py check    # Django configuration check

# Local development
docker-compose up         # Start all services locally
npm test                  # Run frontend tests
python manage.py test     # Run backend tests

# Infrastructure testing
terraform plan            # Preview infrastructure changes
terraform validate       # Validate terraform syntax
```

## Cost Optimization Notes

This template is designed for cost efficiency:
- Single EC2 instance instead of separate RDS
- t3.small instances for non-production
- CloudFront instead of Application Load Balancer
- Minimal S3 storage costs

When suggesting improvements, always consider cost impact.

## Security Considerations

- All HTTPS via CloudFront + ACM certificates
- Security groups restrict access to necessary ports only
- No hardcoded credentials in any files
- Environment-specific secrets via GitHub environments
- EC2 instances in private subnets (if VPC module supports it)

## Troubleshooting Common Issues

1. **Terraform state conflicts**: Use workspaces properly
2. **DNS propagation delays**: Wait 5-10 minutes after Route53 changes
3. **CloudFront cache issues**: Always invalidate after frontend deploys
4. **EC2 SSH access**: Ensure security groups allow SSH from GitHub Actions IPs
5. **Certificate validation**: Ensure domain ownership for ACM certificates