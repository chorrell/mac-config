# Mac Configuration with Ansible

Automated macOS laptop configuration using Ansible and ansible-pull. Set up a complete development environment with a single command, including:

- Homebrew package management
- Shell configuration (zsh with zimfw)
- Git configuration
- VS Code setup with extensions
- Automatic updates via launchd

## Prerequisites

- macOS (10.15+)
- Internet connection
- Administrator access (for some tasks)

## Quick Start

### Option 1: Bootstrap Script (Recommended)

```bash
git clone https://github.com/YOUR_USERNAME/mac-config.git
cd mac-config
./bootstrap.sh
```

The bootstrap script will:

1. Install Homebrew (if not present)
2. Install Ansible
3. Install Ansible Galaxy collections
4. Validate the playbook syntax
5. Run the Ansible playbook

### Option 2: Manual Setup

If you prefer to do this step by step:

```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Ansible
brew install ansible

# Install Ansible Galaxy collections
ansible-galaxy collection install -r collections/requirements.yml

# Run the playbook
ansible-playbook -i hosts local.yml
```

## Configuration

Before running the playbook, customize the configuration:

### 1. Edit group_vars/local.yml

Configure the base role settings:

```yaml
configure_system_settings: true
create_config_directories: true
```

### 2. Customize Base Role (Optional)

Review and customize in `roles/base/defaults/main.yml` to:

- Enable/disable system default configurations
- Adjust which directories to create

## Running the Playbook

### Run the base role

```bash
ansible-playbook -i hosts local.yml
```

### Run with tags

```bash
# Only system configuration
ansible-playbook -i hosts local.yml --tags system
```

### Dry run (check mode)

```bash
ansible-playbook -i hosts local.yml --check
```

## Branch Structure

This repository uses feature branches to isolate and review each role:

- **main** - Stable, production-ready configuration
- **feature/base-role** - Base system configuration (current)
- **feature/homebrew-role** - Package management (coming soon)
- **feature/dotfiles-role** - Shell and git configuration (coming soon)
- **feature/vscode-role** - VS Code setup (coming soon)
- **feature/launchd-role** - Automatic updates scheduling (coming soon)

Each feature branch contains a single role and corresponding Molecule tests. Once approved and tested, feature branches are merged to main.

## Directory Structure

```text
mac-config/
├── bootstrap.sh                # Quick setup script (production)
├── local.yml                   # Main playbook (base-role)
├── hosts                       # Inventory file
├── ansible.cfg                 # Ansible configuration
├── requirements.txt            # Python dependencies (testing)
├── .ansible-lint               # Ansible linting config
├── .yamllint                   # YAML linting config
├── collections/
│   └── requirements.yml        # Galaxy collection requirements
├── roles/
│   └── base/                   # System defaults and directories
│       └── molecule/           # Molecule test structure
│           └── default/
│               ├── molecule.yml
│               ├── converge.yml
│               └── verify.yml
├── group_vars/
│   └── local.yml               # Local machine variables
└── .github/workflows/
    └── molecule.yml            # GitHub Actions CI/CD workflow
```

## Base Role

The base role (current) configures essential macOS system settings:

### What It Does

- **Directory Creation**: Creates `~/.config` and `~/.local/bin` directories
- **System Defaults**: Configures Finder to show hidden files and sets keyboard repeat rate
- **Idempotency**: All tasks check current state before applying changes

### Verification

Molecule tests verify:

- Required directories are created with correct permissions
- Finder hidden files setting is applied
- Keyboard repeat rate is configured
- All tasks are idempotent (safe to run multiple times)

### Upcoming Roles

Future feature branches will add:

- **homebrew** - Package and cask installation via Homebrew
- **dotfiles** - Shell configuration with zimfw and git setup
- **vscode** - VS Code extensions and configuration
- **launchd** - Automatic ansible-pull scheduling on login

## Troubleshooting

### Ansible not found

```bash
brew install ansible
```

### Permission denied for zsh

```bash
sudo chsh -s /usr/local/bin/zsh $(whoami)
```

### VS Code extensions won't install

Ensure VS Code is installed and in PATH:

```bash
which code
```

### launchd service not loading

Check for errors:

```bash
launchctl load ~/Library/LaunchAgents/com.user.ansible-pull.plist
```

### Homebrew issues

Update Homebrew:

```bash
brew update
brew doctor
```

## Testing

### Testing Prerequisites

- Python 3.11+

**Note:** Molecule tests run directly on your macOS system (no VM needed), so all required dependencies are automatically available.

### Set Up Testing Environment

For local testing, create a Python virtual environment to isolate testing dependencies:

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install testing dependencies
pip install -r requirements.txt

# Install Galaxy collections
ansible-galaxy collection install -r collections/requirements.yml
```

**Note:** Ansible will be installed in the virtual environment alongside Molecule and linting tools. For production/bootstrap, Ansible is installed via Homebrew instead (see `bootstrap.sh`).

### Run Molecule Tests for a Role

First, ensure your testing environment is set up:

```bash
# Create and activate virtual environment (if not already done)
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
ansible-galaxy collection install -r collections/requirements.yml
```

Then run the tests:

```bash
# Full test cycle for complete playbook (syntax → converge → idempotence → verify)
molecule test

# Or run individual steps:
molecule syntax    # Check playbook syntax
molecule converge  # Apply the playbook to localhost
molecule idempotence # Verify idempotency (converge twice)
molecule verify    # Run verification tests

# Useful for debugging:
molecule converge  # Run playbook once
molecule converge --extra-vars "debug=true"  # Add debugging
```

**Expected Output:**

```bash
INFO     default ➜ discovery: scenario test matrix: dependency, cleanup, destroy, syntax, create, prepare, converge, idempotence, side_effect, verify, cleanup, destroy
INFO     default ➜ syntax: Executed: Successful
INFO     default ➜ converge: Executed: Successful
INFO     default ➜ idempotence: Executed: Successful
INFO     default ➜ verify: Executed: Successful
```

### Troubleshooting Molecule Tests

**Molecule not found:**

```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Verify molecule is installed
pip list | grep molecule
```

**Ansible or collection errors:**

```bash
# Reinstall dependencies
pip install --upgrade -r requirements.txt

# Reinstall collections
ansible-galaxy collection install -r collections/requirements.yml
```

**Cache issues:**

```bash
# Clear Molecule scenario cache
molecule destroy
rm -rf .molecule/
```

**Tests modify system configuration:**

Since tests run on your actual macOS system, some system defaults will be modified:

- Finder will show hidden files
- Keyboard repeat rate will be set

These can be reverted manually or by running the test again with `--check` mode.

### Run Linting Only

```bash
# Ensure venv is activated
source venv/bin/activate

# Run all linting
yamllint .
ansible-lint

# Or run individually:
yamllint roles/base/          # Check YAML syntax
ansible-lint roles/base/      # Check Ansible best practices
markdownlint-cli2 "**/*.md"   # Check Markdown (requires Docker)
```

### Pre-commit Hooks

Pre-commit hooks automatically validate code before commits. This repo includes:

- **markdownlint**: Validates markdown formatting
- **ansible-lint**: Validates Ansible YAML and best practices

To set up pre-commit hooks:

```bash
# Install pre-commit framework
pip install pre-commit

# Install git hooks in your repo
pre-commit install

# Run hooks on all files (optional)
pre-commit run --all-files

# Hooks will now run automatically on `git commit`
```

**Note:** The ansible-lint hook uses your system's ansible-lint installation (from Homebrew or venv), ensuring consistency with your testing environment.

### Deactivate Virtual Environment

```bash
deactivate
```

### Manual Configuration Testing

#### 1. Syntax validation

```bash
ansible-playbook -i hosts local.yml --syntax-check
```

#### 2. Check mode (dry run)

```bash
ansible-playbook -i hosts local.yml --check
```

#### 3. Idempotency test

Run twice and verify no changes on second run:

```bash
ansible-playbook -i hosts local.yml
ansible-playbook -i hosts local.yml  # Should show no changes
```

#### 4. Test the base role

```bash
ansible-playbook -i hosts local.yml --tags system --check
```

### CI/CD Testing

Molecule tests run automatically on:

- Pull requests to feature branches
- Pushes to main branch
- Changes to roles, workflows, or linting configs

See `.github/workflows/molecule.yml` for details.

## Best Practices Implemented

- **Idempotency**: All tasks are idempotent and safe to run multiple times
- **Modularity**: Organized into logical roles that can be run independently
- **Variables**: Centralized configuration in group_vars and role defaults
- **Templates**: Dynamic configuration via Jinja2 templates
- **Error Handling**: Proper error handling and informative messages
- **Logging**: Comprehensive logging for troubleshooting
- **Tags**: Selective execution of roles and tasks

## Contributing

To customize this for your needs:

1. Fork this repository
2. Update `group_vars/local.yml` with your preferences
3. Customize dotfiles in `roles/dotfiles/files/`
4. Add/remove packages in `roles/homebrew/files/Brewfile`
5. Test with `ansible-playbook -i hosts local.yml --check`
6. Commit your changes

## Support

For issues or questions:

- Check logs: `tail -f ~/Library/Logs/ansible-pull.log`
- Review Ansible output for error messages
- Verify prerequisites are installed
- Check connectivity to GitHub

## License

MIT License - See LICENSE file for details

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Homebrew Documentation](https://docs.brew.sh/)
- [macOS Defaults](https://macos-defaults.com/)
- [launchd Documentation](https://www.manpagez.com/man/5/launchd.plist/)
