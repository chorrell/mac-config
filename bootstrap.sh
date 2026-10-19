#!/bin/bash
# Bootstrap script for macOS Ansible configuration
#
# Sets up Homebrew and uv, installs Ansible into a uv-managed virtual
# environment, then runs the playbook. Any arguments are passed on to
# ansible-playbook, for example:
#
#   ./bootstrap.sh --tags vscode
#   ./bootstrap.sh --check --diff

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

trap 'echo -e "${RED}Bootstrap failed. Check the output above for errors.${NC}"' ERR

# Run from the repository, wherever the script is called from
cd "$(dirname "$0")"

echo "========================================"
echo "macOS Ansible Configuration Bootstrap"
echo "========================================"

if [[ $OSTYPE != darwin* ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

# The playbook expects Homebrew in /opt/homebrew, its Apple Silicon location
if [[ "$(uname -m)" != arm64 ]]; then
    echo -e "${RED}Error: This script needs a Mac with Apple Silicon${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking for Homebrew${NC}"
if [[ ! -x /opt/homebrew/bin/brew ]]; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo -e "${GREEN}Homebrew already installed${NC}"
fi
# The Homebrew installer does not add itself to PATH
eval "$(/opt/homebrew/bin/brew shellenv)"

echo -e "${YELLOW}Step 2: Checking for uv${NC}"
if ! command -v uv &>/dev/null; then
    echo -e "${YELLOW}Installing uv via Homebrew...${NC}"
    brew install uv
else
    echo -e "${GREEN}uv already installed${NC}"
fi

echo -e "${YELLOW}Step 3: Installing Python and Ansible with uv${NC}"
# Creates .venv using the uv-managed Python pinned in .python-version
uv sync --locked --no-dev

echo -e "${YELLOW}Step 4: Installing Ansible Galaxy collections${NC}"
uv run --no-dev ansible-galaxy collection install -r collections/requirements.yml

echo -e "${YELLOW}Step 5: Validating playbook syntax${NC}"
uv run --no-dev ansible-playbook -i hosts local.yml --syntax-check
echo -e "${GREEN}Syntax check passed${NC}"

# Homebrew changes a file inside Docker.app while installing it, which macOS
# blocks unless the terminal has the App Management permission
if [[ ! -d /Applications/Docker.app && -t 0 ]]; then
    terminal_app="${TERM_PROGRAM:-your terminal}"
    [[ $terminal_app == Apple_Terminal ]] && terminal_app=Terminal
    echo -e "${YELLOW}Before the playbook installs Docker Desktop:${NC}"
    echo "  Turn on $terminal_app in System Settings > Privacy & Security > App Management."
    echo "  If you had to change it, quit $terminal_app, reopen it and run this script again."
    read -r -p "Press Enter to continue, or Ctrl+C to stop... "
fi

echo -e "${YELLOW}Step 6: Running Ansible playbook${NC}"
# ${1+"$@"} because macOS's bash 3.2 treats an empty "$@" as unbound under set -u
uv run --no-dev ansible-playbook -i hosts local.yml ${1+"$@"}

echo -e "${GREEN}========================================"
echo "✓ Bootstrap completed successfully!"
echo -e "========================================${NC}"

# Next steps only apply after a full run
if [[ $# -eq 0 ]]; then
    echo ""
    echo "Next steps:"
    echo "1. Open a new terminal window so the new ~/.zshrc is loaded"
    echo "2. Set your git name and email (git config --global user.name/user.email)"
    echo "   and, to sign commits, import your GPG key (see README)"
    echo "3. Put machine-specific shell settings and secrets in ~/.zshrc.local"
    echo "4. Run 'atuin login' to sync shell history between machines"
    echo "5. Open Docker Desktop once to accept the licence and install its helper"
    echo "6. Re-run ./bootstrap.sh (or 'uv run ansible-playbook -i hosts local.yml')"
    echo "   after changing this repo"
    echo ""
fi
