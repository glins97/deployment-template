#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}GitHub CLI (gh) is not installed. Please install it first.${NC}"
    echo "Visit: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}You are not authenticated with GitHub CLI.${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

# Read config.json
if [ ! -f "config.json" ]; then
    echo -e "${RED}config.json not found!${NC}"
    echo "Please run the main setup.sh script first to create config.json from template."
    exit 1
fi

# Extract values using basic shell parsing
PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' config.json | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
REPOSITORY=$(grep -o '"repository"[[:space:]]*:[[:space:]]*"[^"]*"' config.json | sed 's/.*"repository"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
ENVIRONMENTS=("dev" "hml" "prd")  # Default environments

echo -e "${GREEN}Setting up GitHub environments for $PROJECT_NAME${NC}"
echo "Repository: $REPOSITORY"
echo "Environments: ${ENVIRONMENTS[*]}"

# Function to create environment
create_environment() {
    local env_name=$1
    echo -e "${YELLOW}Creating environment: $env_name${NC}"
    
    # Create environment
    gh api repos/$REPOSITORY/environments/$env_name -X PUT --silent || {
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
        gh api repos/$REPOSITORY/environments/$env_name -X PUT \
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
            echo "$value" | gh secret set "$key" --env "$env_name" --body @-
        done < .env
    else
        echo -e "${YELLOW}.env file not found. Skipping secret creation.${NC}"
        echo "You'll need to manually add the following secrets to each environment:"
        echo "- AWS_ACCESS_KEY_ID"
        echo "- AWS_SECRET_ACCESS_KEY" 
        echo "- EC2_KEY_NAME"
        echo "- EC2_PRIVATE_KEY"
        echo "- DATABASE_URL"
        echo "- REDIS_URL"
        echo "- JWT_SECRET"
    fi
}

# Main execution
echo -e "${GREEN}Starting GitHub environment setup...${NC}"

for env in "${ENVIRONMENTS[@]}"; do
    create_environment "$env"
    add_environment_secrets "$env"
    echo ""
done

echo -e "${GREEN}✅ GitHub environments setup completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Review the created environments in your GitHub repository settings"
echo "2. Add any missing secrets manually if needed"
echo "3. Configure branch protection rules if desired"
echo "4. Run the setup-infrastructure workflow to create AWS resources"