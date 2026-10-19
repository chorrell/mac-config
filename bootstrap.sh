#!/usr/bin/env bash

set -euo pipefail

# ============================================================================
# macOS Ansible Configuration Bootstrap
# ============================================================================
# Sets up Homebrew and uv, installs Ansible into a uv-managed virtual
# environment, then runs the playbook.
#
# Usage: bootstrap.sh [ANSIBLE-PLAYBOOK OPTIONS]
#   Any options are passed on to ansible-playbook, for example
#   --tags vscode or --check --diff
#   --help    Show this help message
# ============================================================================

# Constants (BREW_PREFIX and DOCKER_APP can be set by the tests in tests/)
readonly BREW_PREFIX="${BREW_PREFIX:-/opt/homebrew}"
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
readonly DOCKER_APP="${DOCKER_APP:-/Applications/Docker.app}"

# Color output (disabled in non-interactive shells)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly COLOR_RED='\033[0;31m'
  readonly COLOR_YEL='\033[0;33m'
  readonly COLOR_GRN='\033[0;32m'
  readonly COLOR_BLU='\033[1;34m'
  readonly COLOR_RESET='\033[0m'
else
  readonly COLOR_RED=''
  readonly COLOR_YEL=''
  readonly COLOR_GRN=''
  readonly COLOR_BLU=''
  readonly COLOR_RESET=''
fi

# Helper functions
error() {
  echo -e "${COLOR_RED}Error:${COLOR_RESET} $1" >&2
  exit 1
}

warn() {
  echo -e "${COLOR_YEL}Warning:${COLOR_RESET} $1" >&2
}

success() {
  echo -e "${COLOR_GRN}✓${COLOR_RESET} $1"
}

header() {
  echo ""
  echo -e "${COLOR_BLU}$1${COLOR_RESET}"
}

footer() {
  echo ""
}

usage() {
  cat << EOF
macOS Ansible Configuration Bootstrap

Usage: $0 [ANSIBLE-PLAYBOOK OPTIONS]

Installs Homebrew, uv, Python and Ansible if needed, then runs the playbook.
Any options are passed on to ansible-playbook.

Examples:
  $0                      # Set up everything
  $0 --tags vscode        # Apply one role
  $0 --check --diff       # Show what would change, without changing anything

Environment Variables:
  NO_COLOR                Disable colored output

EOF
}

next_steps() {
  cat << EOF
Next steps:
  1. Open a new terminal window so the new ~/.zshrc is loaded
  2. Set your git name and email (git config --global user.name/user.email)
     and, to sign commits, import your GPG key (see README)
  3. Put machine-specific shell settings and secrets in ~/.zshrc.local
  4. Run 'atuin login' to sync shell history between machines
  5. Open Docker Desktop once to accept the licence and install its helper
  6. Re-run $0 (or 'uv run ansible-playbook -i hosts local.yml')
     after changing this repo

EOF
}

# Name of the terminal app running this script, as shown in System Settings
terminal_name() {
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal) echo "Terminal" ;;
    "") echo "your terminal" ;;
    *) echo "$TERM_PROGRAM" ;;
  esac
}

# Homebrew changes a file inside Docker.app while installing it, which macOS
# blocks unless the terminal has the App Management permission
app_management_reminder() {
  local terminal
  terminal=$(terminal_name)
  warn "The playbook will install Docker Desktop"
  cat << EOF
Turn on ${terminal} in System Settings > Privacy & Security > App Management.
If you had to change it, quit ${terminal}, reopen it and run this script again.

EOF
  read -r -p "Press Enter to continue, or Ctrl+C to stop... "
}

on_failure() {
  echo -e "${COLOR_RED}Bootstrap failed.${COLOR_RESET} Check the output above for errors." >&2
}
trap on_failure ERR

# ============================================================================
# Parse CLI Arguments
# ============================================================================

# Everything else is for ansible-playbook
case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

# ============================================================================
# Validate Environment
# ============================================================================

[[ "$(uname -s)" == Darwin ]] || error "This script must be run on macOS"

# The playbook expects Homebrew in /opt/homebrew, its Apple Silicon location
[[ "$(uname -m)" == arm64 ]] || error "This script needs a Mac with Apple Silicon"

# Run from the repository, wherever the script is called from
cd "$(dirname "$0")" || error "Failed to change to the repository directory"

header "macOS Ansible Configuration Bootstrap"
footer

# ============================================================================
# Install Homebrew and uv
# ============================================================================

header "Step 1: Checking for Homebrew"
if [[ -x "${BREW_PREFIX}/bin/brew" ]]; then
  success "Homebrew already installed"
else
  /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
  success "Homebrew installed"
fi
# The Homebrew installer does not add itself to PATH
eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
footer

header "Step 2: Checking for uv"
if command -v uv > /dev/null 2>&1; then
  success "uv already installed"
else
  brew install uv
  success "uv installed"
fi
footer

# ============================================================================
# Install Python, Ansible and Collections
# ============================================================================

header "Step 3: Installing Python and Ansible with uv"
# Creates .venv using the uv-managed Python pinned in .python-version
uv sync --locked --no-dev
success "Python and Ansible installed in .venv"
footer

header "Step 4: Installing Ansible Galaxy collections"
uv run --no-dev ansible-galaxy collection install -r collections/requirements.yml
success "Collections installed"
footer

header "Step 5: Validating playbook syntax"
uv run --no-dev ansible-playbook -i hosts local.yml --syntax-check
success "Syntax check passed"
footer

# ============================================================================
# Run the Playbook
# ============================================================================

if [[ ! -d "$DOCKER_APP" ]] && [[ -t 0 ]]; then
  app_management_reminder
fi

header "Step 6: Running Ansible playbook"
uv run --no-dev ansible-playbook -i hosts local.yml "$@"
footer

success "Bootstrap completed successfully"

# Next steps only apply after a full run
if [[ $# -eq 0 ]]; then
  footer
  next_steps
fi
