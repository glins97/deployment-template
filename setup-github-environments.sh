#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if required tools are installed
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install jq and try again."
        exit 1
    fi
    
    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is required but not installed. Please install gh and try again."
        exit 1
    fi
    
    # Check if user is authenticated with gh
    if ! gh auth status &> /dev/null; then
        print_error "You are not authenticated with GitHub CLI. Please run 'gh auth login' first."
        exit 1
    fi
    
    print_status "All prerequisites met!"
}

# Function to load configuration
load_config() {
    print_step "Loading configuration files..."
    
    # Check if config.json exists
    if [[ ! -f "config.json" ]]; then
        print_error "config.json not found. Please copy config.example.json to config.json and configure it."
        exit 1
    fi
    
    # Check if .env exists
    if [[ ! -f ".env" ]]; then
        print_error ".env file not found. Please copy .env.example to .env and configure it."
        exit 1
    fi
    
    # Parse config.json
    PROJECT_NAME=$(jq -r '.project.name' config.json)
    PROJECT_DESCRIPTION=$(jq -r '.project.description' config.json)
    DOMAIN=$(jq -r '.project.domain' config.json)
    AWS_REGION=$(jq -r '.aws.region' config.json)
    ENVIRONMENTS=($(jq -r '.environments[]' config.json))
    
    # Get instance types for each environment
    DEV_INSTANCE_TYPE=$(jq -r '.infrastructure.instance_types.dev' config.json)
    HML_INSTANCE_TYPE=$(jq -r '.infrastructure.instance_types.hml' config.json)
    PRD_INSTANCE_TYPE=$(jq -r '.infrastructure.instance_types.prd' config.json)
    
    # Validate required fields
    if [[ "$PROJECT_NAME" == "null" || "$DOMAIN" == "null" ]]; then
        print_error "project.name and project.domain are required in config.json"
        exit 1
    fi
    
    print_status "Configuration loaded: $PROJECT_NAME ($DOMAIN)"
}

# Function to get repository information
get_repo_info() {
    print_step "Getting repository information..."
    
    # Get current repository
    REPO_OWNER=$(gh repo view --json owner --jq .owner.login)
    REPO_NAME=$(gh repo view --json name --jq .name)
    
    if [[ -z "$REPO_OWNER" || -z "$REPO_NAME" ]]; then
        print_error "Could not determine repository information. Make sure you're in a GitHub repository."
        exit 1
    fi
    
    print_status "Repository: $REPO_OWNER/$REPO_NAME"
}

# Function to create GitHub environments
create_environments() {
    print_step "Creating GitHub environments..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        print_status "Creating environment: $env"
        
        # Create environment (this will succeed even if it already exists)
        gh api \
            --method PUT \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "/repos/$REPO_OWNER/$REPO_NAME/environments/$env" \
            --silent || true
            
        print_status "Environment $env created/updated"
    done
}

# Function to set environment secrets
set_environment_secrets() {
    print_step "Setting environment secrets..."
    
    # Read .env file and process each line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Extract key and value
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            
            # Remove surrounding quotes if present
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            
            # Set secret for each environment
            for env in "${ENVIRONMENTS[@]}"; do
                print_status "Setting secret $key for environment $env"
                
                echo "$value" | gh secret set "$key" \
                    --env "$env" \
                    --body -
            done
        fi
    done < .env
}

# Function to set environment variables (non-secret configuration)
set_environment_variables() {
    print_step "Setting environment variables..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        # Set domain-related variables
        if [[ "$env" == "prd" ]]; then
            FRONTEND_DOMAIN="$DOMAIN"
            API_DOMAIN="$DOMAIN"
        else
            FRONTEND_DOMAIN="$env.$DOMAIN"
            API_DOMAIN="$env.$DOMAIN"
        fi
        
        # Set instance type based on environment
        case "$env" in
            "dev")
                INSTANCE_TYPE="$DEV_INSTANCE_TYPE"
                ;;
            "hml")
                INSTANCE_TYPE="$HML_INSTANCE_TYPE"
                ;;
            "prd")
                INSTANCE_TYPE="$PRD_INSTANCE_TYPE"
                ;;
            *)
                INSTANCE_TYPE="t4g.micro"
                ;;
        esac
        
        # Set variables using GitHub CLI
        gh variable set "PROJECT_NAME" --env "$env" --body "$PROJECT_NAME"
        gh variable set "ENVIRONMENT" --env "$env" --body "$env"
        gh variable set "DOMAIN" --env "$env" --body "$DOMAIN"
        gh variable set "FRONTEND_DOMAIN" --env "$env" --body "$FRONTEND_DOMAIN"
        gh variable set "API_DOMAIN" --env "$env" --body "$API_DOMAIN"
        gh variable set "AWS_REGION" --env "$env" --body "$AWS_REGION"
        gh variable set "INSTANCE_TYPE" --env "$env" --body "$INSTANCE_TYPE"
        
        print_status "Variables set for environment $env"
    done
}

# Function to generate SSH key for deployments
generate_ssh_key() {
    print_step "Generating SSH key for deployments..."
    
    # Create temporary directory for SSH keys
    SSH_DIR=$(mktemp -d)
    SSH_KEY_PATH="$SSH_DIR/deploy_key"
    
    # Generate SSH key pair
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "github-actions-$PROJECT_NAME"
    
    # Read private key
    PRIVATE_KEY=$(cat "$SSH_KEY_PATH")
    PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")
    
    # Set private key as secret for all environments
    for env in "${ENVIRONMENTS[@]}"; do
        echo "$PRIVATE_KEY" | gh secret set "EC2_PRIVATE_KEY" \
            --env "$env" \
            --body -
    done
    
    # Save public key to file for manual setup
    cp "$SSH_KEY_PATH.pub" "./deploy_key_$PROJECT_NAME.pub"
    
    print_warning "IMPORTANT: You need to manually add the public key to your AWS EC2 key pairs."
    print_warning "Public key saved to: ./deploy_key_$PROJECT_NAME.pub"
    print_warning "AWS Console: EC2 → Key Pairs → Import Key Pair"
    print_warning "Key name should be: $PROJECT_NAME-deploy-key"
    
    # Cleanup
    rm -rf "$SSH_DIR"
}

# Function to create terraform backend configuration
create_terraform_backend() {
    print_step "Creating Terraform backend configuration..."
    
    # Create backend configuration file
    cat > terraform/backend.hcl <<EOF
# Terraform Backend Configuration
# This file is used to configure the S3 backend for Terraform state

# You need to create these resources manually before running terraform:
# 1. S3 bucket for state storage: ${PROJECT_NAME}-terraform-state
# 2. DynamoDB table for state locking: ${PROJECT_NAME}-terraform-locks

bucket         = "${PROJECT_NAME}-terraform-state"
key            = "terraform.tfstate"
region         = "${AWS_REGION}"
encrypt        = true
dynamodb_table = "${PROJECT_NAME}-terraform-locks"
EOF

    print_status "Terraform backend configuration created: terraform/backend.hcl"
    print_warning "You need to manually create:"
    print_warning "1. S3 bucket: ${PROJECT_NAME}-terraform-state"
    print_warning "2. DynamoDB table: ${PROJECT_NAME}-terraform-locks"
}

# Function to display summary
display_summary() {
    print_step "Setup Summary"
    
    echo ""
    echo "✅ GitHub environments created: ${ENVIRONMENTS[*]}"
    echo "✅ Environment secrets configured from .env file"
    echo "✅ Environment variables set"
    echo "✅ SSH key generated for deployments"
    echo "✅ Terraform backend configuration created"
    echo ""
    
    print_warning "Manual steps required:"
    echo "1. Create S3 bucket: ${PROJECT_NAME}-terraform-state"
    echo "2. Create DynamoDB table: ${PROJECT_NAME}-terraform-locks" 
    echo "3. Import SSH public key to AWS EC2: deploy_key_${PROJECT_NAME}.pub"
    echo "4. Update terraform/main.tf with your backend configuration"
    echo ""
    
    print_status "After completing manual steps, you can:"
    echo "- Push code to trigger deployments"
    echo "- Run infrastructure workflow: gh workflow run infrastructure.yml"
    echo "- Monitor deployments: gh run list"
}

# Main execution
main() {
    echo "🚀 GitHub Environments Setup for $PROJECT_NAME"
    echo "================================================"
    
    check_prerequisites
    load_config
    get_repo_info
    create_environments
    set_environment_secrets
    set_environment_variables
    generate_ssh_key
    create_terraform_backend
    display_summary
    
    print_status "Setup completed successfully! 🎉"
}

# Run main function
main "$@"