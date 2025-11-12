#!/usr/bin/env bats

# Tests for trk init command

load test_helper

# Tests for init_normal

@test "init_normal: creates a new repository" {
  run trk init
  assert_success
  assert_dir_exists ".git"

  assert_base_configuration
  assert_permission_configured
  assert_encryption_configured
  refute_is_global_repository
}

@test "init_normal: creates repository in specified directory" {
  run trk init test-repo
  assert_success
  assert_dir_exists "test-repo/.git"
}

@test "init_normal: preserve git options" {
  run trk init --quiet test-repo
  assert_success
  refute_output "Initialized empty Git repository in"
  assert_dir_exists "test-repo/.git"
}

@test "init_normal: preserve git options, only before path" {
  run trk init test-repo --quiet
  assert_failure

  assert_output --partial "ERROR: Directory not found after git init"
}

@test "init_normal: --without-encryption skips encryption setup" {
  run trk init --without-encryption
  assert_success

  refute_encryption_configured
}

@test "init_normal: --without-permissions skips permissions setup" {
  run trk init --without-permissions
  assert_success

  refute_permission_configured
}

# Tests for init_global

@test "init_global: --worktree creates global repository" {
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  run trk init --worktree "$worktree"
  assert_success
  assert_output --partial  "Initializing repository with worktree $worktree"

  assert_base_configuration
  assert_permission_configured
  assert_encryption_configured
  assert_is_global_repository
}

@test "init_global: --worktree with non-existent path fails" {
  run trk init --worktree "/nonexistent/path"
  assert_failure
}

@test "init_global: passes through git init options" {
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"

  run trk init --worktree "$worktree" --quiet
  assert_success
  assert_is_global_repository
  refute_output "Initialized empty Git repository in"
}

@test "init_global: with --key-file works" {
  local worktree="$TEST_DIR/my-worktree"
  mkdir -p "$worktree"
  git-crypt keygen my-key

  run trk init --worktree "$worktree" --key-file my-key
  assert_success
  assert_is_global_repository
  assert_encryption_configured

  diff my-key "$(trk rev-parse --absolute-git-dir)/git-crypt/keys/default"
}
