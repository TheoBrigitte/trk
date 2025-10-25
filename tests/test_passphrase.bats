#!/usr/bin/env bats
# Tests for trk passphrase management

load test_helper

@test "passphrase get: retrieves passphrase" {
  run trk init
  assert_success

  run trk passphrase get
  assert_success
  [[ -n "$output" ]]
}

@test "passphrase get: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  run trk passphrase get
  assert_failure
}

@test "passphrase get: fails in non-git repository" {
  run trk passphrase get
  assert_failure
}

@test "passphrase generate: creates new passphrase" {
  run trk init
  assert_success

  local old_passphrase
  old_passphrase="$(trk passphrase get)"

  run trk passphrase generate --force
  assert_success

  local new_passphrase
  new_passphrase="$(trk passphrase get)"

  # Passphrase should be different
  [[ "$old_passphrase" != "$new_passphrase" ]]
}

@test "passphrase generate: generates sufficiently long passphrase" {
  run trk init
  assert_success

  run trk passphrase generate --force
  assert_success

  local passphrase
  passphrase="$(trk passphrase get)"

  # Should be at least 32 characters
  [[ ${#passphrase} -ge 32 ]]
}

@test "passphrase generate: generates base64 passphrase" {
  run trk init
  assert_success

  run trk passphrase generate --force
  assert_success

  local passphrase
  passphrase="$(trk passphrase get)"

  # Should contain base64 characters only
  [[ "$passphrase" =~ ^[A-Za-z0-9+/=]+$ ]]
}

@test "passphrase generate: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  run trk passphrase generate
  assert_failure
}

@test "passphrase import: imports passphrase from file" {
  run trk init
  assert_success

  local passphrase_file="$TEST_DIR/passphrase.txt"
  echo "imported-passphrase-12345" > "$passphrase_file"

  run trk passphrase import --force "$passphrase_file"
  assert_success

  local passphrase
  passphrase="$(trk passphrase get)"
  [[ "$passphrase" == "imported-passphrase-12345" ]]
}

@test "passphrase import: trims whitespace from imported passphrase" {
  run trk init
  assert_success

  local passphrase_file="$TEST_DIR/passphrase.txt"
  echo "  passphrase-with-spaces  " > "$passphrase_file"

  run trk passphrase import --force "$passphrase_file"
  assert_success

  local passphrase
  passphrase="$(trk passphrase get)"
  [[ "$passphrase" == "passphrase-with-spaces" ]]
}

@test "passphrase import: requires file argument" {
  run trk init
  assert_success

  run trk passphrase import
  assert_failure
}

@test "passphrase import: fails with nonexistent file" {
  run trk init
  assert_success

  run trk passphrase import "/nonexistent/file"
  assert_failure
}

@test "passphrase import: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  local passphrase_file="$TEST_DIR/passphrase.txt"
  echo "test-passphrase" > "$passphrase_file"

  run trk passphrase import "$passphrase_file"
  assert_failure
}

@test "passphrase import: handles empty file" {
  run trk init
  assert_success

  local passphrase_file="$TEST_DIR/passphrase.txt"
  touch "$passphrase_file"

  run trk passphrase import "$passphrase_file"
  # Should fail or handle gracefully
  assert_failure
}

@test "passphrase: works across clone" {
  # Create source repository
  run trk init
  assert_success

  local passphrase
  passphrase="$(trk passphrase get)"

  create_file "secret.txt" "secret content"
  run trk mark "secret.txt"
  git add .
  git commit --quiet -m "Add secret"

  # Create bare remote
  local remote
  remote="$(create_remote_repo test-remote)"
  git remote add origin "$remote"
  git push --quiet origin main

  # Clone with same passphrase
  cd "$TEST_DIR"
  git clone --quiet "$remote" clone-test
  cd clone-test

  run trk setup
  assert_success

  git config --local trk.passphrase "$passphrase"

  # Should be able to read the secret
  assert_file_contains "secret.txt" "secret content"
}

@test "passphrase: wrong passphrase fails decryption" {
  run trk init
  assert_success

  create_file "secret.txt" "secret content"
  run trk mark "secret.txt"
  git add secret.txt
  git commit --quiet -m "Add secret"

  # Change passphrase to wrong value
  git config --local trk.passphrase "wrong-passphrase"

  # Remove and try to checkout
  rm secret.txt
  run git checkout -- secret.txt

  # File should not contain correct content
  local content
  content="$(cat secret.txt)"
  [[ "$content" != "secret content" ]]
}

@test "passphrase generate: stores in git config" {
  run trk init
  assert_success

  run trk passphrase generate
  assert_success

  run git config --local trk.passphrase
  assert_success
  [[ -n "$output" ]]
}

@test "passphrase: respects existing passphrase on setup" {
  init_test_repo
  git config --local trk.passphrase "existing-passphrase"

  run trk setup
  assert_success

  local passphrase
  passphrase="$(trk passphrase get)"
  [[ "$passphrase" == "existing-passphrase" ]]
}

@test "passphrase: generates unique passphrases" {
  run trk init
  assert_success
  local pass1
  pass1="$(trk passphrase get)"

  cd "$TEST_DIR"
  mkdir repo2
  cd repo2
  run trk init
  assert_success
  local pass2
  pass2="$(trk passphrase get)"

  [[ "$pass1" != "$pass2" ]]
}

@test "passphrase import: handles multiline file" {
  run trk init
  assert_success

  local passphrase_file="$TEST_DIR/passphrase.txt"
  cat > "$passphrase_file" <<EOF
first-line
second-line
third-line
EOF

  run trk passphrase import "$passphrase_file"
  assert_success

  # Should only import first line
  local passphrase
  passphrase="$(trk passphrase get)"
  [[ "$passphrase" == "first-line" ]]
}

@test "passphrase: supports special characters" {
  run trk init
  assert_success

  local special_pass="p@ssw0rd!#\$%&*()-_=+[]{}|;:',.<>?/~\`"
  git config --local trk.passphrase "$special_pass"

  local retrieved_pass
  retrieved_pass="$(trk passphrase get)"
  [[ "$retrieved_pass" == "$special_pass" ]]
}

@test "passphrase import: reads from stdin with dash" {
  skip "stdin test - requires interactive testing"
}
