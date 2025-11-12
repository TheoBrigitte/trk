#!/usr/bin/env bats
# Tests for trk encryption (mark, unmark, list encrypted, reencrypt)

load test_helper

@test "mark: marks a file for encryption" {
  run trk init
  assert_success

  run trk mark "secret.txt"
  assert_success

  assert_file_contains ".gitattributes" "secret.txt"
  assert_file_contains ".gitattributes" "filter=crypt"
}

@test "mark: marks a pattern for encryption" {
  run trk init
  assert_success

  run trk mark "*.key"
  assert_success

  assert_file_contains ".gitattributes" "*.key"
}

@test "mark: marks multiple files" {
  run trk init
  assert_success

  run trk mark "file1.txt"
  assert_success

  run trk mark "file2.txt"
  assert_success

  assert_file_contains ".gitattributes" "file1.txt"
  assert_file_contains ".gitattributes" "file2.txt"
}

@test "mark: works with nested paths" {
  run trk init
  assert_success

  run trk mark "secrets/passwords.txt"
  assert_success

  assert_file_contains ".gitattributes" "secrets/passwords.txt"
}

@test "mark: encrypts file when committed" {
  run trk init
  assert_success

  create_file "secret.txt" "my secret password"
  run trk mark "secret.txt"
  assert_success

  git add secret.txt
  git commit --quiet -m "Add secret"

  # File should be encrypted in git
  run is_encrypted_in_git "secret.txt"
  assert_success
}

@test "mark: decrypts file when checked out" {
  run trk init
  assert_success

  create_file "secret.txt" "my secret password"
  run trk mark "secret.txt"
  assert_success

  git add secret.txt
  git commit --quiet -m "Add secret"

  # Remove file and checkout again
  rm secret.txt
  git checkout -- secret.txt

  # File should be decrypted
  assert_file_contains "secret.txt" "my secret password"
}

@test "mark: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  run trk mark "secret.txt"
  assert_failure
}

@test "unmark: removes encryption mark from file" {
  run trk init
  assert_success

  run trk mark "secret.txt"
  assert_success

  run trk unmark "secret.txt"
  assert_success

  # Check that the specific line is removed
  if [[ -f .gitattributes ]]; then
    ! grep -q "^secret.txt.*filter=crypt" .gitattributes
  fi
}

@test "unmark: removes pattern from .gitattributes" {
  run trk init
  assert_success

  run trk mark "*.key"
  assert_success

  run trk unmark "*.key"
  assert_success

  if [[ -f .gitattributes ]]; then
    ! grep -q "^\*.key.*filter=crypt" .gitattributes
  fi
}

@test "unmark: handles file not marked" {
  run trk init
  assert_success

  run trk unmark "notmarked.txt"
  # Should succeed even if file wasn't marked
  assert_success
}

@test "list encrypted: shows all marked files and patterns" {
  run trk init
  assert_success

  run trk mark "secret.txt"
  run trk mark "*.key"
  run trk mark "passwords.txt"

  run trk list encrypted
  assert_success
  assert_output --partial  "secret.txt"
  assert_output --partial  "*.key"
  assert_output --partial  "passwords.txt"
}

@test "list encrypted: shows empty list when nothing marked" {
  run trk init
  assert_success

  run trk list encrypted
  assert_success
}

@test "list encrypted: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  run trk list encrypted
  assert_failure
}

@test "reencrypt: reencrypts all marked files" {
  run trk init
  assert_success

  # Create and mark files
  create_file "secret1.txt" "password1"
  create_file "secret2.txt" "password2"
  run trk mark "secret1.txt"
  run trk mark "secret2.txt"

  git add .
  git commit --quiet -m "Add secrets"

  # Change passphrase
  local new_passphrase="new-passphrase-$(date +%s)"
  git config --local trk.passphrase "$new_passphrase"

  run trk reencrypt
  assert_success

  # Files should still be readable
  assert_file_contains "secret1.txt" "password1"
  assert_file_contains "secret2.txt" "password2"

  # Files should be encrypted with new passphrase in git
  run is_encrypted_in_git "secret1.txt"
  assert_success
  run is_encrypted_in_git "secret2.txt"
  assert_success
}

@test "reencrypt: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  run trk reencrypt
  assert_failure
}

@test "reencrypt: handles repository with no encrypted files" {
  run trk init
  assert_success

  run trk reencrypt
  assert_success
}

@test "mark: with diff attribute sets diff and filter" {
  run trk init
  assert_success

  run trk mark "secret.txt"
  assert_success

  assert_file_contains ".gitattributes" "diff=crypt"
  assert_file_contains ".gitattributes" "filter=crypt"
}

@test "mark: with merge attribute sets merge" {
  run trk init
  assert_success

  run trk mark "secret.txt"
  assert_success

  assert_file_contains ".gitattributes" "merge=crypt"
}

@test "encryption: preserves file content through commit cycle" {
  run trk init
  assert_success

  local original_content="This is my secret password: 12345"
  create_file "secret.txt" "$original_content"
  run trk mark "secret.txt"
  assert_success

  git add secret.txt
  git commit --quiet -m "Add secret"

  # Read back the file
  local content
  content="$(cat secret.txt)"
  [[ "$content" == "$original_content" ]]
}

@test "encryption: handles binary files" {
  run trk init
  assert_success

  # Create a small binary file
  dd if=/dev/urandom of=binary.dat bs=1024 count=1 2>/dev/null

  run trk mark "binary.dat"
  assert_success

  git add binary.dat
  git commit --quiet -m "Add binary"

  # File should be encrypted in git
  run is_encrypted_in_git "binary.dat"
  assert_success
}

@test "encryption: handles empty files" {
  run trk init
  assert_success

  touch empty.txt
  run trk mark "empty.txt"
  assert_success

  git add empty.txt
  git commit --quiet -m "Add empty file"

  # File should be tracked
  git ls-files | grep -q "empty.txt"
}

@test "encryption: handles large files" {
  run trk init
  assert_success

  # Create a 1MB file
  dd if=/dev/zero of=large.txt bs=1M count=1 2>/dev/null

  run trk mark "large.txt"
  assert_success

  git add large.txt
  git commit --quiet -m "Add large file"

  run is_encrypted_in_git "large.txt"
  assert_success
}

@test "encryption: different passphrases produce different ciphertext" {
  # First repository
  run trk init
  assert_success
  local repo1="$TEST_DIR/repo1"
  mkdir -p "$repo1"
  cd "$repo1"

  run trk init
  assert_success
  create_file "secret.txt" "same content"
  run trk mark "secret.txt"
  git add secret.txt
  git commit --quiet -m "Add secret"
  local hash1
  hash1="$(git ls-files -s secret.txt | awk '{print $2}')"
  local content1
  content1="$(git cat-file -p "$hash1")"

  # Second repository with different passphrase
  cd "$TEST_DIR"
  local repo2="$TEST_DIR/repo2"
  mkdir -p "$repo2"
  cd "$repo2"

  run trk init
  assert_success
  git config --local trk.passphrase "different-passphrase"
  create_file "secret.txt" "same content"
  run trk mark "secret.txt"
  git add secret.txt
  git commit --quiet -m "Add secret"
  local hash2
  hash2="$(git ls-files -s secret.txt | awk '{print $2}')"
  local content2
  content2="$(git cat-file -p "$hash2")"

  # Ciphertext should be different
  [[ "$content1" != "$content2" ]]
}

@test "mark: fails in non-git repository" {
  run trk mark "file.txt"
  assert_failure
}

@test "unmark: fails in non-git repository" {
  run trk unmark "file.txt"
  assert_failure
}

@test "reencrypt: requires confirmation in interactive mode" {
  skip "Interactive test - requires manual testing"
}
