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
- Vagrant
- VirtualBox

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
# Full test cycle for base role (create → converge → verify → destroy)
cd roles/base
molecule test

# Or run individual steps:
molecule create      # Create macOS test VM
molecule converge    # Apply the role to the VM
molecule verify      # Run verification tests
molecule destroy     # Clean up the VM

# Useful for debugging:
molecule converge --no-cleanup  # Keep VM running after convergence
molecule login       # SSH into running test VM
```

**Expected Output:**

```bash
 --> Test matrix

 --> ubuntu Instance is being created...
 --> Lint Passed
 --> Preparing Instance
 --> Converging Instance
 --> Idempotence check
 --> Verifying Instance
 --> Cleaning Up Instance
Verifying
 --> Running Ansible Verify playbook.

PLAY [Verify] *****
...
```

### Troubleshooting Molecule Tests

**VirtualBox/Vagrant Issues:**

```bash
# Check Vagrant status
vagrant global-status

# Destroy orphaned VMs if needed
vagrant destroy -f

# Verify VirtualBox is running
vboxmanage list vms
```

**Python/Dependency Issues:**

```bash
# Reinstall dependencies
pip install --upgrade -r requirements.txt

# Clear Molecule cache
rm -rf .molecule/
```

**Slow Tests:**

Molecule tests can take several minutes on first run as it:

1. Creates a macOS virtual machine
2. Installs Ansible
3. Applies the role
4. Runs verification tasks
5. Cleans up the VM

Subsequent runs will be faster due to caching.

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

To automatically run markdownlint before commits:

```bash
# Install pre-commit framework
pip install pre-commit

# Install git hooks in your repo
pre-commit install

# Run hooks on all files
pre-commit run --all-files

# Hooks will now run automatically on `git commit`
```

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
