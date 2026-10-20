# Mac Configuration with Ansible

Ansible playbook that sets up a new Mac for development and DevOps work, based on the setup of my current Mac. Clone the repository and run one script to get:

- Homebrew and the command-line toolset (infrastructure as code, Kubernetes, linters and more)
- The [Ghostty](https://ghostty.org/) terminal, with its config, theme and font
- [VS Code](https://code.visualstudio.com/) with its extensions and settings
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [fastfetch](https://github.com/fastfetch-cli/fastfetch) and its preset
- zsh with [zimfw](https://zimfw.sh/), and [atuin](https://atuin.sh/) shell history
- Shared git settings, Git LFS and GnuPG

The playbook runs locally with `ansible-playbook` and is safe to run again: every role only changes what differs from the desired state.

## Prerequisites

- A Mac with Apple Silicon (Homebrew in `/opt/homebrew`)
- Internet access
- An administrator account, for installing Homebrew

## Quick Start

### Option 1: Bootstrap Script (Recommended)

```bash
git clone https://github.com/chorrell/mac-config.git
cd mac-config
./bootstrap.sh
```

On a new Mac, the first `git` command asks to install the Xcode Command Line Tools. Accept, wait for the install to finish, then run `git clone` again.

The bootstrap script will:

1. Check that it is running on a Mac with Apple Silicon
2. Install Homebrew (if not present) and add it to the `PATH` for the rest of the script
3. Install [uv](https://docs.astral.sh/uv/) (if not present)
4. Install a uv-managed Python 3.14 and Ansible into `.venv`
5. Install Ansible Galaxy collections
6. Validate the playbook syntax
7. If Docker Desktop is not installed yet, remind you to give your terminal the App Management permission it needs (see [Docker Role](#docker-role))
8. Run the Ansible playbook

It can be run from any directory. Arguments are passed on to `ansible-playbook`, so you can also use it to apply one role or to preview changes:

```bash
./bootstrap.sh --tags vscode
./bootstrap.sh --check --diff
```

### Option 2: Manual Setup

If you prefer to do this step by step:

```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to the PATH of this shell (the installer does not)
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install uv
brew install uv

# Install Python 3.14 and Ansible into .venv (from uv.lock)
uv sync --no-dev

# Install Ansible Galaxy collections
uv run --no-dev ansible-galaxy collection install -r collections/requirements.yml

# Run the playbook
uv run --no-dev ansible-playbook -i hosts local.yml
```

### After the First Run

Some settings are personal or secret, so they are not in this repository. Set them by hand on each new Mac:

- **git identity and signing**: see [Identity and Commit Signing](#identity-and-commit-signing)
- **Machine-specific shell settings and secrets**: put them in `~/.zshrc.local` (see [Machine-specific Settings and Secrets](#machine-specific-settings-and-secrets))
- **Shell history sync**: run `atuin login`
- **Docker Desktop**: open it once to accept the licence and let it install its helper

Open a new terminal window afterwards so the new `~/.zshrc` is loaded.

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

Each role's settings live in its `defaults/main.yml`, and its config files in its `files/` directory. To change what gets installed or configured, edit those, or override role defaults for this machine in `group_vars/local.yml`. For example, to change which directories the base role creates:

```yaml
config_dirs:
  - "{{ ansible_facts['user_dir'] }}/.config"
  - "{{ ansible_facts['user_dir'] }}/.local/bin"
```

Facts are only available as `ansible_facts[...]` (`inject_facts_as_vars` is off in `ansible.cfg`), so use `ansible_facts['user_dir']` rather than `ansible_user_dir`.

## Running the Playbook

### Run everything

```bash
uv run ansible-playbook -i hosts local.yml
```

### Run with tags

Each role has a tag, so you can apply one part at a time:

| Tag | Roles |
| --- | --- |
| `system` | base |
| `brew` | homebrew |
| `ghostty` | ghostty |
| `vscode` | vscode |
| `docker` | docker |
| `fastfetch` | fastfetch |
| `shell` | atuin and zsh (or `atuin`, `zsh` on their own) |
| `git` | git |

```bash
uv run ansible-playbook -i hosts local.yml --tags ghostty
```

### Dry run (check mode)

Show what would change, with diffs, without changing anything:

```bash
uv run ansible-playbook -i hosts local.yml --check --diff
```

## Directory Structure

```text
mac-config/
├── bootstrap.sh                # Installs Homebrew, uv and Ansible, then runs the playbook
├── local.yml                   # Main playbook
├── hosts                       # Inventory (localhost)
├── ansible.cfg                 # Ansible configuration
├── pyproject.toml              # Python dependencies (managed by uv)
├── uv.lock                     # Locked dependency versions
├── .python-version             # Python version used by uv
├── .ansible-lint               # Ansible linting config
├── .yamllint                   # YAML linting config
├── .pre-commit-config.yaml     # Pre-commit hooks
├── collections/
│   └── requirements.yml        # Galaxy collection requirements
├── group_vars/
│   └── local.yml               # Overrides for this machine
├── roles/
│   ├── atuin/                  # atuin and its config
│   ├── base/                   # Base directories
│   ├── docker/                 # Docker Desktop
│   ├── fastfetch/              # fastfetch and its preset
│   ├── ghostty/                # Ghostty terminal, font, config and themes
│   ├── git/                    # git settings, Git LFS and GnuPG
│   ├── homebrew/               # Homebrew taps, formulae and casks
│   ├── vscode/                 # VS Code, extensions, settings and font
│   └── zsh/                    # zshrc, zimrc and zimfw modules
├── molecule/
│   └── default/                # Molecule scenario for the whole playbook
│       ├── molecule.yml
│       ├── converge.yml
│       └── verify.yml
├── tests/
│   └── bootstrap.bats          # bats tests for bootstrap.sh
└── .github/workflows/
    ├── bootstrap.yml           # bats tests for bootstrap.sh on macOS
    ├── lint.yml                # ansible-lint and yamllint
    ├── linting.yml             # Shell script and Markdown lint
    └── molecule.yml            # Molecule test on macOS
```

## Base Role

The base role creates the directories the other roles rely on.

### What It Does

- **Directories**: Creates `~/.config` and `~/.local/bin` (set in `config_dirs`)

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

## VS Code Role

The vscode role installs [Visual Studio Code](https://code.visualstudio.com/), its extensions and the preferred user settings.

### What It Installs and Configures

- **VS Code**: Installed as a Homebrew cask, unless `/Applications/Visual Studio Code.app` already exists (for example from a download)
- **`code` CLI**: Linked into `/opt/homebrew/bin`, so it is on the `PATH` either way
- **Fonts**: The editor uses [Hack](https://sourcefoundry.org/hack/), installed from the `font-hack` cask. The integrated terminal uses MesloLGS NF from the ghostty role
- **Extensions**: Each entry in `vscode_extensions` is installed with `code --install-extension` if missing. Other installed extensions are left alone
- **Settings**: Each entry in `vscode_settings` is merged into `~/Library/Application Support/Code/User/settings.json` (any existing file is backed up first), so settings that are not listed are left alone. The file must be plain JSON: the role stops rather than drop comments

Both lists are in `roles/vscode/defaults/main.yml`. If VS Code Settings Sync is turned on, it syncs the same settings and extensions, so changes made in the editor can come back on the next sync. Run just this role with:

```bash
uv run ansible-playbook -i hosts local.yml --tags vscode
```

## Docker Role

The docker role installs [Docker Desktop](https://www.docker.com/products/docker-desktop/), which provides the `docker` CLI, Docker Compose and the Docker engine.

### What the Docker Role Installs

- **Docker Desktop**: Installed as the `docker-desktop` Homebrew cask, unless `/Applications/Docker.app` already exists (for example from a download). Docker Desktop updates itself
- **CLI**: The cask links `docker`, the credential helpers and the Compose plugin into `/usr/local/bin`. That directory belongs to root, so when Docker Desktop is installed the playbook asks for your password and passes it to Homebrew's `sudo`

Homebrew tags a file inside `Docker.app` after moving it into place, which macOS blocks unless the terminal running the playbook has **App Management** permission (System Settings → Privacy & Security → App Management). If the install fails with `xattr: [Errno 1] Operation not permitted`, turn it on for your terminal, restart the terminal and run the playbook again.

Open Docker Desktop once after the first run to accept the licence and let it install its helper; Docker settings, images and containers are not managed. Run just this role with:

```bash
uv run ansible-playbook -i hosts local.yml --tags docker
```

### Replacing a Downloaded Docker Desktop

To let Homebrew manage a copy of Docker Desktop that was installed from a download, quit Docker Desktop and run this in a terminal (it asks for your password). Images, containers and settings are kept, since they live outside the app:

```bash
brew install --cask --force docker-desktop
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

## Git Role

The git role installs git, Git LFS and GnuPG, and applies the global git settings.

### What It Manages

- **Packages**: `git`, `git-lfs`, `gnupg` and `pinentry-mac` from Homebrew
- **Settings**: Each entry in `git_config` (`roles/git/defaults/main.yml`) is set with `git config --global`, so settings that are not listed are left alone. This covers `pull.rebase`, `fetch.prune`, the Keychain credential helper, aliases and the Git LFS filter
- **Global gitignore**: `roles/git/files/gitignore` is copied to `~/.gitignore` and set as `core.excludesfile`
- **GnuPG**: `pinentry-mac` is set as the passphrase prompt in `~/.gnupg/gpg-agent.conf`. Keys and `gpg.conf` are not managed
- **Clean-up**: Filters left by the retired git-media and hawser tools are removed

### Identity and Commit Signing

Your name, email and signing key are not managed, since they can differ between machines (a work Mac, for example) and should not be in a public repository. Existing values are left alone. Set them once on each new Mac:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

To sign commits with GPG, import your private key, then point git at it and at the Homebrew `gpg`:

```bash
gpg --import /path/to/private-key.asc
git config --global user.signingkey <KEY-ID>
git config --global gpg.program /opt/homebrew/bin/gpg
git config --global commit.gpgsign true
```

Run just this role with:

```bash
uv run ansible-playbook -i hosts local.yml --tags git
```

## Upcoming Roles

Planned additions:

- **macos-defaults** - macOS system defaults such as keyboard repeat rate (under consideration)

## Troubleshooting

### Ansible not found

Ansible lives in the project's `.venv`, not on your `PATH`. Install it and run it through uv:

```bash
uv sync
uv run ansible --version
```

### Homebrew not found

The homebrew role stops early if `brew` is not in `/opt/homebrew`. Run `./bootstrap.sh`, which installs it, or install Homebrew by hand (see [Manual Setup](#option-2-manual-setup)).

### Homebrew issues

```bash
brew update
brew doctor
```

### Playbook output

Each run is also logged to `ansible.log` in the repository (set in `ansible.cfg`, and ignored by git).

## Testing

### Testing Prerequisites

- [uv](https://docs.astral.sh/uv/) (`brew install uv`); it installs Python 3.14 for you

**Warning:** Molecule runs the whole playbook against the Mac it runs on, not in a VM or container. On your own Mac, `molecule test` and `molecule converge` really apply the configuration, replacing files such as `~/.zshrc` (backed up first) and changing global git settings. Use a dry run (`--check --diff`) to preview changes instead. CI runs Molecule on a fresh macOS runner.

### Set Up Testing Environment

Install Ansible plus the testing and linting tools (the `dev` dependency group) into `.venv`:

```bash
# Install Python 3.14 and all dependencies, including dev tools
uv sync

# Install Galaxy collections
uv run ansible-galaxy collection install -r collections/requirements.yml
```

**Note:** `bootstrap.sh` runs `uv sync --no-dev`, which installs only Ansible. Plain `uv sync` also installs Molecule and the linters.

### Run Molecule Tests

The `default` scenario tests the whole playbook in four steps: syntax, converge, idempotence and verify. Under Molecule, the homebrew role installs only a small subset of the toolset (one tap, two formulae and one cask, set in `molecule/default/molecule.yml`) to keep runs fast.

```bash
# Full test cycle (syntax → converge → idempotence → verify)
uv run molecule test

# Or run individual steps:
uv run molecule syntax       # Check playbook syntax
uv run molecule converge     # Apply the playbook to this Mac
uv run molecule idempotence  # Converge again and check that nothing changes
uv run molecule verify       # Run the checks in verify.yml
```

A successful run ends with:

```text
default > syntax: Executed: Successful
default > converge: Executed: Successful
default > idempotence: Executed: Successful
default > verify: Executed: Successful
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

### Test the Bootstrap Script

`tests/bootstrap.bats` runs `bootstrap.sh` with stub `uv`, `brew`, `curl` and `uname` commands and a fake Homebrew prefix, so it never installs anything or runs the playbook. It checks the order of the setup steps, that arguments reach `ansible-playbook`, the macOS and Apple Silicon checks, failures, and installing Homebrew and uv when they are missing. It needs [bats](https://github.com/bats-core/bats-core), which the homebrew role installs:

```bash
bats tests/
```

### Run Linting Only

```bash
# YAML and Ansible
uv run yamllint .
uv run ansible-lint

# Markdown (the pre-commit hook runs markdownlint-cli2 in Docker)
uv run pre-commit run markdownlint-cli2-docker --all-files
```

### Pre-commit Hooks

Pre-commit hooks check changes before each commit. This repo runs:

- **uv-lock**: Keeps `uv.lock` in sync with `pyproject.toml`
- **yamllint** and **ansible-lint**: Run via `uv run`, so they use the versions locked in `uv.lock`
- **markdownlint**: Markdown formatting (needs Docker)
- **actionlint** and **zizmor**: GitHub Actions workflow correctness and security
- **gitleaks**: Catches committed secrets
- **shellcheck** and **shfmt**: Shell script checks and formatting for `bootstrap.sh`, with the same versions and flags as the `linting` workflow
- Standard file checks: trailing whitespace, end of file, YAML syntax, merge conflict markers, large files and line endings

To set up pre-commit hooks:

```bash
# pre-commit is installed by `uv sync` (dev group)
uv run pre-commit install

# Run hooks on all files (optional)
uv run pre-commit run --all-files
```

### Manual Configuration Testing

#### 1. Syntax validation

```bash
uv run ansible-playbook -i hosts local.yml --syntax-check
```

#### 2. Check mode (dry run)

```bash
uv run ansible-playbook -i hosts local.yml --check --diff
```

#### 3. Idempotency test

Run twice and verify no changes on the second run:

```bash
uv run ansible-playbook -i hosts local.yml
uv run ansible-playbook -i hosts local.yml  # Should show changed=0
```

### CI/CD Testing

GitHub Actions runs these workflows:

- **Lint** (ansible-lint and yamllint) and **Molecule** run on pull requests, and again on pushes to `main` to check the merged result. Both only run when roles, playbooks, Molecule files, their own workflow or the Python dependencies change
- **Bootstrap Tests** runs the bats tests for `bootstrap.sh` on every pull request (it is a required check), and on pushes to `main` that change the script, its tests or the workflow
- **linting** (shellcheck, shfmt and markdownlint) runs on pull requests to `main`

Pushes to a pull request's branch are covered by the pull request run, so each change is tested once. A new push to a pull request cancels the run still in progress for it.

The lint jobs run on the single-CPU `ubuntu-slim` runner. Molecule and the bootstrap tests need macOS, so they run on `macos-latest`; the bootstrap tests then use the system bash 3.2, as a new Mac does. See `.github/workflows/` for details.

## Design Principles

- **Idempotent**: Every task is safe to run repeatedly; a second run reports no changes
- **One role per tool**: A tool that has its own configuration is installed and configured by its own role; the homebrew role holds the general toolset
- **Leave the rest alone**: Settings are applied one at a time (for example `git config --global`) rather than overwriting whole files, and replaced files are backed up first
- **Nothing personal or secret in the repo**: Identity, keys and tokens are set per machine
- **Tags**: Each role can be applied on its own

## Contributing

To adapt this for your own Mac:

1. Fork this repository
2. Edit the role defaults (`roles/*/defaults/main.yml`) and config files (`roles/*/files/`), or override defaults in `group_vars/local.yml`
3. Preview with `uv run ansible-playbook -i hosts local.yml --check --diff`
4. Run `uv run pre-commit run --all-files`
5. Commit your changes and open a pull request; CI runs the linters and Molecule

## Support

For issues or questions:

- Review the Ansible output, or `ansible.log` in the repository
- Re-run with more detail: `uv run ansible-playbook -i hosts local.yml -vv`
- Check that the prerequisites are installed and that GitHub is reachable

## License

MIT License - See LICENSE file for details

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Tips and Tricks](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [Homebrew Documentation](https://docs.brew.sh/)
- [macOS Defaults](https://macos-defaults.com/)
