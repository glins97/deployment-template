#!/usr/bin/env bash
set -e

# Check if running with bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash. Please run with: bash setup-repository.sh"
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
║    Repository & Environment Setup                            ║
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
        ".aws.credentials.access_key_id")
            grep -A 5 '"credentials"' "$json_file" | grep '"access_key_id"' | sed 's/.*"access_key_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
            ;;
        ".aws.credentials.secret_access_key")
            grep -A 5 '"credentials"' "$json_file" | grep '"secret_access_key"' | sed 's/.*"secret_access_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
            ;;
        ".github.repository")
            grep -o '"repository"[[:space:]]*:[[:space:]]*"[^"]*"' "$json_file" | sed 's/.*"repository"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to validate config.json
validate_config() {
    echo -e "${YELLOW}Validating config.json...${NC}"
    
    # Check if actual config.json exists, if not create from template
    if [ ! -f "config.json" ]; then
        if [ -f "config.example.json" ]; then
            echo "Creating config.json from config.example.json..."
            cp config.example.json config.json
            echo -e "${YELLOW}📝 Please edit config.json with your actual project configuration${NC}"
            echo ""
            echo "Required updates:"
            echo "  - project.name: Your project name"
            echo "  - infrastructure domains: Your actual domain names"  
            echo "  - github.repository: Your GitHub repository (owner/repo-name)"
            echo "  - aws.credentials: Your AWS access key and secret key"
            echo ""
            read -p "Press Enter when you've updated config.json..."
        else
            echo -e "${RED}❌ config.example.json not found!${NC}"
            echo "Please ensure config.example.json exists in the current directory."
            exit 1
        fi
    fi
    
    # Basic JSON validation - check for balanced braces
    if ! grep -q '^{' config.json || ! grep -q '}$' config.json; then
        echo -e "${RED}❌ config.json appears to be malformed!${NC}"
        exit 1
    fi
    
    # Check required fields using basic shell parsing
    local required_checks=("project" "aws" "environments" "infrastructure" "github")
    
    for section in "${required_checks[@]}"; do
        if ! grep -q "\"$section\"" config.json; then
            echo -e "${RED}❌ Missing required section: $section${NC}"
            exit 1
        fi
    done
    
    # Check specific required values
    local project_name=$(get_json_value config.json ".project.name")
    local aws_region=$(get_json_value config.json ".aws.region")
    local github_repo=$(get_json_value config.json ".github.repository")
    local aws_access_key=$(get_json_value config.json ".aws.credentials.access_key_id")
    local aws_secret_key=$(get_json_value config.json ".aws.credentials.secret_access_key")
    
    if [ -z "$project_name" ] || [ "$project_name" = "unknown" ] || [ "$project_name" = "my-fullstack-app" ]; then
        echo -e "${RED}❌ Missing or placeholder project.name in config.json${NC}"
        exit 1
    fi
    
    if [ -z "$aws_region" ] || [ "$aws_region" = "unknown" ]; then
        echo -e "${RED}❌ Missing or invalid aws.region in config.json${NC}"
        exit 1
    fi
    
    if [ -z "$github_repo" ] || [ "$github_repo" = "unknown" ] || [ "$github_repo" = "owner/repo-name" ]; then
        echo -e "${RED}❌ Missing or placeholder github.repository in config.json${NC}"
        exit 1
    fi
    
    # Warn about AWS credentials but don't exit (they can be added later)
    if [ -z "$aws_access_key" ] || [ "$aws_access_key" = "unknown" ] || [ "$aws_access_key" = "your_aws_access_key_id" ] || \
       [ -z "$aws_secret_key" ] || [ "$aws_secret_key" = "unknown" ] || [ "$aws_secret_key" = "your_aws_secret_access_key" ]; then
        echo -e "${YELLOW}⚠️ AWS credentials appear to be placeholder values in config.json${NC}"
        echo -e "${YELLOW}   You'll need to add real AWS credentials before deployment${NC}"
    fi
    
    echo -e "${GREEN}✅ config.json is valid${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    if ! command_exists "gh"; then
        missing_tools+=("gh (GitHub CLI)")
    fi
    
    if ! command_exists "aws"; then
        missing_tools+=("aws (AWS CLI)")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Please install the missing tools and try again."
        echo "Installation commands:"
        echo "  Ubuntu/Debian: sudo apt install gh awscli"
        echo "  macOS: brew install gh awscli"
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

# Function to validate Route53 hosted zones
validate_hosted_zones() {
    echo -e "${YELLOW}Validating Route53 hosted zones...${NC}"
    
    # Extract domains from config.json using grep/sed
    local environments=("dev" "hml" "prd")  # Default environments
    local all_domains=()
    
    # Extract frontend and backend domains for each environment
    for env in "${environments[@]}"; do
        if [ "$env" = "prd" ]; then
            # For production, look for domain without env prefix
            local frontend_domain=$(grep -A 10 '"frontend"' config.json | grep -A 5 '"domain"' | grep '"prd"' | sed 's/.*"prd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            local backend_domain=$(grep -A 15 '"backend"' config.json | grep -A 5 '"domain"' | grep '"prd"' | sed 's/.*"prd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        else
            local frontend_domain=$(grep -A 10 '"frontend"' config.json | grep -A 5 '"domain"' | grep "\"$env\"" | sed "s/.*\"$env\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/")
            local backend_domain=$(grep -A 15 '"backend"' config.json | grep -A 5 '"domain"' | grep "\"$env\"" | sed "s/.*\"$env\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/")
        fi
        
        if [ -n "$frontend_domain" ] && [ "$frontend_domain" != "example.com" ]; then
            all_domains+=("$frontend_domain")
        fi
        if [ -n "$backend_domain" ] && [ "$backend_domain" != "backend.example.com" ]; then
            all_domains+=("$backend_domain")
        fi
    done
    
    # Extract unique root domains
    local root_domains=()
    for domain in "${all_domains[@]}"; do
        local root_domain=$(echo "$domain" | awk -F. '{print $(NF-1)"."$NF}')
        if [[ ! " ${root_domains[@]} " =~ " ${root_domain} " ]]; then
            root_domains+=("$root_domain")
        fi
    done
    
    echo "Checking hosted zones for domains: ${root_domains[*]}"
    
    # Function to check individual hosted zone
    check_hosted_zone() {
        local domain=$1
        # Route53 hosted zones have trailing dots, so we check for both formats
        local zone_info=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${domain}.' || Name=='${domain}']" --output json 2>/dev/null)
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Error checking Route53 for domain '$domain'${NC}"
            echo "Please ensure AWS CLI is configured correctly."
            return 1
        fi
        
        if [ -z "$zone_info" ] || [ "$zone_info" = "[]" ] || ! echo "$zone_info" | grep -q '"Id"'; then
            echo -e "${RED}❌ Route53 hosted zone for '$domain' not found!${NC}"
            echo "Please create a hosted zone for '$domain' in Route53 before proceeding."
            echo "You can create it manually in AWS Console or use:"
            echo "aws route53 create-hosted-zone --name $domain --caller-reference \$(date +%s)"
            return 1
        else
            local zone_id=$(echo "$zone_info" | grep -o '"Id": "[^"]*"' | head -1 | sed 's/.*"Id": "\([^"]*\)".*/\1/' | sed 's|/hostedzone/||')
            echo -e "${GREEN}✅ Hosted zone for '$domain' found (ID: $zone_id)${NC}"
            return 0
        fi
    }
    
    # Check all root domains
    local failed_checks=0
    for domain in "${root_domains[@]}"; do
        check_hosted_zone "$domain" || failed_checks=$((failed_checks + 1))
    done
    
    if [ $failed_checks -gt 0 ]; then
        echo ""
        echo -e "${RED}❌ $failed_checks hosted zone(s) are missing.${NC}"
        echo ""
        echo -e "${YELLOW}📋 Current hosted zones in your AWS account:${NC}"
        aws route53 list-hosted-zones --query 'HostedZones[].{Name:Name,ID:Id}' --output table 2>/dev/null || {
            echo "Unable to list hosted zones. Please check AWS CLI configuration."
        }
        echo ""
        echo "Please create the missing hosted zones in Route53 and update your domain's nameservers."
        echo ""
        echo "After creating the hosted zones, you can run this script again."
        exit 1
    fi
    
    echo -e "${GREEN}✅ All required hosted zones are available!${NC}"
}

# Function to setup .env file
setup_env_file() {
    echo -e "${YELLOW}Setting up .env file...${NC}"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            echo "Creating .env from .env.example..."
            cp .env.example .env
            echo -e "${YELLOW}📝 .env.example has been copied to .env${NC}"
            echo -e "${YELLOW}📝 Add your PROJECT-SPECIFIC environment variables to .env${NC}"
            echo -e "${YELLOW}📝 Do NOT add deployment secrets (AWS keys, EC2 keys) to .env${NC}"
            echo ""
            echo "Example project variables (if your project needs them):"
            echo "  DATABASE_URL=postgresql://localhost:5432/myapp"
            echo "  JWT_SECRET=your-jwt-secret"
            echo "  API_KEY=your-api-key"
            echo ""
            read -p "Press Enter when you've updated the .env file with your project variables..."
        else
            echo -e "${RED}❌ No .env or .env.example file found${NC}"
            echo "Please create a .env file with your project-specific configuration."
            exit 1
        fi
    else
        echo -e "${GREEN}✅ .env file exists${NC}"
        echo -e "${YELLOW}📝 Ensure .env contains only PROJECT-SPECIFIC variables${NC}"
    fi
}

# Function to create GitHub environments
setup_github_environments() {
    echo -e "${YELLOW}Setting up GitHub environments...${NC}"
    
    # Extract values from config.json
    local project_name=$(get_json_value config.json ".project.name")
    local repository=$(get_json_value config.json ".github.repository")
    local environments=("dev" "hml" "prd")
    
    echo -e "${GREEN}Setting up GitHub environments for $project_name${NC}"
    echo "Repository: $repository"
    echo "Environments: ${environments[*]}"
    echo -e "${GREEN}Starting GitHub environment setup...${NC}"
    
    # Function to create environment
    create_environment() {
        local env_name=$1
        echo -e "${YELLOW}Creating environment: $env_name${NC}"
        
        # Create environment
        gh api repos/$repository/environments/$env_name -X PUT --silent || {
            echo -e "${GREEN}Environment $env_name already exists or created successfully${NC}"
        }
        
        # Set environment protection rules for production
        if [ "$env_name" = "prd" ]; then
            echo "Setting protection rules for production environment..."
            # Create a temporary JSON file for the protection rules
            cat > /tmp/protection_rules.json << EOF
{
  "wait_timer": 0,
  "prevent_self_review": false,
  "reviewers": [],
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}
EOF
            gh api repos/$repository/environments/$env_name -X PUT \
                --input /tmp/protection_rules.json \
                --silent 2>/dev/null && echo "✅ Protection rules configured" || echo "⚠️ Protection rules configuration skipped"
            rm -f /tmp/protection_rules.json
        fi
    }
    
    # Function to add secrets to environment
    add_environment_secrets() {
        local env_name=$1
        echo -e "${YELLOW}Adding secrets to environment: $env_name${NC}"
        
        # Read .env file if it exists
        if [ -f ".env" ]; then
            while IFS='=' read -r key value; do
                # Skip empty lines and comments
                [[ -z "$key" || "$key" =~ ^#.*$ ]] && continue
                
                # Remove quotes from value if present
                value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
                
                echo "Adding secret: $key"
                echo "$value" | gh secret set "$key" --env "$env_name"
            done < .env
        fi
    }
    
    # Create environments (without secrets)
    for env in "${environments[@]}"; do
        create_environment "$env"
        echo ""
    done
    
    echo -e "${GREEN}✅ GitHub environments setup completed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the created environments in your GitHub repository settings"
    echo "2. Add any missing secrets manually if needed"
    echo "3. Configure branch protection rules if desired"
    echo "4. Run the setup-infrastructure workflow to create AWS resources"
}

# Function to upload secrets
upload_secrets() {
    echo -e "${YELLOW}Uploading secrets to GitHub...${NC}"
    
    # Check if GitHub CLI supports variables (newer versions)
    local supports_variables=false
    if gh variable --help &> /dev/null; then
        supports_variables=true
    fi
    
    if [ "$supports_variables" = false ]; then
        echo -e "${YELLOW}Your GitHub CLI version doesn't support variables.${NC}"
        echo -e "${YELLOW}All variables will be stored as secrets instead.${NC}"
        echo ""
    fi
    
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        echo -e "${RED}.env file not found!${NC}"
        echo "Please create a .env file based on .env.example"
        return 1
    fi
    
    # Extract values from config.json
    local repository=$(get_json_value config.json ".github.repository")
    local environments=("dev" "hml" "prd")
    
    echo -e "${GREEN}Setting up GitHub variables and secrets from .env file${NC}"
    echo "Repository: $repository"
    echo "Environments: ${environments[*]}"
    echo ""
    if [ "$supports_variables" = true ]; then
        echo -e "${YELLOW}Variables containing 'SECRET', 'KEY', or 'PASSWORD' → GitHub Secrets${NC}"
        echo -e "${YELLOW}Other variables → GitHub Environment Variables${NC}"
    else
        echo -e "${YELLOW}All variables will be stored as GitHub Secrets${NC}"
    fi
    echo -e "${YELLOW}Deployment secrets (AWS credentials, EC2 keys) are handled separately.${NC}"
    echo ""
    
    # Function to add secrets to environment
    add_secrets_to_environment() {
        local env_name=$1
        echo -e "${YELLOW}Adding variables to environment: $env_name${NC}"
        
        local secrets_added=0
        local vars_added=0
        
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^#.*$ ]] && continue
            
            # Remove quotes from value if present
            value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
            
            # Handle multi-line values (like private keys)
            if [[ "$value" == *"\\n"* ]]; then
                value=$(echo -e "$value")
            fi
            
            # Check if variable name contains SECRET, KEY, or PASSWORD (case insensitive) OR if variables are not supported
            if [[ "$key" =~ [Ss][Ee][Cc][Rr][Ee][Tt] ]] || [[ "$key" =~ [Kk][Ee][Yy] ]] || [[ "$key" =~ [Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd] ]] || [ "$supports_variables" = false ]; then
                echo "Adding secret: $key"
                echo "$value" | gh secret set "$key" --env "$env_name"
                secrets_added=$((secrets_added + 1))
            else
                echo "Adding environment variable: $key"
                echo "$value" | gh variable set "$key" --env "$env_name"
                vars_added=$((vars_added + 1))
            fi
        done < .env
        
        if [ "$supports_variables" = true ]; then
            echo "✅ Added $secrets_added secrets and $vars_added environment variables to $env_name"
        else
            echo "✅ Added $secrets_added secrets to $env_name"
        fi
    }
    
    # Function to add repository-level variables
    add_repository_secrets() {
        echo -e "${YELLOW}Adding repository-level variables${NC}"
        
        local secrets_added=0
        local vars_added=0
        
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^#.*$ ]] && continue
            
            # Remove quotes from value if present
            value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
            
            # Handle multi-line values (like private keys)
            if [[ "$value" == *"\\n"* ]]; then
                value=$(echo -e "$value")
            fi
            
            # Check if variable name contains SECRET, KEY, or PASSWORD (case insensitive) OR if variables are not supported
            if [[ "$key" =~ [Ss][Ee][Cc][Rr][Ee][Tt] ]] || [[ "$key" =~ [Kk][Ee][Yy] ]] || [[ "$key" =~ [Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd] ]] || [ "$supports_variables" = false ]; then
                echo "Adding repository secret: $key"
                echo "$value" | gh secret set "$key"
                secrets_added=$((secrets_added + 1))
            else
                echo "Adding repository variable: $key"
                echo "$value" | gh variable set "$key"
                vars_added=$((vars_added + 1))
            fi
        done < .env
        
        if [ "$supports_variables" = true ]; then
            echo "✅ Added $secrets_added secrets and $vars_added variables to repository"
        else
            echo "✅ Added $secrets_added secrets to repository"
        fi
    }
    
    # Ask user what they want to do
    echo ""
    echo "Choose an option:"
    echo "1. Add variables/secrets to all environments"
    echo "2. Add variables/secrets to specific environment"
    echo "3. Add variables/secrets as repository-level"
    echo "4. Add variables/secrets to both environments and repository level"
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            for env in "${environments[@]}"; do
                add_secrets_to_environment "$env"
                echo ""
            done
            ;;
        2)
            echo "Available environments: ${environments[*]}"
            read -p "Enter environment name: " selected_env
            if [[ " ${environments[*]} " =~ " ${selected_env} " ]]; then
                add_secrets_to_environment "$selected_env"
            else
                echo -e "${RED}Invalid environment name!${NC}"
                return 1
            fi
            ;;
        3)
            add_repository_secrets
            ;;
        4)
            add_repository_secrets
            echo ""
            for env in "${environments[@]}"; do
                add_secrets_to_environment "$env"
                echo ""
            done
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Secrets setup completed!${NC}"
}

# Function to setup deployment secrets
setup_deployment_secrets() {
    echo -e "${YELLOW}Setting up deployment secrets...${NC}"
    echo ""
    local project_name=$(get_json_value config.json ".project.name")
    local key_name="$project_name-key"
    
    echo "The following secrets need to be added to GitHub:"
    echo "1. AWS_ACCESS_KEY_ID (your AWS access key)"
    echo "2. AWS_SECRET_ACCESS_KEY (your AWS secret key)"
    echo "3. EC2_KEY_NAME (will be created: $key_name)"
    echo "4. EC2_PRIVATE_KEY (will be created by infrastructure setup)"
    echo ""
    
    read -p "Do you want to add AWS secrets now? (y/n): " add_secrets
    if [[ $add_secrets =~ ^[Yy]$ ]]; then
        # Get AWS credentials from config.json
        echo ""
        echo "Getting AWS credentials from config.json..."
        local aws_access_key=$(get_json_value config.json ".aws.credentials.access_key_id")
        local aws_secret_key=$(get_json_value config.json ".aws.credentials.secret_access_key")
        
        # Check if credentials are placeholder values
        if [ -n "$aws_access_key" ] && [ "$aws_access_key" != "unknown" ] && [ "$aws_access_key" != "your_aws_access_key_id" ] && \
           [ -n "$aws_secret_key" ] && [ "$aws_secret_key" != "unknown" ] && [ "$aws_secret_key" != "your_aws_secret_access_key" ]; then
            gh secret set AWS_ACCESS_KEY_ID --body "$aws_access_key" && echo "✅ AWS_ACCESS_KEY_ID added"
            gh secret set AWS_SECRET_ACCESS_KEY --body "$aws_secret_key" && echo "✅ AWS_SECRET_ACCESS_KEY added"
            echo -e "${GREEN}✅ AWS secrets added successfully!${NC}"
        else
            echo -e "${YELLOW}⚠️ AWS credentials not found or are placeholder values in config.json${NC}"
            echo "Please update config.json with your actual AWS credentials and run the script again, or add them manually:"
            echo "gh secret set AWS_ACCESS_KEY_ID --body 'your_aws_access_key'"
            echo "gh secret set AWS_SECRET_ACCESS_KEY --body 'your_aws_secret_key'"
        fi
    else
        echo -e "${YELLOW}⚠️ AWS secrets not added. Please add them manually before deploying.${NC}"
    fi
}

# Function to show next steps
show_next_steps() {
    echo -e "${GREEN}"
    cat << "EOF"

╔════════════════════════════════════════════════════════════╗
║                Repository Setup Complete! 🎉              ║
╚════════════════════════════════════════════════════════════╝

EOF
    echo -e "${NC}"
    
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. 🚀 Run infrastructure setup:"
    echo "   - Go to Actions tab in your GitHub repository"
    echo "   - Run 'Setup Initial Infrastructure' workflow"
    echo "   - This will create Terraform backend and EC2 key pairs"
    echo ""
    echo "2. 📋 After infrastructure setup:"
    echo "   - Environments: dev, hml, prd are configured"
    echo "   - Project secrets uploaded to GitHub"
    echo "   - Ready for application deployment"
    echo ""
    echo "3. 🔧 Configure your application:"
    echo "   - Update frontend/ and backend/ directories with your code"
    echo "   - Ensure docker-compose.yml is properly configured"
    echo ""
    echo -e "${GREEN}Repository setup complete! 🚀${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting Repository & Environment Setup...${NC}"
    echo ""
    
    # Step 1: Validate config
    validate_config
    echo ""
    
    # Step 2: Check prerequisites
    check_prerequisites
    echo ""
    
    # Step 3: Validate hosted zones
    validate_hosted_zones
    echo ""
    
    # Step 4: Setup .env file
    setup_env_file
    echo ""
    
    # Step 5: Setup GitHub environments
    setup_github_environments
    echo ""
    
    # Step 6: Setup deployment secrets
    setup_deployment_secrets
    echo ""
    
    # Step 7: Upload project variables/secrets to environments
    echo -e "${YELLOW}Would you like to upload project variables/secrets from .env to GitHub environments now? (y/n)${NC}"
    echo -e "${BLUE}Note: This will upload all variables from .env to the dev, hml, and prd environments${NC}"
    read -p "> " upload_now
    if [[ $upload_now =~ ^[Yy]$ ]]; then
        upload_secrets
        echo ""
    else
        echo -e "${YELLOW}⚠️ Skipped secrets upload. You can run this manually later or add secrets via GitHub UI.${NC}"
        echo ""
    fi
    
    # Step 8: Show next steps
    show_next_steps
}

# Run main function
main "$@"