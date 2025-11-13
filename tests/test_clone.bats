#!/usr/bin/env bats
# Tests for trk clone command

load test_helper

@test "clone_normal: clones a repository" {
  create_remote_repo_with_file remote/test-remote README.md "# Test"

  run trk clone remote/test-remote
  assert_success

  assert_dir_exists test-remote/.git
  assert_file_exists test-remote/README.md

  cd test-remote
  assert_git_checkout_clean
  assert_base_configuration
  assert_permission_configured
  refute_is_global_repository
}

@test "clone_normal: clones a repository with non-humanish URL" {
  create_remote_repo_with_file remote/test-remote/.git README.md "# Test"

  run trk clone remote/test-remote/.git
  assert_success

  assert_dir_exists test-remote/.git
  assert_file_exists test-remote/README.md
  cd test-remote
  assert_git_checkout_clean
}

@test "clone_normal: clones a repository with directory" {
  create_remote_repo_with_file remote/test-remote README.md "# Test"

  run trk clone remote/test-remote some-dir
  assert_success

  assert_dir_exists some-dir/.git
  assert_file_exists some-dir/README.md
  cd some-dir
  assert_git_checkout_clean
}

@test "clone_normal: passes through git clone options" {
  local remote
  remote="test/test-remote"
  mkdir -p "$remote"
  git -C "$remote" init --bare --quiet
  git -C "$remote" worktree add --orphan -b develop work
  # Create initial README
  echo "# Development" > "$remote/work/README.md"
  git -C "$remote/work" add "README.md"
  git -C "$remote/work" commit --quiet -m "Initial dev commit"
  git -C "$remote/work" checkout -b main
  # Overwrite README in main branch
  echo "# Main" > "$remote/work/README.md"
  git -C "$remote/work" add "README.md"
  git -C "$remote/work" commit --quiet -m "Update README to Main"

  # Clone develop branch
  run trk clone --branch develop "$remote"
  assert_success

  cd test-remote
  local branch
  branch="$(git branch --show-current)"
  [[ "$branch" == "develop" ]]
  assert_file_exists "README.md"
  [[ "$(cat README.md)" == "# Development" ]]
}

@test "clone_global: --worktree creates global repository" {
  create_remote_repo_with_file remote/test-remote/.git README.md "# Test"

  mkdir my-worktree
  run trk clone --worktree my-worktree remote/test-remote
  assert_success

  assert_is_global_repository
  cd my-worktree
  assert_git_checkout_clean
}

@test "clone_global: --worktree detects local changes" {
  create_remote_repo_with_file remote/test-remote/.git README.md "# Test"

  mkdir -p my-worktree

  # Create a conflicting local file
  echo "# Local content" > my-worktree/README.md

  run trk clone --worktree my-worktree remote/test-remote
  assert_failure
  assert_output --partial  "Local files differ from the cloned repository. Review and apply the changes manually."
  cd my-worktree
  run trk diff
  assert_success
  assert_output --partial "diff --git a/README.md b/README.md"
  assert_output --partial "--- a/README.md"
  assert_output --partial "+++ b/README.md"
  assert_output --partial "-# Test"
  assert_output --partial "+# Local content"
}

@test "clone: --without-encryption skips encryption setup" {
  create_remote_repo_with_file remote/test-remote README.md "# Test"

  run trk clone remote/test-remote --without-encryption
  assert_success

  assert_dir_exists test-remote/.git
  assert_file_exists test-remote/README.md

  cd test-remote
  refute_encryption_configured
}

@test "clone: --without-permissions skips permissions setup" {
  create_remote_repo_with_file remote/test-remote README.md "# Test"

  run trk clone remote/test-remote --without-permissions
  assert_success

  assert_dir_exists test-remote/.git
  assert_file_exists test-remote/README.md

  cd test-remote
  refute_permission_configured
}

@test "clone: fails with invalid remote" {
  run trk clone "file:///nonexistent/repo.git"
  assert_failure
  assert_output --partial "fatal: '/nonexistent/repo.git' does not appear to be a git repository"
}

@test "clone: requires repository URL" {
  run trk clone
  assert_failure
  assert_output --partial "fatal: You must specify a repository to clone"
}
