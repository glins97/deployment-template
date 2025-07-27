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
    # For simple cases like .project.name, .environments, etc.
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
        echo "  Ubuntu/Debian: sudo apt install awscli terraform"
        echo "  macOS: brew install awscli terraform"
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

# Function to initialize Terraform backend
init_terraform_backend() {
    echo -e "${YELLOW}Initializing Terraform backend...${NC}"
    
    local project_name=$(get_json_value config.json ".project.name")
    local aws_region=$(get_json_value config.json ".aws.region")
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
    echo "✅ GitHub secrets configured"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. 🚀 Deploy your application:"
    echo "   - Go to Actions tab in your GitHub repository"
    echo "   - Run 'Deploy Infrastructure and Application' workflow"
    echo "   - This will deploy the full infrastructure and application"
    echo ""
    echo "2. 🔧 Monitor deployment:"
    echo "   - Check workflow logs for any issues"
    echo "   - Verify resources are created in AWS Console"
    echo "   - Test application endpoints after deployment"
    echo ""
    echo -e "${GREEN}Infrastructure ready for application deployment! 🚀${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting Infrastructure Setup...${NC}"
    echo ""
    
    # Step 1: Check prerequisites
    check_prerequisites
    echo ""
    
    # Step 2: Initialize Terraform backend
    init_terraform_backend
    echo ""
    
    # Step 3: Create EC2 key pair
    create_ec2_keypair
    echo ""
    
    # Step 4: Show next steps
    show_next_steps
}

# Run main function
main "$@"