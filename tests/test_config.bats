#!/usr/bin/env bats
# Tests for trk config export/import

load test_helper

@test "config export: exports trk configuration" {
  run trk init
  assert_success

  run trk config export
  assert_success
  [[ -n "$output" ]]
}

@test "config export: includes passphrase" {
  run trk init
  assert_success

  run trk config export
  assert_success
  assert_output_contains "trk.passphrase"
}

@test "config export: includes openssl-args" {
  run trk init
  assert_success

  run trk config export
  assert_success
  assert_output_contains "trk.openssl-args"
}

@test "config export: includes managed flag" {
  run trk init
  assert_success

  run trk config export
  assert_success
  assert_output_contains "trk.managed"
}

@test "config export: includes permissions if enabled" {
  run trk init --with-permissions
  assert_success

  run trk config export
  assert_success
  assert_output_contains "trk.permissions"
}

@test "config export: outputs in key=value format" {
  run trk init
  assert_success

  run trk config export
  assert_success

  # Should be in format: trk.key=value or trk.key value (depending on git version)
  [[ "$output" =~ trk\. ]]
}

@test "config export: can be piped to file" {
  run trk init
  assert_success

  trk config export > exported.config
  assert_file_exists "exported.config"
  assert_file_contains "exported.config" "trk."
}

@test "config import: imports configuration from file" {
  run trk init
  assert_success

  local config_file="$TEST_DIR/import.config"
  cat > "$config_file" <<EOF
trk.passphrase imported-passphrase
trk.openssl-args -aes-128-cbc -md sha256
EOF

  cd "$TEST_DIR"
  mkdir new-repo
  cd new-repo
  run trk init --without-encryption
  assert_success

  run trk config import "$config_file"
  assert_success

  run git config --local trk.passphrase
  assert_success
  assert_output_equals "imported-passphrase"

  run git config --local trk.openssl-args
  assert_success
  assert_output_equals "-aes-128-cbc -md sha256"
}

@test "config import: requires file argument" {
  run trk init
  assert_success

  run trk config import
  assert_failure
}

@test "config import: fails with nonexistent file" {
  run trk init
  assert_success

  run trk config import "/nonexistent/config"
  assert_failure
}

@test "config import: handles empty file" {
  run trk init
  assert_success

  local config_file="$TEST_DIR/empty.config"
  touch "$config_file"

  run trk config import "$config_file"
  # Should succeed but not change anything
  assert_success
}

@test "config import: overwrites existing values" {
  run trk init
  assert_success

  local old_passphrase
  old_passphrase="$(git config --local trk.passphrase)"

  local config_file="$TEST_DIR/import.config"
  cat > "$config_file" <<EOF
trk.passphrase new-passphrase
EOF

  run trk config import "$config_file"
  assert_success

  local new_passphrase
  new_passphrase="$(git config --local trk.passphrase)"
  [[ "$new_passphrase" == "new-passphrase" ]]
  [[ "$new_passphrase" != "$old_passphrase" ]]
}

@test "config import: imports with space-separated format" {
  run trk init --without-encryption
  assert_success

  # Format: trk.key value
  local config_file="$TEST_DIR/config1"
  echo "trk.test1 value1" > "$config_file"

  run trk config import "$config_file"
  assert_success

  run git config --local trk.test1
  assert_success
  assert_output_equals "value1"
}

@test "config import: handles comments" {
  run trk init
  assert_success

  local config_file="$TEST_DIR/commented.config"
  cat > "$config_file" <<EOF
# This is a comment
trk.passphrase test-pass
# Another comment
EOF

  run trk config import "$config_file"
  assert_success

  run git config --local trk.passphrase
  assert_success
  assert_output_equals "test-pass"
}

@test "config import: handles blank lines" {
  run trk init
  assert_success

  local config_file="$TEST_DIR/blanks.config"
  cat > "$config_file" <<EOF

trk.passphrase test-pass

trk.openssl-args -aes-256-cbc

EOF

  run trk config import "$config_file"
  assert_success

  run git config --local trk.passphrase
  assert_success
}

@test "config export/import: round trip preserves configuration" {
  run trk init
  assert_success

  # Export config
  local export_file="$TEST_DIR/exported.config"
  trk config export > "$export_file"

  local original_passphrase
  original_passphrase="$(git config --local trk.passphrase)"

  # Create new repo and import
  cd "$TEST_DIR"
  mkdir new-repo
  cd new-repo
  run trk init --without-encryption
  assert_success

  run trk config import "$export_file"
  assert_success

  local imported_passphrase
  imported_passphrase="$(git config --local trk.passphrase)"
  [[ "$imported_passphrase" == "$original_passphrase" ]]
}

@test "config export: in non-git repository fails" {
  run trk config export
  assert_failure
}

@test "config import: in non-git repository fails" {
  local config_file="$TEST_DIR/test.config"
  echo "trk.test=value" > "$config_file"

  run trk config import "$config_file"
  assert_failure
}

@test "config import: handles values with spaces" {
  run trk init
  assert_success

  local config_file="$TEST_DIR/spaces.config"
  cat > "$config_file" <<EOF
trk.openssl-args=-aes-256-cbc -md sha256 -pbkdf2
EOF

  run trk config import "$config_file"
  assert_success

  run git config --local trk.openssl-args
  assert_success
  assert_output_equals "-aes-256-cbc -md sha256 -pbkdf2"
}

@test "config import: handles values with special characters" {
  run trk init
  assert_success

  local config_file="$TEST_DIR/special.config"
  cat > "$config_file" <<EOF
trk.passphrase p@ss!#\$%&*()_+-=
EOF

  run trk config import "$config_file"
  assert_success

  run git config --local trk.passphrase
  assert_success
  [[ "$output" =~ "@ss" ]]
}

@test "config export: only exports trk namespace" {
  run trk init
  assert_success

  # Add some non-trk config
  git config --local user.name "Test User"
  git config --local core.autocrlf false

  run trk config export
  assert_success

  # Should only contain trk.* config
  [[ ! "$output" =~ "user.name" ]]
  [[ ! "$output" =~ "core.autocrlf" ]]
}

@test "config import: only imports trk namespace" {
  run trk init
  assert_success

  local config_file="$TEST_DIR/mixed.config"
  cat > "$config_file" <<EOF
trk.passphrase test-pass
user.name Hacker
core.autocrlf true
EOF

  run trk config import "$config_file"
  assert_success

  # trk config should be imported
  run git config --local trk.passphrase
  assert_success

  # Non-trk config should not be imported
  run git config --local user.name
  [[ "$output" != "Hacker" ]]
}

@test "config import: validates configuration format" {
  run trk init
  assert_success

  local config_file="$TEST_DIR/invalid.config"
  cat > "$config_file" <<EOF
this is not valid config
trk.passphrase valid
more invalid stuff
EOF

  run trk config import "$config_file"
  # Should handle invalid lines gracefully
  assert_success

  # Valid line should still be imported
  run git config --local trk.passphrase
  assert_success
  assert_output_equals "valid"
}
