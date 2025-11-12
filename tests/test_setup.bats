#!/usr/bin/env bats
# Tests for trk setup and unsetup commands

load test_helper

@test "setup: configures existing git repository" {
  init_test_repo

  run trk setup
  assert_success

  run git config --local trk.managed
  assert_success
  assert_output "true"
}

@test "setup: generates encryption passphrase" {
  init_test_repo

  run trk setup
  assert_success

  run git config --local trk.passphrase
  assert_success
  [[ -n "$output" ]]
}

@test "setup: sets up git filters" {
  init_test_repo

  run trk setup
  assert_success

  run git config --local filter.crypt.clean
  assert_success
  [[ -n "$output" ]]

  run git config --local filter.crypt.smudge
  assert_success
  [[ -n "$output" ]]
}

@test "setup: --without-encryption skips encryption setup" {
  init_test_repo

  run trk setup --without-encryption
  assert_success

  run git config --local trk.passphrase
  assert_failure
}

@test "setup: --with-permissions enables permissions tracking" {
  init_test_repo

  run trk setup --with-permissions
  assert_success

  run git config --local trk.permissions
  assert_success
  assert_output "true"
}

@test "setup: with --config-file imports configuration" {
  init_test_repo

  # Create a config file
  local config_file="$TEST_DIR/trk.config"
  cat > "$config_file" <<EOF
trk.passphrase test-passphrase-123
trk.openssl-args -aes-128-cbc -md sha256
EOF

  run trk setup --config-file "$config_file"
  assert_success

  run git config --local trk.passphrase
  assert_success
  assert_output "test-passphrase-123"

  run git config --local trk.openssl-args
  assert_success
  assert_output "-aes-128-cbc -md sha256"
}

@test "setup: fails in non-git repository" {
  run trk setup
  assert_failure
}

@test "setup: installs git hooks with --with-permissions" {
  init_test_repo

  run trk setup --with-permissions
  assert_success

  assert_file_exists ".git/hooks/pre-commit"
  assert_file_exists ".git/hooks/post-checkout"
}

@test "setup: hooks are executable" {
  init_test_repo

  run trk setup --with-permissions
  assert_success

  [[ -x ".git/hooks/pre-commit" ]]
  [[ -x ".git/hooks/post-checkout" ]]
}

@test "unsetup: disables trk management" {
  init_test_repo
  run trk setup
  assert_success

  run trk unsetup
  assert_success

  run git config --local trk.managed
  assert_success
  assert_output "false"
}

@test "unsetup: disables encryption filters" {
  init_test_repo
  run trk setup
  assert_success

  run trk unsetup
  assert_success

  run git config --local filter.crypt.clean
  assert_failure
}

@test "unsetup: disables permissions tracking" {
  init_test_repo
  run trk setup --with-permissions
  assert_success

  run trk unsetup
  assert_success

  run git config --local trk.permissions
  assert_failure
}

@test "unsetup: --prune removes all trk configuration" {
  init_test_repo
  run trk setup
  assert_success

  run trk unsetup --prune
  assert_success

  # All trk.* config should be removed
  run git config --local --get-regexp '^trk\.'
  assert_failure
}

@test "unsetup: --prune removes .gitattributes" {
  init_test_repo
  run trk setup
  assert_success

  run trk unsetup --prune
  assert_success

  [[ ! -f ".gitattributes" ]]
}

@test "unsetup: --prune removes .gitpermissions" {
  init_test_repo
  run trk setup --with-permissions
  assert_success

  # Create .gitpermissions file
  create_file ".gitpermissions" "README.md 644"
  git add .gitpermissions
  git commit --quiet -m "Add permissions"

  run trk unsetup --prune
  assert_success

  [[ ! -f ".gitpermissions" ]]
}

@test "unsetup: without --prune keeps files" {
  init_test_repo
  run trk setup
  assert_success

  # Mark a file to create .gitattributes
  create_file "secret.txt" "secret"
  trk mark "secret.txt"

  run trk unsetup
  assert_success

  # Files should still exist
  assert_file_exists ".gitattributes"
}

@test "unsetup: can be run on unmanaged repository" {
  init_test_repo

  run trk unsetup
  assert_success
}

@test "setup: can reconfigure after unsetup" {
  init_test_repo
  run trk setup
  assert_success

  run trk unsetup
  assert_success

  run trk setup
  assert_success

  run git config --local trk.managed
  assert_success
  assert_output "true"
}

@test "setup: preserves existing passphrase if present" {
  init_test_repo
  git config --local trk.passphrase "existing-passphrase"

  run trk setup
  assert_success

  run git config --local trk.passphrase
  assert_success
  assert_output "existing-passphrase"
}

@test "setup: updates filter configuration" {
  init_test_repo
  run trk setup
  assert_success

  # Setup again to test updates
  run trk setup
  assert_success

  run git config --local filter.crypt.clean
  assert_success
}
