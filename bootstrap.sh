#!/bin/bash
set -e

# Bootstrap script for macOS Ansible configuration
# This script sets up Homebrew and uv, installs Ansible into a uv-managed
# virtual environment, then runs the playbook

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

echo -e "${YELLOW}Step 2: Checking for uv${NC}"
if ! command -v uv &> /dev/null; then
    echo -e "${YELLOW}Installing uv via Homebrew...${NC}"
    brew install uv
else
    echo -e "${GREEN}uv already installed${NC}"
fi

echo -e "${YELLOW}Step 3: Installing Python and Ansible with uv${NC}"
# Creates .venv using the uv-managed Python pinned in .python-version
uv sync --locked --no-dev

echo -e "${YELLOW}Step 4: Installing Ansible Galaxy collections${NC}"
if [ -f "collections/requirements.yml" ]; then
    uv run --no-dev ansible-galaxy collection install -r collections/requirements.yml
else
    echo -e "${YELLOW}collections/requirements.yml not found${NC}"
fi

echo -e "${YELLOW}Step 5: Validating playbook syntax${NC}"
uv run --no-dev ansible-playbook --syntax-check local.yml
echo -e "${GREEN}Syntax check passed${NC}"

echo -e "${YELLOW}Step 6: Running Ansible playbook${NC}"
uv run --no-dev ansible-playbook local.yml -i hosts

if [ $? -eq 0 ]; then
    echo -e "${GREEN}========================================"
    echo "✓ Bootstrap completed successfully!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "1. Set your git name and email (git config --global user.name/user.email)"
    echo "   and, to sign commits, import your GPG key (see README)"
    echo "2. Put machine-specific shell settings and secrets in ~/.zshrc.local"
    echo "3. Run 'atuin login' to sync shell history between machines"
    echo "4. Re-run 'uv run ansible-playbook local.yml' after changing this repo"
    echo ""
else
    echo -e "${RED}Bootstrap failed. Check the output above for errors.${NC}"
    exit 1
fi
