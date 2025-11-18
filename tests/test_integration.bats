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
  create_remote_repo remote/test-remote

  # Create source repository
  mkdir source
  cd source
  run trk init
  assert_success

  create_file "secret.txt" "my secret"
  run trk mark "secret.txt"
  assert_success
  git add "secret.txt"
  git commit --quiet -m "Add secret"

  # Create remote
  git remote add origin "../remote/test-remote"
  git push --quiet origin main
  run trk crypt export-key ../key
  assert_success
  cd ..

  # Clone
  run trk clone --quiet "remote/test-remote" target
  assert_success
  cd target

  # Secret is not yet decrypted
  ! grep -Fq "my secret" "secret.txt"

  run trk crypt unlock ../key
  assert_success

  # Should decrypt correctly
  assert_file_contains "secret.txt" "my secret"
}

@test "integration: global repository workflow" {
  local worktree="$TEST_DIR/home"
  mkdir -p "$worktree"

  run trk init --worktree "$worktree"
  assert_success

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
  run is_encrypted_in_git ".ssh/config"
  assert_success

  # Verify .bashrc is not encrypted
  local sha
  sha="$(trk ls-files -s .bashrc | awk '{print $2}')"
  local content
  content="$(trk cat-file -p "$sha")"
  [[ "$content" =~ "PATH" ]]
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

  # Mark files for permission tracking
  run trk permissions mark "script.sh"
  assert_success
  run trk permissions mark "data.txt"
  assert_success

  run trk permissions refresh
  assert_success

  git add .trk/permissions .trk/permissions_list
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

  git add .gitattributes secret.txt
  git commit --quiet -m "Mark and encrypt secret"

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

  # Export key before unsetup
  run trk crypt export-key "$TEST_DIR/key"
  assert_success

  # Unsetup
  run trk unsetup
  assert_success

  # Files still encrypted in git
  run is_encrypted_in_git "secret.txt"
  assert_success

  # Re-setup with same key
  run trk setup --key-file "$TEST_DIR/key"
  assert_success

  # Should still work
  rm secret.txt
  git checkout -- secret.txt
  assert_file_contains "secret.txt" "password"
}

@test "integration: worktree command shows information" {
  run trk init
  assert_success

  run trk info
  assert_success
  assert_output --partial  "worktree:"
  assert_output --partial  "gitdir:"
}

@test "integration: version command shows versions" {
  run trk version
  assert_success
  assert_output --partial  "trk version"
  assert_output --partial  "git version"
  assert_output --partial  "git-crypt"
}

@test "integration: help command shows usage" {
  run trk help
  assert_success
  assert_output --partial  "Usage:"
  assert_output --partial  "> Commands <"
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
  run trk crypt status
  assert_success
  assert_output --partial  "secret-1.txt"
  assert_output --partial  "secret-50.txt"
}

@test "integration: large repository with many permissions tracking" {
  run trk init --with-permissions
  assert_success

  # Create 50 files with various permissions
  for i in {1..50}; do
    create_file "file-$i.txt" "content-$i"
    if (( i % 3 == 0 )); then
      chmod 755 "file-$i.txt"
    elif (( i % 3 == 1 )); then
      chmod 644 "file-$i.txt"
    else
      chmod 600 "file-$i.txt"
    fi
    run trk permissions mark "file-$i.txt"
    assert_success
  done

  git add .
  git commit --quiet -m "Track all permissions"

  # Verify permissions list contains all files
  run trk permissions list
  assert_success
  assert_output --partial  "file-1.txt"
  assert_output --partial  "file-25.txt"
  assert_output --partial  "file-50.txt"

  # Change all permissions
  for i in {1..50}; do
    chmod 777 "file-$i.txt"
  done

  # Apply stored permissions
  run trk permissions apply
  assert_success

  # Verify a sample of permissions were restored correctly
  local perm1 perm2 perm3
  perm1=$(stat -c "%a" "file-1.txt")
  perm2=$(stat -c "%a" "file-3.txt")
  perm3=$(stat -c "%a" "file-2.txt")
  [[ "$perm1" == "644" ]]  # i % 3 == 1
  [[ "$perm2" == "755" ]]  # i % 3 == 0
  [[ "$perm3" == "600" ]]  # i % 3 == 2
}
