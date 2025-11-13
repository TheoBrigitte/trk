#!/usr/bin/env bats
# Tests for trk encryption (mark, unmark, list encrypted, reencrypt)

load test_helper

@test "commit: encrypts file when committed" {
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

  # File is shown in clear in working directory
  assert_file_contains "secret.txt" "my secret password"

  # crypt status should show the file
  run trk crypt status
  assert_output --partial "encrypted: secret.txt"
}

@test "mark: marks a file for encryption" {
  run trk init
  assert_success

  run trk mark "secret.txt"
  assert_success

  assert_file_contains ".gitattributes" "secret.txt filter=git-crypt diff=git-crypt"
}

@test "mark: marks a pattern for encryption" {
  run trk init
  assert_success

  run trk mark "*.key"
  assert_success

  assert_file_contains ".gitattributes" "*.key filter=git-crypt diff=git-crypt"
}

@test "mark: marks multiple files" {
  run trk init
  assert_success

  run trk mark "file1.txt"
  assert_success

  run trk mark "file2.txt"
  assert_success

  assert_file_contains ".gitattributes" "file1.txt filter=git-crypt diff=git-crypt"
  assert_file_contains ".gitattributes" "file2.txt filter=git-crypt diff=git-crypt"
}

@test "mark: marks file with spaces" {
  run trk init
  assert_success

  run trk mark "file with spaces.txt"
  assert_success

  assert_file_contains ".gitattributes" "file[[:space:]]with[[:space:]]spaces.txt filter=git-crypt diff=git-crypt"
}

@test "mark: works with nested paths" {
  run trk init
  assert_success

  run trk mark "secrets/passwords.txt"
  assert_success

  assert_file_contains ".gitattributes" "secrets/passwords.txt filter=git-crypt diff=git-crypt"
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
  assert_output --partial "Encryption is not enabled in this repository"
}

@test "unmark: removes encryption mark from file" {
  run trk init
  assert_success

  run trk mark "secret.txt"
  assert_success

  run trk unmark "secret.txt"
  assert_success

  # Check that the specific line is removed
  ! grep -Fq "secret.txt" .gitattributes
}

@test "unmark: removes pattern from .gitattributes" {
  run trk init
  assert_success

  run trk mark "*.key"
  assert_success

  run trk unmark "*.key"
  assert_success

  ! grep -Fq "*.key" .gitattributes
}

@test "unmark: handles file not marked" {
  run trk init
  assert_success

  run trk unmark "notmarked.txt"
  # Should succeed even if file wasn't marked
  assert_success
}

@test "crypt status: shows empty list when nothing marked" {
  run trk init
  assert_success

  # Creating an empty file to have the repository initialized with HEAD
  create_file "secret.txt" "my secret password"
  git add secret.txt
  git commit --quiet -m "Add secret"

  run trk crypt status
  assert_success
  refute_output
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
  dd if=/dev/urandom of=large.txt bs=1M count=1 2>/dev/null

  run trk mark "large.txt"
  assert_success

  git add large.txt
  git commit --quiet -m "Add large file"

  run is_encrypted_in_git "large.txt"
  assert_success
}

@test "encryption: different keys produce different ciphertext" {
  # First repository
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
  cd ..

  # Second repository with different passphrase
  local repo2="$TEST_DIR/repo2"
  mkdir -p "$repo2"
  cd "$repo2"

  run trk init
  assert_success
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
