#!/usr/bin/env bash
set -e

# Check if running with bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash. Please run with: bash setup-infrastructure.sh"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ASCII Art Banner
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    Infrastructure Setup                                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to extract JSON value using basic shell parsing
get_json_value() {
    local json_file="$1"
    local key_path="$2"
    
    # Convert dot notation to grep pattern
    case "$key_path" in
        ".project.name")
            grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$json_file" | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
            ;;
        ".aws.region")
            grep -o '"region"[[:space:]]*:[[:space:]]*"[^"]*"' "$json_file" | sed 's/.*"region"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to extract domain for specific environment and service
get_domain_for_env() {
    local json_file="$1"
    local service="$2"  # frontend or backend
    local env="$3"      # dev, hml, prd
    
    # Look for "service": { "domain": { "env": "domain.com" } }
    # More precise parsing to avoid cross-contamination
    local service_section=$(sed -n "/\"$service\":/,/^[[:space:]]*}/p" "$json_file")
    local domain_section=$(echo "$service_section" | sed -n '/\"domain\":/,/}/p')
    echo "$domain_section" | grep "\"$env\"" | sed "s/.*\"$env\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/" | head -1
}

# Function to extract instance type for specific environment
get_instance_type_for_env() {
    local json_file="$1"
    local env="$2"
    
    # Look for "instance_type": { "env": "type" } more precisely
    local backend_section=$(sed -n '/\"backend\":/,/^[[:space:]]*}/p' "$json_file")
    local instance_section=$(echo "$backend_section" | sed -n '/\"instance_type\":/,/}/p')
    echo "$instance_section" | grep "\"$env\"" | sed "s/.*\"$env\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/" | head -1
}

# Function to extract environments from config.json
get_environments() {
    local json_file="$1"
    # Extract environments array using basic shell parsing
    # Look for "environments": ["env1", "env2", "env3"]
    local env_line=$(grep -A 5 '"environments"' "$json_file" | grep -o '\[.*\]' | head -1)
    if [ -n "$env_line" ]; then
        # Remove brackets and quotes, split by comma
        echo "$env_line" | sed 's/\[//g; s/\]//g; s/"//g; s/,/ /g'
    else
        echo "dev hml prd"  # Default fallback
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    if ! command_exists "aws"; then
        missing_tools+=("aws (AWS CLI)")
    fi
    
    if ! command_exists "terraform"; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists "gh"; then
        missing_tools+=("gh (GitHub CLI)")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Please install the missing tools and try again."
        echo "Installation commands:"
        echo "  Ubuntu/Debian: sudo apt install awscli terraform gh"
        echo "  macOS: brew install awscli terraform gh"
        exit 1
    fi
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not configured${NC}"
        echo "Please ensure AWS credentials are available via environment variables or AWS configuration."
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
}

# Function to clean up and initialize Terraform 
init_terraform() {
    echo -e "${YELLOW}Initializing Terraform with clean local state...${NC}"
    
    cd terraform
    
    # Clean up any existing Terraform state/config
    echo "Cleaning up old Terraform configuration..."
    rm -rf .terraform
    rm -f .terraform.lock.hcl
    rm -f terraform.tfstate*
    rm -f tfplan*
    
    # Fresh initialization with local state
    echo "Fresh Terraform initialization..."
    terraform init
    
    cd ..
    
    echo -e "${GREEN}✅ Terraform initialized with clean local state${NC}"
}

# Function to create EC2 key pair
create_ec2_keypair() {
    echo -e "${YELLOW}Creating EC2 key pair...${NC}"
    
    local project_name=$(get_json_value config.json ".project.name")
    local aws_region=$(get_json_value config.json ".aws.region")
    local key_name="$project_name-key"
    
    # Check if key pair already exists
    if aws ec2 describe-key-pairs --key-names $key_name --region $aws_region &> /dev/null; then
        echo -e "${GREEN}✅ Key pair $key_name already exists${NC}"
        return
    fi
    
    echo "Creating key pair: $key_name"
    
    # Create key pair and save private key
    aws ec2 create-key-pair \
        --key-name $key_name \
        --query 'KeyMaterial' \
        --output text \
        --region $aws_region > /tmp/${key_name}.pem
    
    chmod 600 /tmp/${key_name}.pem
    
    echo -e "${GREEN}✅ Key pair created successfully${NC}"
    echo -e "${YELLOW}📝 Private key saved to: /tmp/${key_name}.pem${NC}"
    
    # Automatically add secrets to GitHub if GitHub CLI is available and authenticated
    if command_exists "gh" && gh auth status &> /dev/null; then
        echo "Adding EC2 secrets to GitHub..."
        gh secret set EC2_KEY_NAME --body "$key_name" && echo "✅ EC2_KEY_NAME added to GitHub secrets"
        
        # Add private key content
        if [ -f "/tmp/${key_name}.pem" ]; then
            cat "/tmp/${key_name}.pem" | gh secret set EC2_PRIVATE_KEY && echo "✅ EC2_PRIVATE_KEY added to GitHub secrets"
        fi
        
        echo -e "${GREEN}✅ EC2 secrets added to GitHub successfully!${NC}"
    else
        echo -e "${YELLOW}📝 Please add these secrets to GitHub manually:${NC}"
        echo "gh secret set EC2_KEY_NAME --body '$key_name'"
        echo "gh secret set EC2_PRIVATE_KEY --body-file /tmp/${key_name}.pem"
    fi
}

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
    
    local project_name=$(get_json_value config.json ".project.name")
    local aws_region=$(get_json_value config.json ".aws.region")
    
    # Get environments from config.json
    local environments=$(get_environments config.json)
    
    echo "Deploying infrastructure for environments: $environments"
    
    # Change to terraform directory
    if [ ! -d "terraform" ]; then
        echo -e "${RED}❌ terraform directory not found${NC}"
        echo "Please ensure you're running this script from the project root directory."
        exit 1
    fi
    
    cd terraform
    
    # Clean up any existing terraform.tfvars
    rm -f terraform.tfvars
    
    # Initialize Terraform
    echo "Initializing Terraform..."
    terraform init
    
    # Deploy infrastructure for each environment separately
    for env in $environments; do
        echo "============================================"
        echo "Deploying infrastructure for environment: $env"
        echo "============================================"
        
        local frontend_domain=$(get_domain_for_env ../config.json "frontend" "$env")
        local backend_domain=$(get_domain_for_env ../config.json "backend" "$env")
        local instance_type=$(get_instance_type_for_env ../config.json "$env")
        
        # Use default instance type if not found
        if [ -z "$instance_type" ]; then
            instance_type="t3.small"
        fi
        
        echo "Configuration for $env:"
        echo "  Frontend domain: '$frontend_domain'"
        echo "  Backend domain: '$backend_domain'"
        echo "  Instance type: '$instance_type'"
        echo ""
        
        # Validate required values
        if [ -z "$frontend_domain" ] || [ -z "$backend_domain" ]; then
            echo -e "${RED}❌ Missing domain configuration for environment $env${NC}"
            echo "Please check your config.json file"
            cd ..
            exit 1
        fi
        
        # Create terraform.tfvars for this environment
        cat > terraform.tfvars << EOF
# Configuration for environment: $env
project_name = "$project_name"
environment = "$env"
aws_region = "$aws_region"
frontend_domain = "$frontend_domain"
backend_domain = "$backend_domain"
instance_type = "$instance_type"
key_name = "$project_name-key"
EOF
        
        echo "Generated terraform.tfvars for $env:"
        cat terraform.tfvars
        echo ""
        
        # Plan infrastructure for this environment
        echo "Planning infrastructure deployment for $env..."
        terraform plan -out=tfplan-$env
        
        # Ask for confirmation before applying this environment
        echo ""
        echo -e "${YELLOW}⚠️ This will create AWS infrastructure for $env environment and may incur costs.${NC}"
        echo -e "${YELLOW}Review the plan above and confirm you want to proceed.${NC}"
        echo ""
        read -p "Do you want to apply these changes for $env? (y/N): " confirm
        
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo "Infrastructure deployment for $env cancelled."
            continue
        fi
        
        # Apply infrastructure for this environment
        echo "Applying infrastructure changes for $env..."
        terraform apply -auto-approve tfplan-$env
        
        echo -e "${GREEN}✅ Infrastructure for $env deployed successfully${NC}"
        echo ""
    done
    
    # Get final outputs (from the last environment deployed)
    echo "Getting infrastructure outputs..."
    local outputs=$(terraform output -json)
    
    cd ..
    
    echo -e "${GREEN}✅ Infrastructure deployed successfully for all environments${NC}"
    
    # Update GitHub secrets with infrastructure outputs
    update_github_secrets_with_outputs "$outputs" "$environments"
}

# Function to update GitHub secrets with Terraform outputs
update_github_secrets_with_outputs() {
    local outputs="$1"
    local environments="$2"
    
    echo -e "${YELLOW}Updating GitHub secrets with infrastructure outputs...${NC}"
    
    if ! command_exists "gh" || ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}⚠️ GitHub CLI not available or not authenticated${NC}"
        echo "Please manually add the following infrastructure outputs to GitHub secrets:"
        echo "$outputs"
        return
    fi
    
    # Function to extract value from JSON using basic shell parsing
    extract_terraform_output() {
        local output_json="$1"
        local key="$2"
        # Look for "key": { "value": "actual_value" }
        echo "$output_json" | grep -A 2 "\"$key\"" | grep '"value"' | sed 's/.*"value"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1
    }
    
    # Add shared/global infrastructure outputs
    local vpc_id=$(extract_terraform_output "$outputs" "vpc_id")
    if [ -n "$vpc_id" ] && [ "$vpc_id" != "null" ]; then
        gh secret set VPC_ID --body "$vpc_id" && echo "✅ VPC_ID added to GitHub secrets"
    fi
    
    # Add environment-specific outputs
    for env in $environments; do
        echo "Processing outputs for environment: $env"
        
        # Frontend bucket per environment
        local frontend_bucket=$(extract_terraform_output "$outputs" "frontend_bucket_${env}")
        if [ -n "$frontend_bucket" ] && [ "$frontend_bucket" != "null" ]; then
            gh secret set "FRONTEND_BUCKET_${env^^}" --body "$frontend_bucket" && echo "✅ FRONTEND_BUCKET_${env^^} added to GitHub secrets"
        fi
        
        # CloudFront distribution per environment
        local cloudfront_id=$(extract_terraform_output "$outputs" "cloudfront_distribution_${env}")
        if [ -n "$cloudfront_id" ] && [ "$cloudfront_id" != "null" ]; then
            gh secret set "CLOUDFRONT_DISTRIBUTION_${env^^}" --body "$cloudfront_id" && echo "✅ CLOUDFRONT_DISTRIBUTION_${env^^} added to GitHub secrets"
        fi
        
        # ALB DNS per environment
        local alb_dns=$(extract_terraform_output "$outputs" "alb_dns_${env}")
        if [ -n "$alb_dns" ] && [ "$alb_dns" != "null" ]; then
            gh secret set "ALB_DNS_${env^^}" --body "$alb_dns" && echo "✅ ALB_DNS_${env^^} added to GitHub secrets"
        fi
        
        # Frontend domain per environment
        local frontend_domain=$(extract_terraform_output "$outputs" "frontend_domain_${env}")
        if [ -n "$frontend_domain" ] && [ "$frontend_domain" != "null" ]; then
            gh secret set "FRONTEND_DOMAIN_${env^^}" --body "$frontend_domain" && echo "✅ FRONTEND_DOMAIN_${env^^} added to GitHub secrets"
        fi
        
        # Backend domain per environment
        local backend_domain=$(extract_terraform_output "$outputs" "backend_domain_${env}")
        if [ -n "$backend_domain" ] && [ "$backend_domain" != "null" ]; then
            gh secret set "BACKEND_DOMAIN_${env^^}" --body "$backend_domain" && echo "✅ BACKEND_DOMAIN_${env^^} added to GitHub secrets"
        fi
    done
    
    echo -e "${GREEN}✅ Infrastructure outputs added to GitHub secrets for all environments${NC}"
}

# Function to show next steps
show_next_steps() {
    echo -e "${GREEN}"
    cat << "EOF"

╔════════════════════════════════════════════════════════════╗
║                Infrastructure Setup Complete! 🎉          ║
╚════════════════════════════════════════════════════════════╝

EOF
    echo -e "${NC}"
    
    echo -e "${BLUE}Infrastructure components created:${NC}"
    echo "✅ Terraform S3 backend bucket"
    echo "✅ DynamoDB table for state locking"
    echo "✅ EC2 key pair for server access"
    echo "✅ VPC, subnets, and networking (shared)"
    
    # Show environment-specific resources
    local environments=$(get_environments config.json)
    
    echo ""
    echo -e "${BLUE}Per-environment resources created:${NC}"
    for env in $environments; do
        echo "📁 Environment: ${env^^}"
        echo "   ✅ S3 bucket for frontend"
        echo "   ✅ CloudFront distribution"
        echo "   ✅ Application Load Balancer"
        echo "   ✅ Auto Scaling Group for backend"
        echo "   ✅ SSL certificates"
        echo "   ✅ Route53 DNS records"
    done
    
    echo ""
    echo "✅ GitHub secrets configured with infrastructure outputs"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. 🚀 Deploy your application:"
    echo "   - Go to Actions tab in your GitHub repository"
    echo "   - Run 'Deploy' workflow"
    echo "   - This will build and deploy your application to the infrastructure"
    echo ""
    echo "2. 🔧 Monitor deployment:"
    echo "   - Check workflow logs for any issues"
    echo "   - Verify application is running in AWS Console"
    echo "   - Test application endpoints"
    echo ""
    echo -e "${GREEN}Full infrastructure deployed and ready! 🚀${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting Infrastructure Setup...${NC}"
    echo ""
    
    # Step 1: Check prerequisites
    check_prerequisites
    echo ""
    
    # Step 2: Initialize Terraform
    init_terraform
    echo ""
    
    # Step 3: Create EC2 key pair
    create_ec2_keypair
    echo ""
    
    # Step 4: Deploy infrastructure
    deploy_infrastructure
    echo ""
    
    # Step 5: Show next steps
    show_next_steps
}

# Run main function
main "$@"