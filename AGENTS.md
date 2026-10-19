# AGENTS.md

Ansible playbook that sets up a new Apple Silicon Mac for development and DevOps work: Homebrew tools, Ghostty,
VS Code, Docker Desktop, fastfetch, zsh with zimfw, atuin and shared git settings. It runs locally with `ansible-playbook` against
`localhost`. See `README.md` for what each role does.

## Commands

```bash
# Install Python, Ansible and dev tools into .venv, then Galaxy collections
uv sync
uv run ansible-galaxy collection install -r collections/requirements.yml

# Lint
uv run yamllint .
uv run ansible-lint
uv run pre-commit run --all-files   # everything, including markdownlint (needs Docker)

# Check without changing anything
uv run ansible-playbook -i hosts local.yml --syntax-check
uv run ansible-playbook -i hosts local.yml --check --diff
uv run ansible-playbook -i hosts local.yml --tags <tag> --check --diff
```

**Do not run `ansible-playbook local.yml`, `molecule converge` or `molecule test` without being asked.** They apply the
playbook to the Mac they run on (there is no VM), replacing files such as `~/.zshrc` and changing global git config.
Use `--check --diff` to show what a change would do. CI runs the full Molecule test on a fresh macOS runner.

## Layout

```text
local.yml                  # Playbook: base, homebrew, ghostty, vscode, docker, fastfetch, atuin, zsh, git
roles/<role>/defaults/     # Settings and package lists
roles/<role>/files/        # Config files copied to the Mac
roles/<role>/tasks/        # Tasks
group_vars/local.yml       # Per-machine overrides
molecule/default/          # Molecule scenario for the whole playbook (verify.yml holds the checks)
.github/workflows/         # lint.yml, markdownlint.yml, molecule.yml
```

## Conventions

- **One role per tool.** A tool with its own configuration is installed (via Homebrew) and configured by its own role.
  The homebrew role lists only the general toolset; don't add tools there that a role already installs.
- **Idempotent.** A second run must report `changed=0`. Use modules over `command`/`shell`; when a command is
  unavoidable, set `changed_when` and `creates` as appropriate.
- **Leave unmanaged settings alone.** Apply settings one at a time (for example `community.general.git_config`) rather
  than overwriting whole files. Use `backup: true` when copying over user files.
- **Nothing personal or secret in the repo.** It is public and meant for any new Mac, including a work one. Name,
  email, signing keys, tokens and machine-specific paths stay out (they go in `~/.zshrc.local` or are set by hand).
- **Facts only via `ansible_facts[...]`.** `inject_facts_as_vars` is off, so `ansible_user_dir` is undefined; use
  `ansible_facts['user_dir']`.
- **Homebrew lives in `/opt/homebrew`.** Pass `path: /opt/homebrew/bin` to the Homebrew modules. Third-party taps must
  be trusted (`trust: true`) or Homebrew refuses to load them.
- **Use FQCN** for all modules (`ansible.builtin.copy`, `community.general.homebrew`).
- **Every new role** gets a tag in `local.yml`, checks in `molecule/default/verify.yml`, and a section in `README.md`.
  Verify tasks that run commands need `changed_when: false`. Markdown headings must be unique (markdownlint MD024).

## Git and Pull Requests

- All changes go through a pull request; `main` is protected. Branch from `main` as `feature/<description>` or
  `fix/<description>`, usually one role or change per PR.
- Commit messages and PR titles use conventional commits (`feat: ...`, `fix(zsh): ...`, `chore(deps): ...`,
  `docs: ...`, `ci: ...`).
- Keep PR descriptions brief: a few bullets or one paragraph on what changed and why. No Problem/Solution/Changes
  templates, and no AI attribution lines.
- PRs are squash-merged, so each lands as one commit; merged branches are deleted automatically.
- Force-push only to feature branches, with `git push --force-with-lease`. To update a branch with `main`, merge
  `main` in.
- Before opening a PR, run `uv run pre-commit run --all-files` and a `--check --diff` run of the affected tags.

## Gotchas

- Molecule overrides the homebrew role's lists with a small subset (`molecule/default/molecule.yml`), so CI does not
  install the full toolset.
- Lint jobs run on the `ubuntu-slim` runner (1 CPU, 15-minute limit, no Docker); Molecule needs `macos-latest`.
- `pre-commit`'s markdownlint hook runs in Docker.
