#!/bin/bash
set -e

# Bootstrap script for macOS Ansible configuration
# This script sets up Homebrew and Ansible, then runs the playbook

echo "========================================"
echo "macOS Ansible Configuration Bootstrap"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking for Homebrew${NC}"
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo -e "${GREEN}Homebrew already installed${NC}"
fi

echo -e "${YELLOW}Step 2: Checking for Ansible${NC}"
if ! command -v ansible &> /dev/null; then
    echo -e "${YELLOW}Installing Ansible via Homebrew...${NC}"
    brew install ansible
else
    echo -e "${GREEN}Ansible already installed${NC}"
fi

echo -e "${YELLOW}Step 3: Installing Ansible Galaxy collections${NC}"
if [ -f "collections/requirements.yml" ]; then
    ansible-galaxy collection install -r collections/requirements.yml
else
    echo -e "${YELLOW}collections/requirements.yml not found${NC}"
fi

echo -e "${YELLOW}Step 4: Validating playbook syntax${NC}"
if command -v ansible-playbook &> /dev/null; then
    ansible-playbook --syntax-check local.yml
    echo -e "${GREEN}Syntax check passed${NC}"
fi

echo -e "${YELLOW}Step 5: Running Ansible playbook${NC}"
ansible-playbook local.yml -i hosts

if [ $? -eq 0 ]; then
    echo -e "${GREEN}========================================"
    echo "✓ Bootstrap completed successfully!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "1. Customize group_vars/local.yml with your settings"
    echo "2. Update roles/dotfiles/files/* with your configurations"
    echo "3. Run 'ansible-playbook local.yml' to apply changes"
    echo ""
else
    echo -e "${RED}Bootstrap failed. Check the output above for errors.${NC}"
    exit 1
fi
