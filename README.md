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

Before running the playbook, customize the configuration files:

### 1. Edit group_vars/local.yml

Set your personal information:

```yaml
git_user_name: "Your Name"
git_user_email: "your.email@example.com"
ansible_pull_repo: "https://github.com/YOUR_USERNAME/mac-config.git"
```

### 2. Edit roles/dotfiles/files/

Customize your dotfiles:

- `zshrc` - Zsh shell configuration
- `aliases.zsh` - Shell aliases
- `gitconfig` - Git configuration

### 3. Edit roles/homebrew/files/Brewfile

Add or remove packages and casks as needed.

### 4. Edit roles/vscode/defaults/main.yml

Customize VS Code extensions and settings.

## Running the Playbook

### Run all roles

```bash
ansible-playbook -i hosts local.yml
```

### Run specific roles using tags

```bash
# Only Homebrew
ansible-playbook -i hosts local.yml --tags brew

# Only dotfiles
ansible-playbook -i hosts local.yml --tags dotfiles

# Only VS Code
ansible-playbook -i hosts local.yml --tags vscode

# Only system settings
ansible-playbook -i hosts local.yml --tags system

# Only launchd setup
ansible-playbook -i hosts local.yml --tags launchd
```

### Dry run (check mode)

```bash
ansible-playbook -i hosts local.yml --check
```

## Automatic Updates

The launchd role automatically sets up a service to run ansible-pull on login. This will:

1. Check for changes in your git repository
2. Update only if there are changes (`--only-if-changed` flag)
3. Log output to `~/Library/Logs/ansible-pull.log`

### Manually run ansible-pull

```bash
ansible-pull --url https://github.com/YOUR_USERNAME/mac-config.git \
  --directory ~/.ansible/mac-config \
  --checkout main \
  --inventory hosts \
  --only-if-changed
```

### Check launchd service status

```bash
# List loaded services
launchctl list | grep ansible

# View logs
tail -f ~/Library/Logs/ansible-pull.log

# Unload service (if needed)
launchctl unload ~/Library/LaunchAgents/com.user.ansible-pull.plist

# Load service
launchctl load ~/Library/LaunchAgents/com.user.ansible-pull.plist
```

## Directory Structure

```text
mac-config/
├── bootstrap.sh                # Quick setup script
├── local.yml                   # Main playbook
├── hosts                       # Inventory file
├── ansible.cfg                 # Ansible configuration
├── collections/
│   └── requirements.yml        # Galaxy collection requirements
├── roles/
│   ├── base/                   # System defaults and directories
│   ├── homebrew/               # Homebrew packages and casks
│   ├── dotfiles/               # Shell and git configuration
│   ├── vscode/                 # VS Code setup and extensions
│   └── launchd/                # Auto-update scheduling
└── group_vars/
    └── local.yml               # Local machine variables
```

## Roles Explained

### base

Configures macOS system defaults:

- Directory creation (~/.config, ~/.local/bin, etc.)
- Dock settings
- Finder settings
- Keyboard repeat rate

### homebrew

Manages package installation:

- Installs Homebrew if not present
- Runs `brew bundle` with Brewfile
- Installs additional packages via Ansible
- Provides outdated packages list

### dotfiles

Manages configuration files:

- zsh configuration with zimfw
- Git configuration
- Shell aliases
- Sets zsh as default shell

### vscode

Configures VS Code:

- Creates user settings directory
- Templates settings.json
- Installs extensions
- Supports idempotent installations

### launchd

Sets up automatic updates:

- Creates LaunchAgent plist
- Runs ansible-pull on login
- Configures logging
- Runs every 24 hours

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

### Install Testing Dependencies

```bash
pip install -r requirements.txt
```

### Run Molecule Tests for a Role

```bash
# Test base role
cd roles/base
molecule test

# Run individual steps
molecule create      # Create test VM
molecule converge    # Apply role
molecule verify      # Run verification
molecule destroy     # Clean up
```

### Run Linting Only

```bash
yamllint .
ansible-lint
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

#### 4. Test individual roles

```bash
ansible-playbook -i hosts local.yml --tags base --check
ansible-playbook -i hosts local.yml --tags homebrew --check
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
