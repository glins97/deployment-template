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

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}.env file not found!${NC}"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

# Read config.json
if [ ! -f "config.json" ]; then
    echo -e "${RED}config.json not found!${NC}"
    exit 1
fi

# Extract values using basic shell parsing
REPOSITORY=$(grep -o '"repository"[[:space:]]*:[[:space:]]*"[^"]*"' config.json | sed 's/.*"repository"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
ENVIRONMENTS=("dev" "hml" "prd")  # Default environments

echo -e "${GREEN}Setting up GitHub secrets from .env file${NC}"
echo "Repository: $REPOSITORY"
echo "Environments: ${ENVIRONMENTS[*]}"

# Function to add secrets to environment
add_secrets_to_environment() {
    local env_name=$1
    echo -e "${YELLOW}Adding secrets to environment: $env_name${NC}"
    
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^#.*$ ]] && continue
        
        # Remove quotes from value if present
        value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
        
        # Handle multi-line values (like private keys)
        if [[ "$value" == *"\\n"* ]]; then
            value=$(echo -e "$value")
        fi
        
        echo "Adding secret: $key"
        echo "$value" | gh secret set "$key" --env "$env_name" --body @-
    done < .env
}

# Function to add repository-level secrets
add_repository_secrets() {
    echo -e "${YELLOW}Adding repository-level secrets${NC}"
    
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^#.*$ ]] && continue
        
        # Remove quotes from value if present
        value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
        
        # Handle multi-line values (like private keys)
        if [[ "$value" == *"\\n"* ]]; then
            value=$(echo -e "$value")
        fi
        
        echo "Adding repository secret: $key"
        echo "$value" | gh secret set "$key" --body @-
    done < .env
}

# Ask user what they want to do
echo ""
echo "Choose an option:"
echo "1. Add secrets to all environments"
echo "2. Add secrets to specific environment"
echo "3. Add secrets as repository-level secrets"
echo "4. Add secrets to both environments and repository level"
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        for env in "${ENVIRONMENTS[@]}"; do
            add_secrets_to_environment "$env"
            echo ""
        done
        ;;
    2)
        echo "Available environments: ${ENVIRONMENTS[*]}"
        read -p "Enter environment name: " selected_env
        if [[ " ${ENVIRONMENTS[*]} " =~ " ${selected_env} " ]]; then
            add_secrets_to_environment "$selected_env"
        else
            echo -e "${RED}Invalid environment name!${NC}"
            exit 1
        fi
        ;;
    3)
        add_repository_secrets
        ;;
    4)
        add_repository_secrets
        echo ""
        for env in "${ENVIRONMENTS[@]}"; do
            add_secrets_to_environment "$env"
            echo ""
        done
        ;;
    *)
        echo -e "${RED}Invalid choice!${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ Secrets setup completed!${NC}"