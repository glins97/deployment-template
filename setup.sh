#!/bin/bash
set -e

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
║    _____ _               ____  __            _____           ║
║   / ____| |             |  _ \/ _|          |  ___|          ║
║  | (___ | |_ __ _ _ __   | |_) | |_ _ __ ____ | |___           ║
║   \___ \| | '_ ` | '_ \  |  _ <|  _| '_ \_  _||  ___|         ║
║   ____) | | | | | | | | | |_) | | | | | / / | |___           ║
║  |_____/|_|_| |_|_| |_| |____/|_| |_| |_\__\ |_____|         ║
║                                                              ║
║              Full Stack Deployment Template                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate config.json
validate_config() {
    echo -e "${YELLOW}Validating config.json...${NC}"
    
    if [ ! -f "config.json" ]; then
        echo -e "${RED}❌ config.json not found!${NC}"
        echo "Please ensure config.json exists in the current directory."
        exit 1
    fi
    
    # Check if jq can parse the file
    if ! jq empty config.json 2>/dev/null; then
        echo -e "${RED}❌ config.json is not valid JSON!${NC}"
        exit 1
    fi
    
    # Check required fields
    local required_fields=(".project.name" ".aws.region" ".environments" ".infrastructure.frontend.domain" ".infrastructure.backend.domain" ".github.repository")
    
    for field in "${required_fields[@]}"; do
        if [ "$(jq -r "$field" config.json)" = "null" ]; then
            echo -e "${RED}❌ Missing required field: $field${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✅ config.json is valid${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    if ! command_exists "jq"; then
        missing_tools+=("jq")
    fi
    
    if ! command_exists "gh"; then
        missing_tools+=("gh (GitHub CLI)")
    fi
    
    if ! command_exists "aws"; then
        missing_tools+=("aws (AWS CLI)")
    fi
    
    if ! command_exists "terraform"; then
        missing_tools+=("terraform")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check GitHub CLI authentication
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI is not authenticated${NC}"
        echo "Please run: gh auth login"
        exit 1
    fi
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not configured${NC}"
        echo "Please run: aws configure"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
}

# Function to setup .env file
setup_env_file() {
    echo -e "${YELLOW}Setting up .env file...${NC}"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            echo "Creating .env from .env.example..."
            cp .env.example .env
            echo -e "${YELLOW}📝 Please edit .env file with your actual values before proceeding${NC}"
            read -p "Press Enter when you've updated the .env file..."
        else
            echo -e "${RED}❌ No .env or .env.example file found${NC}"
            echo "Please create a .env file with your configuration."
            exit 1
        fi
    else
        echo -e "${GREEN}✅ .env file exists${NC}"
    fi
}

# Function to create GitHub environments
setup_github_environments() {
    echo -e "${YELLOW}Setting up GitHub environments...${NC}"
    
    if [ -f "scripts/setup-github-environments.sh" ]; then
        ./scripts/setup-github-environments.sh
    else
        echo -e "${RED}❌ setup-github-environments.sh script not found${NC}"
        exit 1
    fi
}

# Function to upload secrets
upload_secrets() {
    echo -e "${YELLOW}Uploading secrets to GitHub...${NC}"
    
    if [ -f "scripts/env-to-secrets.sh" ]; then
        ./scripts/env-to-secrets.sh
    else
        echo -e "${RED}❌ env-to-secrets.sh script not found${NC}"
        exit 1
    fi
}

# Function to initialize Terraform backend
init_terraform_backend() {
    echo -e "${YELLOW}Initializing Terraform backend...${NC}"
    
    local project_name=$(jq -r '.project.name' config.json)
    local aws_region=$(jq -r '.aws.region' config.json)
    local bucket_name="$project_name-terraform-state"
    
    echo "Creating S3 bucket for Terraform state: $bucket_name"
    
    # Create S3 bucket
    aws s3 mb s3://$bucket_name --region $aws_region 2>/dev/null || echo "Bucket already exists"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket $bucket_name \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket $bucket_name \
        --server-side-encryption-configuration '{
          "Rules": [
            {
              "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
              }
            }
          ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket $bucket_name \
        --public-access-block-configuration \
          BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    # Create DynamoDB table for state locking
    aws dynamodb create-table \
        --table-name "$project_name-terraform-locks" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region $aws_region 2>/dev/null || echo "DynamoDB table already exists"
    
    echo -e "${GREEN}✅ Terraform backend initialized${NC}"
}

# Function to create EC2 key pair
create_ec2_keypair() {
    echo -e "${YELLOW}Creating EC2 key pair...${NC}"
    
    local project_name=$(jq -r '.project.name' config.json)
    local aws_region=$(jq -r '.aws.region' config.json)
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
    echo -e "${YELLOW}📝 Please add this private key as EC2_PRIVATE_KEY secret in GitHub${NC}"
    echo -e "${YELLOW}📝 Also add the key name '$key_name' as EC2_KEY_NAME secret${NC}"
    
    # Update .env file with key name
    if grep -q "EC2_KEY_NAME=" .env; then
        sed -i "s/EC2_KEY_NAME=.*/EC2_KEY_NAME=$key_name/" .env
    else
        echo "EC2_KEY_NAME=$key_name" >> .env
    fi
    
    # Update .env file with private key content
    if grep -q "EC2_PRIVATE_KEY=" .env; then
        sed -i "s|EC2_PRIVATE_KEY=.*|EC2_PRIVATE_KEY=$(cat /tmp/${key_name}.pem | tr '\n' '\\n')|" .env
    else
        echo "EC2_PRIVATE_KEY=$(cat /tmp/${key_name}.pem | tr '\n' '\\n')" >> .env
    fi
}

# Function to show next steps
show_next_steps() {
    echo -e "${GREEN}"
    cat << "EOF"

╔════════════════════════════════════════════════════════════╗
║                    Setup Complete! 🎉                     ║
╚════════════════════════════════════════════════════════════╝

EOF
    echo -e "${NC}"
    
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. 📋 Review your GitHub repository settings:"
    echo "   - Environments: dev, hml, prd"
    echo "   - Secrets are configured"
    echo ""
    echo "2. 🚀 Deploy infrastructure:"
    echo "   - Go to Actions tab in your GitHub repository"
    echo "   - Run 'Setup Initial Infrastructure' workflow first"
    echo "   - Then run 'Deploy Infrastructure and Application' workflow"
    echo ""
    echo "3. 🔧 Configure your application:"
    echo "   - Update frontend/ and backend/ directories with your code"
    echo "   - Ensure docker-compose.yml is properly configured"
    echo "   - Update domain names in config.json"
    echo ""
    echo "4. 📚 Documentation:"
    echo "   - Review README.md for detailed instructions"
    echo "   - Check terraform/ directory for infrastructure details"
    echo ""
    echo -e "${GREEN}Happy deploying! 🚀${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting Full Stack Deployment Template Setup...${NC}"
    echo ""
    
    # Step 1: Validate config
    validate_config
    echo ""
    
    # Step 2: Check prerequisites
    check_prerequisites
    echo ""
    
    # Step 3: Setup .env file
    setup_env_file
    echo ""
    
    # Step 4: Initialize Terraform backend
    init_terraform_backend
    echo ""
    
    # Step 5: Create EC2 key pair
    create_ec2_keypair
    echo ""
    
    # Step 6: Setup GitHub environments
    setup_github_environments
    echo ""
    
    # Step 7: Upload secrets
    echo -e "${YELLOW}Would you like to upload secrets to GitHub now? (y/n)${NC}"
    read -p "> " upload_now
    if [[ $upload_now =~ ^[Yy]$ ]]; then
        upload_secrets
        echo ""
    fi
    
    # Step 8: Show next steps
    show_next_steps
}

# Run main function
main "$@"