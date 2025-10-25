#!/usr/bin/env bats
# Tests for trk init command

load test_helper

@test "init: creates a new repository" {
  run trk init
  assert_success
  assert_dir_exists ".git"
}

@test "init: creates repository in specified directory" {
  run trk init test-repo
  assert_success
  assert_dir_exists "test-repo/.git"
}

@test "init: sets up trk configuration" {
  run trk init
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  run git config --local trk.managed
  assert_success
  assert_output_equals "true"
}

@test "init: generates encryption passphrase" {
  run trk init
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  run git config --local trk.passphrase
  assert_success
  [[ -n "$output" ]]
}

@test "init: sets up git filters for encryption" {
  run trk init
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  run git config --local filter.crypt.clean
  assert_success
  [[ -n "$output" ]]

  run git config --local filter.crypt.smudge
  assert_success
  [[ -n "$output" ]]
}

@test "init: creates .gitattributes file" {
  skip "gitattributes created when files are marked for encryption"
}

@test "init: --without-encryption skips encryption setup" {
  run trk init --without-encryption
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  run git config --local filter.crypt.clean
  assert_failure
}

@test "init: --with-permissions sets up permissions tracking" {
  run trk init --with-permissions
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  run git config --local trk.permissions
  assert_success
  assert_output_equals "true"
}

@test "init: --worktree creates global repository" {
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  run trk init --worktree "$worktree"
  assert_success
  assert_output_contains "Initializing repository for worktree"

  local share_dir="$HOME/.local/share/trk/repo.git"
  assert_dir_exists "$share_dir"
}

@test "init: --worktree with non-existent path fails" {
  run trk init --worktree "/nonexistent/path"
  assert_failure
}

@test "init: --worktree sets core.worktree config" {
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  export GIT_DIR="$HOME/.local/share/trk/repo.git"
  run trk init --worktree "$worktree"
  assert_success

  run git config --local core.worktree
  assert_success
  assert_output_equals "$worktree"
}

@test "init: --worktree without --force fails if repository exists" {
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  run trk init --worktree "$worktree"
  assert_success

  # Try to init again without force
  run trk init --worktree "$worktree"
  assert_failure
  assert_output_contains "Repository already exists"
}

@test "init: --worktree with --force overwrites existing repository" {
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  run trk init --worktree "$worktree"
  assert_success

  # Init again with force
  run trk init --worktree "$worktree" --force
  assert_success
}

@test "init: passes through git init options" {
  skip "git init options interfere with trk's own options parsing"
}

@test "init: sets correct OpenSSL default arguments" {
  run trk init
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  run git config --local trk.openssl-args
  assert_success
  assert_output_contains "-aes-256-cbc"
  assert_output_contains "-pbkdf2"
}

@test "init: with --config-file imports configuration" {
  # Create a config file
  local config_file="$TEST_DIR/trk.config"
  cat > "$config_file" <<EOF
trk.openssl-args -aes-128-cbc -md sha256
EOF

  run trk init --config-file "$config_file"
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  run git config --local trk.openssl-args
  assert_success
  assert_output_equals "-aes-128-cbc -md sha256"
}

@test "init: creates git hooks with --with-permissions" {
  run trk init --with-permissions
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  assert_file_exists ".git/hooks/pre-commit"
  assert_file_exists ".git/hooks/post-checkout"
}

@test "init: hooks are executable" {
  run trk init --with-permissions
  assert_success

  cd "$(git rev-parse --show-toplevel)"
  [[ -x ".git/hooks/pre-commit" ]]
  [[ -x ".git/hooks/post-checkout" ]]
}
