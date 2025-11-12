#!/usr/bin/env bats
# Integration tests for trk

load test_helper

@test "integration: full workflow - init, mark, commit, checkout" {
  run trk init
  assert_success

  create_file "public.txt" "public data"
  create_file "secret.txt" "secret password"

  run trk mark "secret.txt"
  assert_success

  git add .
  git commit --quiet -m "Initial commit"

  # Verify secret is encrypted in git
  run is_encrypted_in_git "secret.txt"
  assert_success

  # Verify public file is not encrypted
  local sha
  sha="$(git ls-files -s public.txt | awk '{print $2}')"
  local content
  content="$(git cat-file -p "$sha")"
  [[ "$content" == "public data" ]]

  # Remove files and checkout
  rm public.txt secret.txt
  git checkout -- public.txt secret.txt

  # Verify content is restored
  assert_file_contains "public.txt" "public data"
  assert_file_contains "secret.txt" "secret password"
}

@test "integration: clone repository with encrypted files" {
  # Create source repository
  run trk init
  assert_success

  create_file "secret.txt" "my secret"
  run trk mark "secret.txt"
  git add .
  git commit --quiet -m "Add secret"

  local passphrase
  passphrase="$(trk passphrase get)"

  # Create remote
  local remote
  remote="$(create_remote_repo test-remote)"
  git remote add origin "$remote"
  git push --quiet origin main

  # Clone
  cd "$TEST_DIR"
  git clone --quiet "$remote" cloned
  cd cloned

  run trk setup
  assert_success

  git config --local trk.passphrase "$passphrase"

  # Should decrypt correctly
  assert_file_contains "secret.txt" "my secret"
}

@test "integration: global repository workflow" {
  local worktree="$TEST_DIR/home"
  mkdir -p "$worktree"

  run trk init --worktree "$worktree"
  assert_success

  export GIT_DIR="$HOME/.local/share/trk/repo.git"

  # Add files to worktree
  create_file "$worktree/.bashrc" "export PATH=/usr/local/bin:$PATH"
  create_file "$worktree/.ssh/config" "Host github.com\n  User git"

  # Mark ssh config as encrypted
  cd "$worktree"
  run trk mark ".ssh/config"
  assert_success

  trk add .bashrc .ssh/config
  trk commit --quiet -m "Add dotfiles"

  # Verify encryption
  cd "$worktree"
  run is_encrypted_in_git ".ssh/config"
  assert_success

  # Verify .bashrc is not encrypted
  local sha
  sha="$(trk ls-files -s .bashrc | awk '{print $2}')"
  local content
  content="$(trk cat-file -p "$sha")"
  [[ "$content" =~ "PATH" ]]
}

@test "integration: reencrypt after changing passphrase" {
  run trk init
  assert_success

  create_file "secret1.txt" "password1"
  create_file "secret2.txt" "password2"
  run trk mark "secret1.txt"
  run trk mark "secret2.txt"

  git add .
  git commit --quiet -m "Add secrets"

  # Change passphrase
  git config --local trk.passphrase "new-passphrase-123"

  # Reencrypt
  run trk reencrypt
  assert_success

  # Verify files still readable
  assert_file_contains "secret1.txt" "password1"
  assert_file_contains "secret2.txt" "password2"

  # Verify encrypted in git
  run is_encrypted_in_git "secret1.txt"
  assert_success
  run is_encrypted_in_git "secret2.txt"
  assert_success
}

@test "integration: permissions workflow" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash\necho hello"
  chmod 755 "script.sh"
  create_file "data.txt" "data"
  chmod 644 "data.txt"

  git add .
  git commit --quiet -m "Add files"

  run trk permissions refresh
  assert_success

  git add .gitpermissions
  git commit --quiet -m "Track permissions"

  # Simulate permissions change
  chmod 644 script.sh
  chmod 777 data.txt

  run trk permissions apply
  assert_success

  local script_perm data_perm
  script_perm=$(stat -c "%a" "script.sh")
  data_perm=$(stat -c "%a" "data.txt")
  [[ "$script_perm" == "755" ]]
  [[ "$data_perm" == "644" ]]
}

@test "integration: config export and import" {
  run trk init --with-permissions
  assert_success

  # Customize configuration
  run trk openssl set-args "-aes-128-cbc -md sha256 -pbkdf2"
  assert_success

  # Export config
  local config_file="$TEST_DIR/exported.config"
  trk config export > "$config_file"

  # Create new repository
  cd "$TEST_DIR"
  mkdir new-repo
  cd new-repo

  run trk init --without-encryption --without-permissions
  assert_success

  # Import config
  run trk config import "$config_file"
  assert_success

  # Verify configuration matches
  run trk openssl get-args
  assert_success
  assert_output "-aes-128-cbc -md sha256 -pbkdf2"

  run git config --local trk.permissions
  assert_success
  assert_output "true"
}

@test "integration: multiple encrypted patterns" {
  run trk init
  assert_success

  create_file "passwords.txt" "secret1"
  create_file "api.key" "secret2"
  create_file "config.ini" "[database]\npassword=secret3"
  create_file "readme.txt" "public"

  run trk mark "*.key"
  run trk mark "passwords.txt"
  run trk mark "*.ini"

  git add .
  git commit --quiet -m "Add files"

  # Verify encrypted files
  run is_encrypted_in_git "passwords.txt"
  assert_success
  run is_encrypted_in_git "api.key"
  assert_success
  run is_encrypted_in_git "config.ini"
  assert_success

  # Verify public file not encrypted
  local sha
  sha="$(git ls-files -s readme.txt | awk '{print $2}')"
  local content
  content="$(git cat-file -p "$sha")"
  [[ "$content" == "public" ]]
}

@test "integration: setup existing repository with encrypted files" {
  # Create regular git repo with committed files
  init_test_repo
  create_file "secret.txt" "password"
  git add secret.txt
  git commit --quiet -m "Add secret"

  # Setup trk
  run trk setup
  assert_success

  # Mark file for encryption
  run trk mark "secret.txt"
  assert_success

  git add .gitattributes
  git commit --quiet -m "Mark secret for encryption"

  # Reencrypt
  run trk reencrypt
  assert_success

  # File should now be encrypted
  run is_encrypted_in_git "secret.txt"
  assert_success
}

@test "integration: unsetup and re-setup" {
  run trk init
  assert_success

  create_file "secret.txt" "password"
  run trk mark "secret.txt"
  git add .
  git commit --quiet -m "Add"

  local passphrase
  passphrase="$(trk passphrase get)"

  # Unsetup
  run trk unsetup
  assert_success

  # Files still encrypted in git
  run is_encrypted_in_git "secret.txt"
  assert_success

  # Re-setup with same passphrase
  run trk setup
  assert_success
  git config --local trk.passphrase "$passphrase"

  # Should still work
  rm secret.txt
  git checkout -- secret.txt
  assert_file_contains "secret.txt" "password"
}

@test "integration: worktree command shows information" {
  run trk init
  assert_success

  run trk worktree
  assert_success
  assert_output --partial  "worktree:"
  assert_output --partial  "gitdir:"
}

@test "integration: version command shows versions" {
  run trk version
  assert_success
  assert_output --partial  "trk version"
  assert_output --partial  "Git version"
  assert_output --partial  "OpenSSL version"
}

@test "integration: help command shows usage" {
  run trk help
  assert_success
  assert_output --partial  "Usage:"
  assert_output --partial  "Commands:"
}

@test "integration: git commands work through trk" {
  run trk init
  assert_success

  create_file "test.txt" "content"
  run trk add test.txt
  assert_success

  run trk commit -m "Test commit"
  assert_success

  run trk log --oneline
  assert_success
  assert_output --partial  "Test commit"

  run trk status
  assert_success
}

@test "integration: branch workflow with encrypted files" {
  run trk init
  assert_success

  create_file "secret.txt" "main-secret"
  run trk mark "secret.txt"
  git add .
  git commit --quiet -m "Initial"

  # Create branch with different content
  git checkout -b feature
  create_file "secret.txt" "feature-secret"
  git add secret.txt
  git commit --quiet -m "Update secret"

  # Switch branches and verify
  git checkout main
  assert_file_contains "secret.txt" "main-secret"

  git checkout feature
  assert_file_contains "secret.txt" "feature-secret"
}

@test "integration: nested directory encryption" {
  run trk init
  assert_success

  mkdir -p "secrets/api/keys"
  create_file "secrets/api/keys/production.key" "prod-key"
  create_file "secrets/api/keys/development.key" "dev-key"
  create_file "public/readme.txt" "public"

  run trk mark "secrets/**"
  assert_success

  git add .
  git commit --quiet -m "Add files"

  run is_encrypted_in_git "secrets/api/keys/production.key"
  assert_success
  run is_encrypted_in_git "secrets/api/keys/development.key"
  assert_success
}

@test "integration: large repository with many encrypted files" {
  run trk init
  assert_success

  # Create 50 encrypted files
  for i in {1..50}; do
    create_file "secret-$i.txt" "secret-$i"
    run trk mark "secret-$i.txt"
  done

  git add .
  git commit --quiet -m "Add many secrets"

  # Verify a sample
  run is_encrypted_in_git "secret-1.txt"
  assert_success
  run is_encrypted_in_git "secret-25.txt"
  assert_success
  run is_encrypted_in_git "secret-50.txt"
  assert_success

  # List all encrypted
  run trk list encrypted
  assert_success
  assert_output --partial  "secret-1.txt"
  assert_output --partial  "secret-50.txt"
}
