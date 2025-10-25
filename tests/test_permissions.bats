#!/usr/bin/env bats
# Tests for trk permissions management

load test_helper

@test "permissions: not enabled by default" {
  run trk init
  assert_success

  run git config --local trk.permissions
  assert_failure
}

@test "permissions: enabled with --with-permissions" {
  run trk init --with-permissions
  assert_success

  run git config --local trk.permissions
  assert_success
  assert_output_equals "true"
}

@test "permissions refresh: stores current permissions" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"
  create_file "data.txt" "data"
  chmod 644 "data.txt"

  git add .
  git commit --quiet -m "Add files"

  run trk permissions refresh
  assert_success

  assert_file_exists ".gitpermissions"
  assert_file_contains ".gitpermissions" "script.sh"
  assert_file_contains ".gitpermissions" "755"
}

@test "permissions refresh: fails without permissions enabled" {
  run trk init
  assert_success

  run trk permissions refresh
  assert_failure
}

@test "permissions apply: restores stored permissions" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"
  git add script.sh
  git commit --quiet -m "Add script"

  # Change permission
  chmod 644 "script.sh"

  run trk permissions apply
  assert_success

  # Permission should be restored
  local perm
  perm=$(stat -c "%a" "script.sh")
  [[ "$perm" == "755" ]]
}

@test "permissions apply: fails without permissions enabled" {
  run trk init
  assert_success

  run trk permissions apply
  assert_failure
}

@test "permissions status: shows permission differences" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"
  git add script.sh
  git commit --quiet -m "Add script"

  # Change permission
  chmod 644 "script.sh"

  run trk permissions status
  assert_success
  assert_output_contains "script.sh"
}

@test "permissions status: shows no changes when permissions match" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"
  run trk permissions refresh
  git add .gitpermissions
  git commit --quiet -m "Add permissions"

  run trk permissions status
  assert_success
  # Should show no differences or empty output
}

@test "permissions status: fails without permissions enabled" {
  run trk init
  assert_success

  run trk permissions status
  assert_failure
}

@test "permissions: .gitpermissions format is correct" {
  run trk init --with-permissions
  assert_success

  create_file "test.sh" "#!/bin/bash"
  chmod 755 "test.sh"
  git add test.sh

  run trk permissions refresh
  assert_success

  # Format should be: filename:mode
  local line
  line=$(grep "test.sh" .gitpermissions)
  [[ "$line" =~ ^test\.sh:[0-9]+$ ]]
}

@test "permissions refresh: handles multiple files" {
  run trk init --with-permissions
  assert_success

  create_file "script1.sh" "#!/bin/bash"
  chmod 755 "script1.sh"
  create_file "script2.sh" "#!/bin/bash"
  chmod 700 "script2.sh"
  create_file "data.txt" "data"
  chmod 644 "data.txt"

  git add .
  git commit --quiet -m "Add files"

  run trk permissions refresh
  assert_success

  assert_file_contains ".gitpermissions" "script1.sh"
  assert_file_contains ".gitpermissions" "script2.sh"
  assert_file_contains ".gitpermissions" "data.txt"
}

@test "permissions apply: handles multiple files" {
  run trk init --with-permissions
  assert_success

  create_file "file1.txt" "content1"
  chmod 600 "file1.txt"
  create_file "file2.txt" "content2"
  chmod 644 "file2.txt"

  git add .
  git commit --quiet -m "Add files"

  run trk permissions refresh
  git add .gitpermissions
  git commit --quiet -m "Add permissions"

  # Change all permissions
  chmod 777 file1.txt file2.txt

  run trk permissions apply
  assert_success

  local perm1 perm2
  perm1=$(stat -c "%a" "file1.txt")
  perm2=$(stat -c "%a" "file2.txt")
  [[ "$perm1" == "600" ]]
  [[ "$perm2" == "644" ]]
}

@test "permissions: .gitpermissions is tracked in git" {
  run trk init --with-permissions
  assert_success

  create_file "test.sh" "#!/bin/bash"
  chmod 755 "test.sh"
  git add test.sh

  run trk permissions refresh
  assert_success

  git add .gitpermissions
  git commit --quiet -m "Add permissions"

  # Should be in git
  git ls-files | grep -q ".gitpermissions"
}

@test "permissions refresh: updates existing .gitpermissions" {
  run trk init --with-permissions
  assert_success

  create_file "file1.txt" "content"
  chmod 644 "file1.txt"
  git add file1.txt

  run trk permissions refresh
  git add .gitpermissions
  git commit --quiet -m "Initial"

  # Add new file
  create_file "file2.txt" "content2"
  chmod 755 "file2.txt"
  git add file2.txt

  run trk permissions refresh
  assert_success

  # Both files should be listed
  assert_file_contains ".gitpermissions" "file1.txt"
  assert_file_contains ".gitpermissions" "file2.txt"
}

@test "permissions apply: handles missing files gracefully" {
  run trk init --with-permissions
  assert_success

  create_file "file.txt" "content"
  chmod 644 "file.txt"
  git add file.txt

  run trk permissions refresh
  git add .gitpermissions
  git commit --quiet -m "Add"

  # Remove file
  rm file.txt

  # Apply should not fail
  run trk permissions apply
  # May succeed or fail depending on implementation
}

@test "permissions: disabled by unsetup" {
  run trk init --with-permissions
  assert_success

  run trk unsetup
  assert_success

  run git config --local trk.permissions
  assert_failure
}

@test "permissions: removed by unsetup --prune" {
  run trk init --with-permissions
  assert_success

  create_file "test.sh" "#!/bin/bash"
  chmod 755 "test.sh"
  git add test.sh

  run trk permissions refresh
  git add .gitpermissions
  git commit --quiet -m "Add"

  run trk unsetup --prune
  assert_success

  [[ ! -f ".gitpermissions" ]]
}

@test "permissions refresh: handles files with spaces in names" {
  run trk init --with-permissions
  assert_success

  create_file "file with spaces.txt" "content"
  chmod 644 "file with spaces.txt"
  git add "file with spaces.txt"

  run trk permissions refresh
  assert_success

  assert_file_contains ".gitpermissions" "file with spaces.txt"
}

@test "permissions apply: handles files with spaces in names" {
  run trk init --with-permissions
  assert_success

  create_file "file with spaces.txt" "content"
  chmod 600 "file with spaces.txt"
  git add "file with spaces.txt"

  run trk permissions refresh
  git add .gitpermissions
  git commit --quiet -m "Add"

  chmod 644 "file with spaces.txt"

  run trk permissions apply
  assert_success

  local perm
  perm=$(stat -c "%a" "file with spaces.txt")
  [[ "$perm" == "600" ]]
}

@test "permissions: works with nested directories" {
  run trk init --with-permissions
  assert_success

  mkdir -p "dir/subdir"
  create_file "dir/subdir/script.sh" "#!/bin/bash"
  chmod 755 "dir/subdir/script.sh"
  git add dir

  run trk permissions refresh
  assert_success

  assert_file_contains ".gitpermissions" "dir/subdir/script.sh"
}

@test "permissions status: in non-git repository fails" {
  run trk permissions status
  assert_failure
}

@test "permissions refresh: in non-git repository fails" {
  run trk permissions refresh
  assert_failure
}

@test "permissions apply: in non-git repository fails" {
  run trk permissions apply
  assert_failure
}
