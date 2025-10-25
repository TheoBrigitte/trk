#!/usr/bin/env bats
# Tests for trk clone command

load test_helper

@test "clone: clones a repository" {
  local remote
  remote="$(create_remote_repo test-remote)"

  # Create a commit in the remote
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  run trk clone "$remote"
  assert_success

  local repo_name="test-remote"
  assert_dir_exists "$repo_name/.git"
  assert_file_exists "$repo_name/README.md"
}

@test "clone: clones a repository with non-humanish URL" {
  local remote="$TEST_DIR/remotes/test-remote/.git"
  mkdir -p "$remote"
  git -C "$remote" init --bare --quiet

  # Create a commit in the remote
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  run trk clone "$remote"
  assert_success

  local repo_name="test-remote"
  assert_dir_exists "$repo_name/.git"
  assert_file_exists "$repo_name/README.md"
}

@test "clone: clones a repository with directory" {
  local remote
  remote="$(create_remote_repo test-remote)"

  # Create a commit in the remote
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  local repo_name="some-dir"
  run trk clone "$remote" "$repo_name"
  assert_success

  assert_dir_exists "$repo_name/.git"
  assert_file_exists "$repo_name/README.md"
}

@test "clone: clones checks out files correctly" {
  local remote
  remote="$(create_remote_repo test-remote)"

  # Create a commit in the remote
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  run trk clone "$remote"
  assert_success

  local repo_name="test-remote"
  assert_dir_exists "$repo_name/.git"
  assert_file_exists "$repo_name/README.md"

  cd "$repo_name"
  git diff HEAD --quiet
}


@test "clone: sets up trk configuration" {
  local remote
  remote="$(create_remote_repo test-remote)"

  # Create initial commit
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  run trk clone "$remote"
  assert_success

  cd test-remote
  run git config --local trk.managed
  assert_success
  assert_output_equals "true"
}

@test "clone: generates encryption passphrase" {
  local remote
  remote="$(create_remote_repo test-remote)"

  # Create initial commit
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  run trk clone "$remote"
  assert_success

  cd test-remote
  run git config --local trk.passphrase
  assert_success
  [[ -n "$output" ]]
}

@test "clone: --worktree creates global repository" {
  local remote
  remote="$(create_remote_repo test-remote)"
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  # Create initial commit
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  run trk clone --worktree "$worktree" "$remote"
  assert_success

  local share_dir="$HOME/.local/share/trk/repo.git"
  assert_dir_exists "$share_dir"
}

@test "clone: --worktree checks out files to worktree" {
  local remote
  remote="$(create_remote_repo test-remote)"
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  # Create initial commit
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  run trk clone --worktree "$worktree" "$remote"
  assert_success

  assert_file_exists "$worktree/README.md"
}

@test "clone: --worktree detects local changes" {
  local remote
  remote="$(create_remote_repo test-remote)"
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  # Create initial commit in remote
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  # Create a conflicting local file
  create_file "$worktree/README.md" "# Local content"

  cd "$TEST_DIR"
  run trk clone --worktree "$worktree" "$remote"
  assert_failure
  assert_output_contains "Local files differ from the cloned repository. Review and apply the changes manually."
}

@test "clone: with --config-file imports configuration" {
  local remote
  remote="$(create_remote_repo test-remote)"

  # Create initial commit
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  # Create a config file
  local config_file="$TEST_DIR/trk.config"
  cat > "$config_file" <<EOF
trk.openssl-args -aes-128-cbc -md sha256
EOF

  cd "$TEST_DIR"
  run trk clone --config-file "$config_file" "$remote"
  assert_success

  cd test-remote
  run git config --local trk.openssl-args
  assert_success
  assert_output_equals "-aes-128-cbc -md sha256"
}

@test "clone: passes through git clone options" {
  local remote
  remote="$(create_remote_repo test-remote)"

  # Create initial commit with a branch
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main
  git checkout -b develop
  create_file "DEV.md" "# Development"
  git add DEV.md
  git commit --quiet -m "Add development file"
  git push --quiet origin develop

  cd "$TEST_DIR"
  run trk clone --branch develop "$remote"
  assert_success

  cd test-remote
  local branch
  branch="$(git branch --show-current)"
  [[ "$branch" == "develop" ]]
  assert_file_exists "DEV.md"
}

@test "clone: creates git hooks with --with-permissions" {
  local remote
  remote="$(create_remote_repo test-remote)"

  # Create initial commit
  local temp_clone="$TEST_DIR/temp-clone"
  git clone --quiet "$remote" "$temp_clone"
  cd "$temp_clone"
  create_file "README.md" "# Test"
  git add README.md
  git commit --quiet -m "Initial commit"
  git push --quiet origin main

  cd "$TEST_DIR"
  run trk clone --with-permissions "$remote"
  assert_success

  cd test-remote
  assert_file_exists ".git/hooks/pre-commit"
  assert_file_exists ".git/hooks/post-checkout"
}

@test "clone: fails with invalid remote" {
  run trk clone "file:///nonexistent/repo.git"
  assert_failure
}

@test "clone: requires repository URL" {
  run trk clone
  assert_failure
}
