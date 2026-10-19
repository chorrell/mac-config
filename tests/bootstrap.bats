#!/usr/bin/env bats
# Tests for bootstrap.sh
#
# The script runs with stub uv, brew, curl and uname commands on a minimal
# PATH, and a fake Homebrew prefix, so the real Homebrew, uv and playbook are
# never touched. Each stub logs its arguments to $STUB_LOG.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/bootstrap.sh"
  STUB_BIN="$BATS_TEST_TMPDIR/stubs"
  FAKE_BREW="$BATS_TEST_TMPDIR/fake-brew"

  export BREW_PREFIX="$BATS_TEST_TMPDIR/homebrew"
  export DOCKER_APP="$BATS_TEST_TMPDIR/Docker.app"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  export NO_COLOR=1

  mkdir -p "$STUB_BIN" "$BREW_PREFIX/bin" "$DOCKER_APP"

  write_stub "$STUB_BIN/uname" << 'EOF'
if [[ "$1" == -s ]]; then echo "${STUB_OS:-Darwin}"; else echo "${STUB_ARCH:-arm64}"; fi
EOF

  write_stub "$STUB_BIN/curl" << EOF
echo "curl \$*" >> "\$STUB_LOG"
# The "installer" puts a fake brew in the Homebrew prefix
echo "cp '$FAKE_BREW' '$BREW_PREFIX/bin/brew'"
EOF

  write_stub "$BATS_TEST_TMPDIR/uv" << 'EOF'
echo "uv $*" >> "$STUB_LOG"
echo "$PWD" > "$STUB_LOG.pwd"
if [[ -n "${STUB_PLAYBOOK_FAIL:-}" && "$*" == *"local.yml"* && "$*" != *--syntax-check* ]]; then
  exit 2
fi
EOF
  cp "$BATS_TEST_TMPDIR/uv" "$STUB_BIN/uv"

  write_stub "$FAKE_BREW" << EOF
echo "brew \$*" >> "\$STUB_LOG"
case "\$1" in
  shellenv) echo 'export PATH="$BREW_PREFIX/bin:\$PATH"' ;;
  install) cp '$BATS_TEST_TMPDIR/uv' '$BREW_PREFIX/bin/uv' ;;
esac
EOF
  cp "$FAKE_BREW" "$BREW_PREFIX/bin/brew"

  # Only the stubs and system tools: never /opt/homebrew or the real uv
  export PATH="$STUB_BIN:/usr/bin:/bin"
  [[ "$(command -v uv)" == "$STUB_BIN/uv" ]]
}

# Write an executable stub from stdin
write_stub() {
  {
    echo '#!/usr/bin/env bash'
    cat
  } > "$1"
  chmod +x "$1"
}

# Run the script with macOS's /bin/bash (3.2 on a Mac) and no terminal
run_bootstrap() {
  run /bin/bash "$SCRIPT" "$@" < /dev/null
}

@test "--help prints usage and runs nothing" {
  run_bootstrap --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [ ! -e "$STUB_LOG" ]
}

@test "stops on a system other than macOS" {
  export STUB_OS=Linux
  run_bootstrap

  [ "$status" -eq 1 ]
  [[ "$output" == *"must be run on macOS"* ]]
  [ ! -e "$STUB_LOG" ]
}

@test "stops on an Intel Mac" {
  export STUB_ARCH=x86_64
  run_bootstrap

  [ "$status" -eq 1 ]
  [[ "$output" == *"needs a Mac with Apple Silicon"* ]]
  [ ! -e "$STUB_LOG" ]
}

@test "a full run installs the dependencies, then runs the playbook" {
  run_bootstrap

  [ "$status" -eq 0 ]
  diff - "$STUB_LOG" << 'EOF'
brew shellenv
uv sync --locked --no-dev
uv run --no-dev ansible-galaxy collection install -r collections/requirements.yml
uv run --no-dev ansible-playbook -i hosts local.yml --syntax-check
uv run --no-dev ansible-playbook -i hosts local.yml
EOF
  [[ "$output" == *"Bootstrap completed successfully"* ]]
  [[ "$output" == *"Next steps:"* ]]
}

@test "runs from the repository when called from another directory" {
  cd "$BATS_TEST_TMPDIR"
  run_bootstrap

  [ "$status" -eq 0 ]
  [ "$(cat "$STUB_LOG.pwd")" == "$REPO_ROOT" ]
}

@test "passes arguments on to ansible-playbook" {
  run_bootstrap --tags vscode --check

  [ "$status" -eq 0 ]
  [ "$(tail -1 "$STUB_LOG")" == "uv run --no-dev ansible-playbook -i hosts local.yml --tags vscode --check" ]
  [[ "$output" != *"Next steps:"* ]]
}

@test "reports a failed playbook run" {
  export STUB_PLAYBOOK_FAIL=1
  run_bootstrap

  [ "$status" -eq 2 ]
  [[ "$output" == *"Bootstrap failed."* ]]
  [[ "$output" != *"completed successfully"* ]]
}

@test "installs Homebrew when it is missing" {
  rm "$BREW_PREFIX/bin/brew"
  run_bootstrap

  [ "$status" -eq 0 ]
  grep -qx "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$STUB_LOG"
  grep -qx "brew shellenv" "$STUB_LOG"
}

@test "installs uv with Homebrew when it is missing" {
  rm "$STUB_BIN/uv"
  run_bootstrap

  [ "$status" -eq 0 ]
  grep -qx "brew install uv" "$STUB_LOG"
  grep -qx "uv sync --locked --no-dev" "$STUB_LOG"
}

@test "does not wait for input about Docker Desktop without a terminal" {
  rmdir "$DOCKER_APP"
  run_bootstrap

  [ "$status" -eq 0 ]
  [[ "$output" != *"App Management"* ]]
}
