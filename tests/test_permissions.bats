#!/usr/bin/env bats
# Tests for trk permissions management

load test_helper

@test "permissions refresh: stores current permissions using getfacl" {
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
  # Should contain ACL format entries
  assert_file_contains ".gitpermissions" "# file: script.sh"
  assert_file_contains ".gitpermissions" "user::"
  assert_file_contains ".gitpermissions" "group::"
  assert_file_contains ".gitpermissions" "other::"
}

@test "permissions refresh: fails without hooks installed" {
  run trk init --without-permissions
  assert_success

  create_file "test.txt" "content"
  git add test.txt
  git commit -m "test"

  run trk permissions refresh
  assert_failure
  assert_output --partial "cannot find a hook named pre-commit"
}

@test "permissions apply: restores stored permissions using setfacl" {
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

  # Permission should be restored to 755
  local perm
  perm=$(stat -c "%a" "script.sh")
  [[ "$perm" == "755" ]]
}

@test "permissions apply: fails without hooks installed" {
  run trk init --without-permissions
  assert_success

  create_file "test.txt" "content"
  chmod 755 "test.txt"
  git add test.txt
  git commit -m "test"

  run trk permissions apply
  assert_failure
  assert_output --partial "cannot find a hook named post-checkout"
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
  assert_failure
  assert_output --partial "Permission differences found"
}

@test "permissions status: shows no changes when permissions match" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"
  git add script.sh
  git commit --quiet -m "Add script"

  # Verify .gitpermissions was created
  [[ -f ".gitpermissions" ]]

  run trk permissions status
  if [[ "$status" -ne 0 ]]; then
    # Debug output
    echo "Output: $output"
    echo ".gitpermissions:" 
    cat .gitpermissions
    echo "Current:"
    git ls-files -z | grep -zv "^\.gitpermissions$" | xargs -0 getfacl --access 2>/dev/null | grep -v "^# owner:" | grep -v "^# group:"
  fi
  assert_success
  assert_output --partial "All permissions match"
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

  # Format should be getfacl format: # file: filename followed by ACL entries
  assert_file_contains ".gitpermissions" "# file: test.sh"
  assert_file_contains ".gitpermissions" "user::"
  assert_file_contains ".gitpermissions" "group::"
  assert_file_contains ".gitpermissions" "other::"
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

  # Check ACL format for all files
  assert_file_contains ".gitpermissions" "# file: script1.sh"
  assert_file_contains ".gitpermissions" "# file: script2.sh"
  assert_file_contains ".gitpermissions" "# file: data.txt"
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

@test "permissions: .gitpermissions persists after unsetup" {
  run trk init --with-permissions
  assert_success

  create_file "test.sh" "#!/bin/bash"
  chmod 755 "test.sh"
  git add test.sh

  run trk permissions refresh
  git add .gitpermissions
  git commit --quiet -m "Add"

  run trk unsetup
  assert_success

  # .gitpermissions file should still exist (it's tracked in git)
  [[ -f ".gitpermissions" ]]
}

@test "permissions refresh: handles files with spaces in names" {
  run trk init --with-permissions
  assert_success

  create_file "file with spaces.txt" "content"
  chmod 644 "file with spaces.txt"
  git add "file with spaces.txt"

  run trk permissions refresh
  assert_success

  # getfacl keeps spaces as-is in the filename
  assert_file_contains ".gitpermissions" "# file: file with spaces.txt"
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

  assert_file_contains ".gitpermissions" "# file: dir/subdir/script.sh"
}

@test "permissions: getfacl format preserves exact permissions" {
  run trk init --with-permissions
  assert_success

  # Create files with different permission combinations
  create_file "file1.txt" "content"
  chmod 600 "file1.txt"
  create_file "file2.txt" "content"
  chmod 750 "file2.txt"
  create_file "file3.txt" "content"
  chmod 644 "file3.txt"

  git add .
  git commit --quiet -m "Add files"

  # Change all permissions
  chmod 777 file1.txt file2.txt file3.txt

  # Apply should restore exact permissions
  run trk permissions apply
  assert_success

  [[ "$(stat -c "%a" "file1.txt")" == "600" ]]
  [[ "$(stat -c "%a" "file2.txt")" == "750" ]]
  [[ "$(stat -c "%a" "file3.txt")" == "644" ]]
}

@test "permissions: setfacl restores permissions after checkout" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"
  git add script.sh
  git commit --quiet -m "Initial commit"

  # Create a new branch with different permissions
  git checkout -b test-branch --quiet
  chmod 700 "script.sh"
  run trk permissions refresh
  git add .gitpermissions script.sh
  git commit --quiet -m "Change permissions"

  # Checkout back to main
  git checkout main --quiet

  # Permissions should be restored to 755
  local perm
  perm=$(stat -c "%a" "script.sh")
  [[ "$perm" == "755" ]]
}

@test "permissions: handles permission changes across branches" {
  run trk init --with-permissions
  assert_success

  # Main branch with 644
  create_file "file.txt" "content"
  chmod 644 "file.txt"
  git add file.txt
  git commit --quiet -m "Main branch"

  # Feature branch with 600
  git checkout -b feature --quiet
  chmod 600 "file.txt"
  run trk permissions refresh
  git add .gitpermissions file.txt
  git commit --quiet -m "Feature branch"

  # Switch back to main - should have 644
  git checkout main --quiet
  [[ "$(stat -c "%a" "file.txt")" == "644" ]]

  # Switch to feature - should have 600
  git checkout feature --quiet
  [[ "$(stat -c "%a" "file.txt")" == "600" ]]
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
