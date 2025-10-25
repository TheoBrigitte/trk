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

# Setup function called before each test
setup() {
  # Create a unique test directory
  TEST_DIR="$(mktemp -d -t trk-test.XXXXXXXXXX)"
  cd "$TEST_DIR" || exit 1

  # Set HOME to test directory to isolate git config
  export HOME="$TEST_DIR"
  export XDG_CONFIG_HOME="$TEST_DIR/.config"

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

# Assert command succeeds
assert_success() {
  if [[ $status -ne 0 ]]; then
    echo "Command failed with status $status"
    echo "Output: $output"
    return 1
  fi
}

# Assert command fails
assert_failure() {
  if [[ $status -eq 0 ]]; then
    echo "Command succeeded but was expected to fail"
    echo "Output: $output"
    return 1
  fi
}

# Assert output contains string
assert_output_contains() {
  local expected="$1"
  if [[ ! "$output" =~ $expected ]]; then
    echo "Output does not contain expected string"
    echo "Expected: $expected"
    echo "Actual: $output"
    return 1
  fi
}

# Assert output equals string
assert_output_equals() {
  local expected="$1"
  if [[ "$output" != "$expected" ]]; then
    echo "Output does not match expected"
    echo "Expected: $expected"
    echo "Actual: $output"
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
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

# Assert file contains string
assert_file_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -q "$expected" "$file"; then
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
  local actual
  actual="$(git config "$key")"
  if [[ "$actual" != "$expected" ]]; then
    echo "Git config mismatch"
    echo "Key: $key"
    echo "Expected: $expected"
    echo "Actual: $actual"
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
  local name="$1"
  local remote_dir="$TEST_DIR/remotes/$name"
  mkdir -p "$remote_dir"
  git -C "$remote_dir" init --bare --quiet
  echo "$remote_dir"
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
  sha="$(git ls-files -s "$file" | awk '{print $2}')"
  local content
  content="$(git cat-file -p "$sha")"

  # Check if content starts with "Salted__" (OpenSSL encrypted format)
  if [[ "$content" =~ ^Salted__ ]] || echo "$content" | head -c 8 | grep -q "Salted__"; then
    return 0
  fi
  return 1
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
