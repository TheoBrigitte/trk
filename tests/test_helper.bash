#!/bin/bash
# Test helper functions for trk test suite

# Test directory setup
TEST_ROOT="${BATS_TEST_DIRNAME}"
TEST_TMP_DIR="${BATS_TEST_TMPDIR:-/tmp/trk-test-$$}"

# Path to trk binary
TRK_BIN="${TEST_ROOT}/../bin/trk"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

######################
# Setup and teardown #
######################

# Setup function called before each test
setup() {
  # Load Bats helpers
  load 'bats/support/load'
  load 'bats/assert/load'

  # Create a unique test directory
  TEST_DIR="$(mktemp -d -t trk-test.XXXXXXXXXX)"
  cd "$TEST_DIR" || exit 1

  # Set HOME to test directory to isolate git config
  export HOME="$TEST_DIR"
  export XDG_CONFIG_HOME="$TEST_DIR/.config"
  # Add trk binary to PATH
  export PATH="$TEST_ROOT/../bin:$PATH"

  # Configure git for tests
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  git config --global init.defaultBranch main

  # Clear any existing GIT_DIR
  unset GIT_DIR
  unset GIT_WORK_TREE
}

# Teardown function called after each test
teardown() {
  # Clean up test directory
  if [[ -n "$TEST_DIR" ]] && [[ -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi

  # Clean up shared directories
  local share_dir="$HOME/.local/share/trk"
  if [[ -d "$share_dir" ]]; then
    rm -rf "$share_dir"
  fi
}

# Run trk command
trk() {
  "$TRK_BIN" "$@"
}


######################
#    trk helpers     #
######################

assert_is_global_repository() {
  assert_dir_exists "$HOME/.local/share/trk/repo.git"
  trk config get --local core.worktree
  assert_git_config "status.showUntrackedFiles" "no"

  export GIT_DIR="$(trk rev-parse --absolute-git-dir)"
  run git worktree list --porcelain
  assert_output --partial "worktree $HOME/.local/share/trk/repo.git"
}

refute_is_global_repository() {
  refute_dir_exists "$HOME/.local/share/trk/repo.git"
  refute_git_config "core.worktree"
  refute_git_config "status.showUntrackedFiles"

  export GIT_DIR="$(trk rev-parse --absolute-git-dir)"
  run git worktree list --porcelain
  refute_output "worktree $HOME/.local/share/trk/repo.git"
}

assert_base_configuration() {
  assert_git_config "trk.managed" "true"
  assert_git_config "core.bare" "false" "false"
}

assert_permission_configured() {
  # hooks files exists
  git_dir="$(trk rev-parse --absolute-git-dir)"
  assert_file_exists "$git_dir/hooks/pre-commit"
  assert_file_exists "$git_dir/hooks/post-checkout"

  # hooks files are executable
  [[ -x "$git_dir/hooks/pre-commit" ]]
  [[ -x "$git_dir/hooks/post-checkout" ]]
}

refute_permission_configured() {
  # trk configuration is set
  refute_git_config "trk.permissions" "true"

  # hooks files exists
  git_dir="$(trk rev-parse --absolute-git-dir)"
  refute_file_exists "$git_dir/hooks/pre-commit"
  refute_file_exists "$git_dir/hooks/post-checkout"

  # hooks files are executable
  ! [[ -x "$git_dir/hooks/pre-commit" ]]
  ! [[ -x "$git_dir/hooks/post-checkout" ]]
}

assert_encryption_configured() {
  # git filters are set
  assert_git_config "filter.git-crypt.required" 'true'
  assert_git_config "filter.git-crypt.smudge" '"git-crypt" smudge'
  assert_git_config "filter.git-crypt.clean" '"git-crypt" clean'
  assert_git_config "diff.git-crypt.textconv" '"git-crypt" diff'

  # git-crypt dir and key exists
  git_dir="$(trk rev-parse --absolute-git-dir)"
  assert_dir_exists "$git_dir/git-crypt"
  run file --brief --mime "$git_dir/git-crypt/keys/default"
  assert_success
  assert_output --partial "application/octet-stream; charset=binary"
}

refute_encryption_configured() {
  # git filters are set
  refute_git_config "filter.git-crypt.required" 'true'
  refute_git_config "filter.git-crypt.smudge" '"git-crypt" smudge'
  refute_git_config "filter.git-crypt.clean" '"git-crypt" clean'
  refute_git_config "diff.git-crypt.textconv" '"git-crypt" diff'

  # git-crypt dir and key exists
  git_dir="$(trk rev-parse --absolute-git-dir)"
  ! assert_dir_exists "$git_dir/git-crypt"
}

######################
#    git helpers     #
######################

assert_git_checkout_clean() {
  run trk diff HEAD --quiet
  assert_success

  run trk ls-files --others --exclude-standard
  assert_success
  assert_output ""
}

######################
#   Assert helpers   #
######################

# Assert file exists
assert_file_exists() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "File does not exist: $file"
    return 1
  fi
}

refute_file_exists() {
  local file="$1"
  if [[ -f "$file" ]]; then
    echo "File does not exist: $file"
    return 1
  fi
}

# Assert directory exists
assert_dir_exists() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "Directory does not exist: $dir"
    return 1
  fi
}

# Assert directory exists
refute_dir_exists() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    echo "Directory should not exist: $dir"
    return 1
  fi
}

# Assert file contains string
assert_file_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$file"; then
    echo "File does not contain expected string"
    echo "File: $file"
    echo "Expected: $expected"
    return 1
  fi
}

# Assert git config value
assert_git_config() {
  local key="$1"
  local expected="$2"
  local default="${3-}"
  local actual
  if ! actual="$(trk config get --local --default "$default" "$key")"; then
    echo "trk config get --local '$key' --default '$default', should have failed"
    return 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "trk configuration '$key' expected '$expected' got '$actual'"
    return 1
  fi
}

refute_git_config() {
  local key="$1"
  local actual
  if trk config get --local "$key" &>/dev/null; then
    echo "trk config get --local '$key', should have failed"
    return 1
  fi
}

# Create a test file with content
create_file() {
  local file="$1"
  local content="$2"
  mkdir -p "$(dirname "$file")"
  echo "$content" > "$file"
}

# Create a test git remote repository
create_remote_repo() {
  mkdir -p "$1"
  git -C "$1" init --bare --quiet
}

# Create a test git remote repository
create_remote_repo_with_file() {
  create_remote_repo "$1"
  git -C "$1" worktree add --orphan -b main work
  create_file "$1/work/$2" "$3"
  git -C "$1/work" add "./$2"
  git -C "$1/work" commit --quiet -m "Initial commit"
}

# Initialize a test repository with some content
init_test_repo() {
  git init --quiet
  create_file "README.md" "# Test Repository"
  git add README.md
  git commit --quiet -m "Initial commit"
}

# Check if file is encrypted in git
is_encrypted_in_git() {
  local file="$1"
  local sha
  sha="$(trk ls-files -s "$file" | awk '{print $2}')"
  local content
  content="$(trk cat-file -p "$sha")"

  # Check if content starts with "GITCRYPT" (git-crypt encrypted format)
  if ! [[ "$content" =~ ^GITCRYPT ]]; then
    return 1
  fi

  # Ensure that file content is not stored in clear
  if [[ "$content" =~ "$(cat "$file")" ]]; then
    return 1
  fi

  return 0
}

# Wait for file to be modified (useful for async operations)
wait_for_file() {
  local file="$1"
  local timeout="${2:-5}"
  local elapsed=0

  while [[ ! -f "$file" ]] && [[ $elapsed -lt $timeout ]]; do
    sleep 0.1
    elapsed=$((elapsed + 1))
  done

  [[ -f "$file" ]]
}

# Print debug info
debug_info() {
  echo "=== Debug Info ==="
  echo "PWD: $PWD"
  echo "TEST_DIR: $TEST_DIR"
  echo "Files:"
  ls -la
  if [[ -d .git ]]; then
    echo "Git status:"
    git status
    echo "Git config:"
    git config --list --local
  fi
  echo "=================="
}
