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
            
            # Debug: Show value format for AWS credentials (masked)
            if [[ "$key" == "AWS_ACCESS_KEY_ID" ]]; then
                print_status "Debug: Setting AWS_ACCESS_KEY_ID (${value:0:8}...)"
            elif [[ "$key" == "AWS_SECRET_ACCESS_KEY" ]]; then
                print_status "Debug: Setting AWS_SECRET_ACCESS_KEY (length: ${#value}, ends: ...${value: -4})"
            fi
            
            # Set secret for each environment
            for env in "${ENVIRONMENTS[@]}"; do
                print_status "Setting secret $key for environment $env"
                
                # For AWS credentials, store as environment variables (visible)
                if [[ "$key" =~ ^AWS_ ]]; then
                    # Store as environment variable instead of secret for visibility
                    gh variable set "$key" --env "$env" --body "$value"
                    print_status "AWS credential $key stored as environment variable (visible)"
                    
                    # Verify the variable was set
                    if gh variable list --env "$env" | grep -q "^$key"; then
                        print_status "✅ AWS variable $key verified for $env"
                    else
                        print_error "❌ Failed to set AWS variable $key for $env"
                        exit 1
                    fi
                else
                    # Use printf with explicit binary mode to avoid encoding issues
                    printf "%s" "$value" | gh secret set "$key" \
                        --env "$env" \
                        --body -
                fi
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
    
    # Validate generated key
    if ! ssh-keygen -l -f "$SSH_KEY_PATH" >/dev/null 2>&1; then
        print_error "Failed to generate valid SSH key"
        rm -rf "$SSH_DIR"
        exit 1
    fi
    
    # Read private key
    PRIVATE_KEY=$(cat "$SSH_KEY_PATH")
    PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")
    
    # Validate key size (should be around 1600+ bytes for RSA 4096)
    KEY_SIZE=${#PRIVATE_KEY}
    if [ "$KEY_SIZE" -lt 1600 ]; then
        print_error "Generated private key is too small ($KEY_SIZE bytes). Expected 1600+ bytes."
        rm -rf "$SSH_DIR"
        exit 1
    fi
    
    print_status "Generated valid SSH key ($KEY_SIZE bytes)"
    
    # Set private key as secret for all environments
    for env in "${ENVIRONMENTS[@]}"; do
        # Use printf to ensure proper formatting and avoid newline issues
        printf '%s' "$PRIVATE_KEY" | gh secret set "EC2_PRIVATE_KEY" \
            --env "$env" \
            --body -
        
        if [ $? -eq 0 ]; then
            print_status "✅ SSH private key set for environment $env"
        else
            print_error "❌ Failed to set SSH private key for environment $env"
            rm -rf "$SSH_DIR"
            exit 1
        fi
        
        # Validate the secret was stored by attempting to retrieve it (this won't show the actual value)
        if gh secret list --env "$env" | grep -q "EC2_PRIVATE_KEY"; then
            print_status "✅ SSH key secret verified for environment $env"
        else
            print_error "❌ SSH key secret not found after setting for environment $env"
            rm -rf "$SSH_DIR"
            exit 1
        fi
    done
    
    # Save public key to file for manual setup
    cp "$SSH_KEY_PATH.pub" "./deploy_key_$PROJECT_NAME.pub"
    
    print_status "SSH key generated and saved as secret EC2_PRIVATE_KEY"
    print_status "Public key saved to: ./deploy_key_$PROJECT_NAME.pub"
    print_status "Private key size: $KEY_SIZE bytes (validated)"
    
    # Cleanup
    rm -rf "$SSH_DIR"
}

# Function to commit configuration files to repository
commit_config_files() {
    print_step "Committing configuration files to repository..."
    
    # Check if config.json is committed
    if ! git ls-files --error-unmatch config.json &> /dev/null; then
        print_status "Adding config.json to repository..."
        git add config.json
        git commit -m "Add project configuration file

This commit adds the configured config.json file with actual project settings
instead of the example values. This ensures GitHub Actions workflows can
read the proper configuration values for AWS region and other settings.

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
        print_status "config.json committed to repository"
    else
        print_status "config.json already tracked in repository"
    fi
    
    # Note: .env should NOT be committed as it contains secrets
    # Verify .env is in .gitignore
    if ! grep -q "^\.env$" .gitignore 2>/dev/null; then
        print_warning ".env file should be added to .gitignore to prevent committing secrets"
        echo ".env" >> .gitignore
        git add .gitignore
        git commit -m "Add .env to .gitignore to prevent committing secrets

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
        print_status ".env added to .gitignore"
    fi
}

# Function to create terraform backend configuration
create_terraform_backend() {
    print_step "Creating Terraform backend configuration..."
    
    # Create backend configuration file
    cat > terraform/backend.hcl <<EOF
# Terraform Backend Configuration
# This file is used to configure the S3 backend for Terraform state

bucket         = "${PROJECT_NAME}-terraform-state"
key            = "terraform.tfstate"
region         = "${AWS_REGION}"
encrypt        = true
dynamodb_table = "${PROJECT_NAME}-terraform-locks"
EOF

    print_status "Terraform backend configuration created: terraform/backend.hcl"
}

# Function to display summary
display_summary() {
    print_step "Setup Summary"
    
    echo ""
    echo "✅ Configuration files committed to repository"
    echo "✅ GitHub environments created: ${ENVIRONMENTS[*]}"
    echo "✅ Environment secrets configured from .env file"
    echo "✅ Environment variables set"
    echo "✅ SSH key generated for deployments"
    echo "✅ Terraform backend configuration created"
    echo ""
    
    print_status "Next steps:"
    echo "1. Deploy infrastructure: gh workflow run infrastructure.yml -f environment=dev"
    echo "2. Or simply push to dev/hml/prd branch to trigger everything automatically"
    echo ""
    echo "🚀 The infrastructure workflow will automatically:"
    echo "   - Create S3 bucket for Terraform state"
    echo "   - Create DynamoDB table for state locking"
    echo "   - Import EC2 key pair from the generated SSH key"
    echo "   - Deploy all AWS infrastructure via Terraform"
}

# Main execution
main() {
    echo "🚀 GitHub Environments Setup for $PROJECT_NAME"
    echo "================================================"
    
    check_prerequisites
    load_config
    get_repo_info
    commit_config_files
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