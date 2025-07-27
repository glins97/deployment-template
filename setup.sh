#!/usr/bin/env bash
set -e

# Check if running with bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash. Please run with: bash setup.sh"
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
║    _____ _               ____  __            _____           ║
║   / ____| |             |  _ \/ _|          |  ___|          ║
║  | (___ | |_ __ _ _ __   | |_) | |_ _ __ ____ | |___           ║
║   \___ \| | '_ ` | '_ \  |  _ <|  _| '_ \_  _||  ___|         ║
║   ____) | | | | | | | | | |_) | | | | | / / | |___           ║
║  |_____/|_|_| |_|_| |_| |____/|_| |_| |_\__\ |_____|         ║
║                                                              ║
║              Full Stack Deployment Template                  ║
║                        Setup Orchestrator                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

show_usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./setup.sh [command]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  repository       Set up repository, environments, and secrets"
    echo "  infrastructure   Run infrastructure setup (creates AWS resources)"
    echo "  help             Show this help message"
    echo ""
    echo -e "${YELLOW}Recommended workflow:${NC}"
    echo "1. ${GREEN}./setup.sh repository${NC}     # Set up repository and environments"
    echo "2. ${GREEN}./setup.sh infrastructure${NC} # Set up AWS infrastructure"
    echo "3. ${GREEN}GitHub Actions${NC}            # Run 'Deploy Infrastructure and Application' workflow"
}

# Main execution
main() {
    local command="${1:-}"
    
    case "$command" in
        "repository"|"repo")
            echo -e "${BLUE}Starting Repository Setup...${NC}"
            echo ""
            if [ -f "scripts/setup-repository.sh" ]; then
                ./scripts/setup-repository.sh
            else
                echo -e "${RED}❌ setup-repository.sh script not found${NC}"
                echo "Please ensure scripts/setup-repository.sh exists."
                exit 1
            fi
            ;;
        "infrastructure"|"infra")
            echo -e "${BLUE}Starting Infrastructure Setup...${NC}"
            echo ""
            if [ -f "scripts/setup-infrastructure.sh" ]; then
                ./scripts/setup-infrastructure.sh
            else
                echo -e "${RED}❌ setup-infrastructure.sh script not found${NC}"
                exit 1
            fi
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        "")
            echo -e "${YELLOW}No command specified. Running repository setup by default.${NC}"
            echo ""
            if [ -f "scripts/setup-repository.sh" ]; then
                ./scripts/setup-repository.sh
            else
                echo -e "${RED}❌ setup-repository.sh script not found${NC}"
                echo "Please ensure scripts/setup-repository.sh exists."
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"