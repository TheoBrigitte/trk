#!/usr/bin/env bats
# Tests for trk setup and unsetup commands

load test_helper

@test "setup: configures existing git repository" {
  init_test_repo

  run trk setup
  assert_success

  assert_base_configuration
  assert_encryption_configured
  refute_is_global_repository
}

@test "setup: --without-encryption skips encryption setup" {
  init_test_repo

  run trk setup --without-encryption
  assert_success

  refute_encryption_configured
}

@test "setup: --with-permissions adds permissions setup" {
  init_test_repo

  run trk setup --with-permissions
  assert_success

  assert_permission_configured
}

@test "setup: with --key-file imports encryption key" {
  init_test_repo

  git-crypt keygen my-key

  run trk setup --key-file my-key
  assert_success

  assert_success
  assert_base_configuration
  assert_encryption_configured

  diff my-key "$(trk rev-parse --absolute-git-dir)/git-crypt/keys/default"
}

@test "setup: fails in non-git repository" {
  run trk setup
  assert_failure
}

@test "unsetup: disables trk management" {
  init_test_repo
  run trk setup
  assert_success

  run trk unsetup
  assert_success

  refute_permission_configured
}

@test "unsetup: can be run on unmanaged repository" {
  init_test_repo

  run trk unsetup
  assert_success
}

@test "setup: reconfigure preserves encryption key" {
  init_test_repo
  run trk setup
  assert_success

  sha256sum .git/git-crypt/keys/default > key.sha256sum

  run trk unsetup
  assert_success

  run trk setup
  assert_success

  assert_base_configuration
  assert_encryption_configured
  refute_is_global_repository

  sha256sum -c key.sha256sum
}

@test "setup: reconfigure with --key-file replaces encryption key" {
  init_test_repo
  run trk setup
  assert_success

  sha256sum .git/git-crypt/keys/default > key.sha256sum

  run trk unsetup
  assert_success

  git-crypt keygen new-key
  run trk setup --key-file new-key
  assert_success

  assert_base_configuration
  assert_encryption_configured
  refute_is_global_repository

  ! sha256sum -c key.sha256sum
}
