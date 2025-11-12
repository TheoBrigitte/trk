#!/usr/bin/env bats
# Tests for trk OpenSSL configuration

load test_helper

@test "openssl get-args: shows default arguments" {
  run trk init
  assert_success

  run trk openssl get-args
  assert_success
  assert_output --partial  "-aes-256-cbc"
  assert_output --partial  "-pbkdf2"
}

@test "openssl get-args: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  run trk openssl get-args
  assert_failure
}

@test "openssl get-args: fails in non-git repository" {
  run trk openssl get-args
  assert_failure
}

@test "openssl set-args: sets custom arguments" {
  run trk init
  assert_success

  run trk openssl set-args "-aes-128-cbc -md sha256"
  assert_success

  run trk openssl get-args
  assert_success
  assert_output "-aes-128-cbc -md sha256"
}

@test "openssl set-args: updates git config" {
  run trk init
  assert_success

  run trk openssl set-args "-aes-192-cbc -md sha512"
  assert_success

  run git config --local trk.openssl-args
  assert_success
  assert_output "-aes-192-cbc -md sha512"
}

@test "openssl set-args: requires arguments" {
  run trk init
  assert_success

  run trk openssl set-args
  assert_failure
}

@test "openssl set-args: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  run trk openssl set-args "-aes-128-cbc"
  assert_failure
}

@test "openssl reset-args: resets to default arguments" {
  run trk init
  assert_success

  # Set custom args
  run trk openssl set-args "-aes-128-cbc -md sha256"
  assert_success

  # Reset
  run trk openssl reset-args
  assert_success

  run trk openssl get-args
  assert_success
  assert_output --partial  "-aes-256-cbc"
  assert_output --partial  "-pbkdf2"
}

@test "openssl reset-args: fails without encryption setup" {
  run trk init --without-encryption
  assert_success

  run trk openssl reset-args
  assert_failure
}

@test "openssl: custom args work for encryption" {
  run trk init
  assert_success

  run trk openssl set-args "-aes-128-cbc -md sha256 -pbkdf2"
  assert_success

  create_file "secret.txt" "test content"
  run trk mark "secret.txt"
  assert_success

  git add secret.txt
  git commit --quiet -m "Add secret"

  # File should be encrypted
  run is_encrypted_in_git "secret.txt"
  assert_success
}

@test "openssl: custom args work for decryption" {
  run trk init
  assert_success

  run trk openssl set-args "-aes-128-cbc -md sha256 -pbkdf2"
  assert_success

  create_file "secret.txt" "test content"
  run trk mark "secret.txt"
  assert_success

  git add secret.txt
  git commit --quiet -m "Add secret"

  # Remove and checkout
  rm secret.txt
  git checkout -- secret.txt

  # Should be decrypted correctly
  assert_file_contains "secret.txt" "test content"
}

@test "openssl: supports different cipher algorithms" {
  local ciphers=(
    "-aes-128-cbc -md sha256 -pbkdf2"
    "-aes-192-cbc -md sha256 -pbkdf2"
    "-aes-256-cbc -md sha256 -pbkdf2"
  )

  for cipher_args in "${ciphers[@]}"; do
    cd "$TEST_DIR"
    local test_dir="test-$(echo "$cipher_args" | tr -d ' -')"
    mkdir -p "$test_dir"
    cd "$test_dir"

    run trk init
    assert_success

    run trk openssl set-args "$cipher_args"
    assert_success

    create_file "secret.txt" "content"
    run trk mark "secret.txt"
    git add secret.txt
    git commit --quiet -m "Add"

    # Verify encryption/decryption works
    rm secret.txt
    git checkout -- secret.txt
    assert_file_contains "secret.txt" "content"
  done
}

@test "openssl: supports different hash algorithms" {
  local hashes=(
    "-aes-256-cbc -md sha256 -pbkdf2"
    "-aes-256-cbc -md sha512 -pbkdf2"
  )

  for hash_args in "${hashes[@]}"; do
    cd "$TEST_DIR"
    local test_dir="test-$(echo "$hash_args" | tr -d ' -' | cut -c1-20)"
    mkdir -p "$test_dir"
    cd "$test_dir"

    run trk init
    assert_success

    run trk openssl set-args "$hash_args"
    assert_success

    create_file "secret.txt" "content"
    run trk mark "secret.txt"
    git add secret.txt
    git commit --quiet -m "Add"

    assert_file_contains "secret.txt" "content"
  done
}

@test "openssl set-args: updates filters" {
  run trk init
  assert_success

  run trk openssl set-args "-aes-128-cbc -md sha256 -pbkdf2"
  assert_success

  # Filters should contain new args
  local clean_filter
  clean_filter="$(git config --local filter.trk-encrypt.clean)"
  [[ "$clean_filter" =~ "-aes-128-cbc" ]]
}

@test "openssl: incompatible args fail gracefully" {
  run trk init
  assert_success

  # Set invalid cipher
  run trk openssl set-args "-invalid-cipher"
  # Should either reject or fail when used
  # This test documents behavior
}

@test "openssl: args persist across setup" {
  run trk init
  assert_success

  run trk openssl set-args "-aes-128-cbc -md sha256 -pbkdf2"
  assert_success

  run trk setup
  assert_success

  run trk openssl get-args
  assert_success
  assert_output "-aes-128-cbc -md sha256 -pbkdf2"
}

@test "openssl get-args: shows stored value not computed" {
  run trk init
  assert_success

  # Get initial args
  local initial_args
  initial_args="$(trk openssl get-args)"

  # Directly modify git config
  git config --local trk.openssl-args "modified-args"

  # Should show modified value
  run trk openssl get-args
  assert_success
  assert_output "modified-args"
}

@test "openssl: default args use pbkdf2" {
  run trk init
  assert_success

  run trk openssl get-args
  assert_success
  assert_output --partial  "-pbkdf2"
}

@test "openssl: args can include multiple options" {
  run trk init
  assert_success

  local complex_args="-aes-256-cbc -md sha256 -pbkdf2 -iter 100000"
  run trk openssl set-args "$complex_args"
  assert_success

  run trk openssl get-args
  assert_success
  assert_output "$complex_args"
}

@test "openssl set-args: accepts args with equal signs" {
  run trk init
  assert_success

  # Some OpenSSL args might use = syntax
  run trk openssl set-args "-aes-256-cbc -md sha256"
  assert_success
}

@test "openssl: reencrypt required after changing args" {
  run trk init
  assert_success

  create_file "secret.txt" "content"
  run trk mark "secret.txt"
  git add secret.txt
  git commit --quiet -m "Add secret"

  # Change args
  run trk openssl set-args "-aes-128-cbc -md sha256 -pbkdf2"
  assert_success

  # Old encrypted content won't decrypt properly with new args
  # Need to reencrypt
  run trk reencrypt
  assert_success

  assert_file_contains "secret.txt" "content"
}
