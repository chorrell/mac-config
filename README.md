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
2. Install [uv](https://docs.astral.sh/uv/) (if not present)
3. Install a uv-managed Python 3.14 and Ansible into `.venv`
4. Install Ansible Galaxy collections
5. Validate the playbook syntax
6. Run the Ansible playbook

### Option 2: Manual Setup

If you prefer to do this step by step:

```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install uv
brew install uv

# Install Python 3.14 and Ansible into .venv (from uv.lock)
uv sync --no-dev

# Install Ansible Galaxy collections
uv run --no-dev ansible-galaxy collection install -r collections/requirements.yml

# Run the playbook
uv run --no-dev ansible-playbook -i hosts local.yml
```

## Python and Ansible Environment

Ansible and its Python dependencies are managed with [uv](https://docs.astral.sh/uv/) and are never installed into the system Python:

- `.python-version` pins Python **3.14**, the newest version supported by ansible-core 2.21.
- `pyproject.toml` declares the dependencies (`ansible-core` at runtime; Molecule, ansible-lint, yamllint and pre-commit in the `dev` group).
- `uv.lock` pins exact versions so every machine and CI run gets the same environment.
- `[tool.uv] python-preference = "only-managed"` makes uv download its own Python and ignore the system or Homebrew one.
- The inventory sets `ansible_python_interpreter` to `{{ ansible_playbook_python }}`, so modules also run under the uv-managed Python.

Run Ansible commands with `uv run` (for example, `uv run ansible-playbook local.yml`), or activate the environment with `source .venv/bin/activate`.

To update dependencies:

```bash
uv lock --upgrade   # Upgrade everything within the constraints in pyproject.toml
uv sync             # Apply the updated lock file
```

## Configuration

Before running the playbook, customize the configuration:

### 1. Edit group_vars/local.yml

Override any role defaults for your machine here. For example, to change which directories the base role creates:

```yaml
config_dirs:
  - "{{ ansible_user_dir }}/.config"
  - "{{ ansible_user_dir }}/.local/bin"
```

### 2. Customize Base Role (Optional)

Review the defaults in `roles/base/defaults/main.yml`, including `config_dirs` (the directories to create).

## Running the Playbook

### Run the base role

```bash
uv run ansible-playbook -i hosts local.yml
```

### Run with tags

```bash
# Only system configuration
uv run ansible-playbook -i hosts local.yml --tags system
```

### Dry run (check mode)

```bash
uv run ansible-playbook -i hosts local.yml --check
```

## Branch Structure

This repository uses feature branches to isolate and review each role:

- **main** - Stable, production-ready configuration
- **feature/base-role** - Base system configuration (current)
- **feature/homebrew-role** - Package management
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
├── pyproject.toml              # Python dependencies (managed by uv)
├── uv.lock                     # Locked dependency versions
├── .python-version             # Python version used by uv
├── .ansible-lint               # Ansible linting config
├── .yamllint                   # YAML linting config
├── collections/
│   └── requirements.yml        # Galaxy collection requirements
├── roles/
│   ├── atuin/                  # atuin and its config
│   ├── base/                   # Base directories
│   ├── fastfetch/              # fastfetch and its preset
│   ├── ghostty/                # Ghostty terminal, font, config and themes
│   ├── homebrew/               # Homebrew taps, formulae and casks
│   └── zsh/                    # zshrc, zimrc and zimfw modules
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

The base role (current) sets up the essential base directories:

### What It Does

- **Directory Creation**: Creates `~/.config` and `~/.local/bin` directories
- **Idempotency**: All tasks check current state before applying changes

### Verification

Molecule tests verify:

- Required directories are created with correct permissions
- All tasks are idempotent (safe to run multiple times)

## Homebrew Role

The homebrew role installs the development and DevOps toolset. Homebrew itself is installed by `bootstrap.sh` before Ansible runs; the role fails early with a pointer to the script if `brew` is missing.

### What It Installs

- **Taps**: Adds the third-party taps in `homebrew_taps` and marks them trusted (Homebrew refuses to load formulae and casks from untrusted taps)
- **Formulae**: Installs the command-line tools in `homebrew_formulae`
- **Casks**: Installs the applications in `homebrew_casks`

Packages are only ever installed, never upgraded or removed. Tools that come with their own configuration (such as Ghostty and fastfetch) are installed by their own roles rather than listed here.

To change the toolset, edit the lists in `roles/homebrew/defaults/main.yml`, or override them in `group_vars/local.yml`. Run just this role with:

```bash
uv run ansible-playbook -i hosts local.yml --tags brew
```

## Ghostty Role

The ghostty role installs the [Ghostty](https://ghostty.org/) terminal and applies the preferred settings.

### What It Sets Up

- **Ghostty**: Installed as a Homebrew cask
- **Font**: MesloLGS NF (Meslo with Nerd Font glyphs) in `~/Library/Fonts`, downloaded from a pinned commit of [romkatv/powerlevel10k-media](https://github.com/romkatv/powerlevel10k-media) and verified by SHA-256
- **Config**: `roles/ghostty/files/config` is copied to `~/.config/ghostty/config` (any existing file is backed up first)
- **Themes**: Custom themes in `roles/ghostty/files/themes/` are copied to `~/.config/ghostty/themes/`, including `panic`, a port of the Panic palette from macOS Terminal

To change a setting, edit `roles/ghostty/files/config`. Molecule runs `ghostty +validate-config` against the installed config, which also catches a missing theme. Run just this role with:

```bash
uv run ansible-playbook -i hosts local.yml --tags ghostty
```

## fastfetch Role

The fastfetch role installs [fastfetch](https://github.com/fastfetch-cli/fastfetch) and its preset.

### What It Configures

- **fastfetch**: Installed as a Homebrew formula
- **Config**: `roles/fastfetch/files/config.jsonc` is copied to `~/.config/fastfetch/config.jsonc` (any existing file is backed up first). The preset shows OS, host, uptime, packages, CPU with temperature and core counts, memory, swap, disks, local IPs, battery, power adapter, locale and the colour blocks

To change the preset, edit `roles/fastfetch/files/config.jsonc`. Molecule runs fastfetch against the installed config, which fails if the file cannot be parsed. Run just this role with:

```bash
uv run ansible-playbook -i hosts local.yml --tags fastfetch
```

## zsh and atuin Roles

The zsh role sets up the shell with [zimfw](https://zimfw.sh/), and the atuin role adds [atuin](https://atuin.sh/) history search. macOS already uses `/bin/zsh` as the login shell, so the shell itself is not changed.

### What They Configure

- **zshrc**: `roles/zsh/files/zshrc` is copied to `~/.zshrc`. It runs fastfetch, initializes zimfw, sets the history options and aliases, and activates mise and atuin when they are installed
- **zimrc**: `roles/zsh/files/zimrc` is copied to `~/.zimrc`, listing the zim modules (bira prompt, completions, syntax highlighting, history substring search, autosuggestions, Homebrew and direnv)
- **zimfw**: Downloaded to `~/.zim`, with the modules installed. Changing `zimrc` reinstalls the modules on the next run
- **atuin**: Installed as a Homebrew formula, with `roles/atuin/files/config.toml` copied to `~/.config/atuin/config.toml` (daemon-backed fuzzy search, enter runs the command, ctrl+number shortcuts). The up arrow stays with zsh-history-substring-search; atuin is on ctrl+r

Existing `~/.zshrc`, `~/.zimrc` and atuin config files are backed up before they are replaced.

### Machine-specific Settings and Secrets

`~/.zshrc` sources `~/.zshrc.local` if it exists. Use it for anything that should not be in this repository, such as PATH entries for tools installed outside Homebrew or API tokens. Neither `~/.zshrc.local` nor `~/.zshenv` is managed.

To sync shell history between machines, run `atuin login` after the playbook; it needs your sync key, so it is not automated.

Run just these roles with:

```bash
uv run ansible-playbook -i hosts local.yml --tags shell
```

### Upcoming Roles

Future feature branches will add:

- **dotfiles** - Git configuration
- **vscode** - VS Code extensions and configuration
- **launchd** - Automatic ansible-pull scheduling on login
- **macos-defaults** - macOS system defaults such as keyboard repeat rate (under consideration)

## Troubleshooting

### Ansible not found

Ansible lives in the project's `.venv`, not on your `PATH`. Install it and run it through uv:

```bash
uv sync
uv run ansible --version
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

- [uv](https://docs.astral.sh/uv/) (`brew install uv`); it installs Python 3.14 for you

**Note:** Molecule tests run directly on your macOS system (no VM needed), so all required dependencies are automatically available.

### Set Up Testing Environment

Install Ansible plus the testing and linting tools (the `dev` dependency group) into `.venv`:

```bash
# Install Python 3.14 and all dependencies, including dev tools
uv sync

# Install Galaxy collections
uv run ansible-galaxy collection install -r collections/requirements.yml
```

**Note:** `bootstrap.sh` runs `uv sync --no-dev`, which installs only Ansible. Plain `uv sync` also installs Molecule and the linters.

### Run Molecule Tests for a Role

First, set up the testing environment as described above (`uv sync`), then run the tests:

```bash
# Full test cycle for complete playbook (syntax → converge → idempotence → verify)
uv run molecule test

# Or run individual steps:
uv run molecule syntax    # Check playbook syntax
uv run molecule converge  # Apply the playbook to localhost
uv run molecule idempotence # Verify idempotency (converge twice)
uv run molecule verify    # Run verification tests

# Useful for debugging:
uv run molecule converge  # Run playbook once
uv run molecule converge --extra-vars "debug=true"  # Add debugging
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
# Install dev dependencies (a plain `uv sync` includes them)
uv sync

# Verify molecule is installed
uv run molecule --version
```

**Ansible or collection errors:**

```bash
# Recreate the environment from uv.lock
uv sync --reinstall

# Reinstall collections
uv run ansible-galaxy collection install -r collections/requirements.yml
```

**Cache issues:**

```bash
# Clear Molecule scenario cache
uv run molecule destroy
rm -rf .molecule/
```

### Run Linting Only

```bash
# Run all linting
uv run yamllint .
uv run ansible-lint

# Or run individually:
uv run yamllint roles/base/          # Check YAML syntax
uv run ansible-lint roles/base/      # Check Ansible best practices
markdownlint-cli2 "**/*.md"   # Check Markdown (requires Docker)
```

### Pre-commit Hooks

Pre-commit hooks automatically validate code before commits. This repo includes:

- **uv-lock**: Keeps `uv.lock` in sync with `pyproject.toml`
- **markdownlint**: Validates markdown formatting
- **yamllint** and **ansible-lint**: Run via `uv run`, so they use the versions locked in `uv.lock`

To set up pre-commit hooks:

```bash
# pre-commit is installed by `uv sync` (dev group)
# Install git hooks in your repo
uv run pre-commit install

# Run hooks on all files (optional)
uv run pre-commit run --all-files

# Hooks will now run automatically on `git commit`
```

### Manual Configuration Testing

#### 1. Syntax validation

```bash
uv run ansible-playbook -i hosts local.yml --syntax-check
```

#### 2. Check mode (dry run)

```bash
uv run ansible-playbook -i hosts local.yml --check
```

#### 3. Idempotency test

Run twice and verify no changes on second run:

```bash
uv run ansible-playbook -i hosts local.yml
uv run ansible-playbook -i hosts local.yml  # Should show no changes
```

#### 4. Test the base role

```bash
uv run ansible-playbook -i hosts local.yml --tags system --check
```

### CI/CD Testing

GitHub Actions runs these workflows:

- **Lint** (ansible-lint and yamllint) and **Molecule** run on pull requests, and again on pushes to `main` to check the merged result. Both only run when roles, playbooks, Molecule files, their own workflow or the Python dependencies change
- **markdownlint** runs on pull requests to `main`

Pushes to a pull request's branch are covered by the pull request run, so each change is tested once. A new push to a pull request cancels the run still in progress for it.

The lint jobs run on the single-CPU `ubuntu-slim` runner. Molecule needs macOS, so it runs on `macos-latest`. See `.github/workflows/` for details.

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
4. Add/remove packages in `roles/homebrew/defaults/main.yml`
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
