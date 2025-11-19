#!/usr/bin/env bats
# Tests for trk permissions management

load test_helper

@test "permissions refresh: stores current permissions using getfacl for marked files" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"
  create_file "data.txt" "data"
  chmod 644 "data.txt"

  # Mark files for permission tracking
  run trk permissions mark "script.sh"
  assert_success
  run trk permissions mark "data.txt"
  assert_success

  git add .
  git commit --quiet -m "Add files"

  assert_file_exists ".trk/permissions"
  # Should contain ACL format entries for script.sh (755)
  assert_file_contains ".trk/permissions" "# file: script.sh"
  assert_file_contains ".trk/permissions" "user::rwx"
  assert_file_contains ".trk/permissions" "group::r-x"
  assert_file_contains ".trk/permissions" "other::r-x"
  # Should contain ACL format entries for data.txt (644)
  assert_file_contains ".trk/permissions" "# file: data.txt"
  assert_file_contains ".trk/permissions" "user::rw-"
  assert_file_contains ".trk/permissions" "group::r--"
  assert_file_contains ".trk/permissions" "other::r--"
}

@test "permissions refresh: succeeds with no permissions list" {
  run trk init --without-permissions
  assert_success

  create_file "test.txt" "content"
  git add test.txt
  git commit -m "test"

  run trk permissions refresh
  assert_success
  assert_output --partial "No permissions are being tracked"
}

@test "permissions apply: restores stored permissions using setfacl" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"

  run trk permissions mark "script.sh"
  assert_success

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

@test "permissions apply: succeeds with no permissions file" {
  run trk init --without-permissions
  assert_success

  create_file "test.txt" "content"
  chmod 755 "test.txt"
  git add test.txt
  git commit -m "test"

  run trk permissions apply
  assert_success
  assert_output --partial "No permissions found"
}

@test "permissions status: shows permission differences" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"

  run trk permissions mark "script.sh"
  assert_success

  git add script.sh
  git commit --quiet -m "Add script"

  # Change permission
  chmod 644 "script.sh"

  run trk permissions status
  assert_output --partial "script.sh"
}

@test "permissions status: shows no changes when permissions match" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"

  run trk permissions mark "script.sh"
  assert_success

  git add script.sh
  git commit --quiet -m "Add script"

  # Verify .trk/permissions was created
  [[ -f ".trk/permissions" ]]

  run trk permissions status
  assert_success
  refute_output
}

@test "permissions status: succeeds with no permissions file" {
  run trk init
  assert_success

  run trk permissions status
  assert_success
  refute_output
}

@test "permissions: .trk/permissions format is correct" {
  run trk init --with-permissions
  assert_success

  create_file "test.sh" "#!/bin/bash"
  chmod 755 "test.sh"

  run trk permissions mark "test.sh"
  assert_success

  git add test.sh

  run trk permissions refresh
  assert_success

  # Format should be getfacl format: # file: filename followed by ACL entries
  assert_file_contains ".trk/permissions" "# file: test.sh"
  assert_file_contains ".trk/permissions" "user::rwx"
  assert_file_contains ".trk/permissions" "group::r-x"
  assert_file_contains ".trk/permissions" "other::r-x"
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

  # Mark all files for tracking
  run trk permissions mark "script1.sh"
  assert_success
  run trk permissions mark "script2.sh"
  assert_success
  run trk permissions mark "data.txt"
  assert_success

  git add .
  git commit --quiet -m "Add files"

  # Check ACL format for all files
  assert_file_contains ".trk/permissions" "# file: script1.sh"
  assert_file_contains ".trk/permissions" "user::rwx"
  assert_file_contains ".trk/permissions" "group::r-x"
  assert_file_contains ".trk/permissions" "other::r-x"

  assert_file_contains ".trk/permissions" "# file: script2.sh"
  assert_file_contains ".trk/permissions" "user::rwx"
  assert_file_contains ".trk/permissions" "group::---"
  assert_file_contains ".trk/permissions" "other::---"

  assert_file_contains ".trk/permissions" "# file: data.txt"
  assert_file_contains ".trk/permissions" "user::rw-"
  assert_file_contains ".trk/permissions" "group::r--"
  assert_file_contains ".trk/permissions" "other::r--"
}

@test "permissions apply: handles multiple files" {
  run trk init --with-permissions
  assert_success

  create_file "file1.txt" "content1"
  chmod 600 "file1.txt"
  create_file "file2.txt" "content2"
  chmod 644 "file2.txt"

  run trk permissions mark "file1.txt"
  assert_success
  run trk permissions mark "file2.txt"
  assert_success

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

@test "permissions: .trk/permissions is tracked in git" {
  run trk init --with-permissions
  assert_success

  create_file "test.sh" "#!/bin/bash"
  chmod 755 "test.sh"

  run trk permissions mark "test.sh"
  assert_success

  git add test.sh

  git commit --quiet -m "Add permissions"

  # Should be in git
  git ls-files | grep -q ".trk/permissions"
}

@test "permissions refresh: updates existing .trk/permissions" {
  run trk init --with-permissions
  assert_success

  create_file "file1.txt" "content"
  chmod 644 "file1.txt"

  run trk permissions mark "file1.txt"
  assert_success

  git add file1.txt

  git commit --quiet -m "Initial"

  # Add new file
  create_file "file2.txt" "content2"
  chmod 755 "file2.txt"

  run trk permissions mark "file2.txt"
  assert_success

  git add file2.txt

  run trk permissions refresh
  assert_success

  # Both files should be listed
  assert_file_contains ".trk/permissions" "file1.txt"
  assert_file_contains ".trk/permissions" "file2.txt"
}

@test "permissions apply: handles missing files gracefully" {
  run trk init --with-permissions
  assert_success

  create_file "file1.txt" "content"
  chmod 644 "file1.txt"
  create_file "file2.txt" "content"
  chmod 644 "file2.txt"

  run trk permissions mark "file1.txt"
  run trk permissions mark "file2.txt"
  assert_success

  git add file1.txt file2.txt
  git commit --quiet -m "Add"

  # Remove file1
  rm file1.txt
  chmod 755 file2.txt

  # Apply should not fail
  run trk permissions apply
  assert_failure

  local perm
  perm=$(stat -c "%a" "file2.txt")
  [[ "$perm" == "644" ]]
}

@test "permissions: disabled by unsetup" {
  run trk init --with-permissions
  assert_success

  run trk unsetup
  assert_success

  run git config --local trk.permissions
  assert_failure
}

@test "permissions: .trk/permissions persists after unsetup" {
  run trk init --with-permissions
  assert_success

  create_file "test.sh" "#!/bin/bash"
  chmod 755 "test.sh"

  run trk permissions mark "test.sh"
  assert_success

  git add test.sh

  run trk permissions refresh
  git add .trk/permissions
  git commit --quiet -m "Add"

  run trk unsetup
  assert_success

  # .trk/permissions file should still exist (it's tracked in git)
  [[ -f ".trk/permissions" ]]
}

@test "permissions refresh: handles files with spaces in names" {
  run trk init --with-permissions
  assert_success

  # Create initial commit first
  create_file "initial.txt" "initial"
  git add initial.txt
  git commit --quiet -m "Initial commit"

  create_file "file with spaces.txt" "content"
  chmod 644 "file with spaces.txt"

  run trk permissions mark "file with spaces.txt"
  assert_success

  git add "file with spaces.txt"

  run trk permissions refresh
  assert_success

  # getfacl keeps spaces as-is in the filename
  assert_file_contains ".trk/permissions" "# file: file with spaces.txt"
  assert_file_contains ".trk/permissions" "user::rw-"
  assert_file_contains ".trk/permissions" "group::r--"
  assert_file_contains ".trk/permissions" "other::r--"
}

@test "permissions apply: handles files with spaces in names" {
  run trk init --with-permissions
  assert_success

  # Create initial commit first
  create_file "initial.txt" "initial"
  git add initial.txt
  git commit --quiet -m "Initial commit"

  create_file "file with spaces.txt" "content"
  chmod 600 "file with spaces.txt"

  run trk permissions mark "file with spaces.txt"
  assert_success

  git add "file with spaces.txt"
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

  run trk permissions mark "dir/subdir/script.sh"
  assert_success

  git add dir

  run trk permissions refresh
  assert_success

  assert_file_contains ".trk/permissions" "# file: dir/subdir/script.sh"
  assert_file_contains ".trk/permissions" "user::rwx"
  assert_file_contains ".trk/permissions" "group::r-x"
  assert_file_contains ".trk/permissions" "other::r-x"
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

  # Mark all files for tracking
  run trk permissions mark "file1.txt"
  assert_success
  run trk permissions mark "file2.txt"
  assert_success
  run trk permissions mark "file3.txt"
  assert_success

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

  run trk permissions mark "script.sh"
  assert_success

  git add script.sh
  git commit --quiet -m "Initial commit"

  # Create a new branch with different permissions
  git checkout -b test-branch --quiet
  chmod 700 "script.sh"
  # Also change the file content to trigger the hook
  echo "# modified" >> "script.sh"
  git add .trk/permissions script.sh
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

  run trk permissions mark "file.txt"
  assert_success

  git add file.txt
  git commit --quiet -m "Main branch"

  # Feature branch with 600
  git checkout -b feature --quiet
  chmod 600 "file.txt"
  # Also change the file content to trigger the hook
  echo "modified" >> "file.txt"
  git add .trk/permissions file.txt
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

@test "permissions mark: adds file to tracking list" {
  run trk init --with-permissions
  assert_success

  create_file "script.sh" "#!/bin/bash"
  chmod 755 "script.sh"

  run trk permissions mark "script.sh"
  assert_success

  # File should be in tracking list
  assert_file_exists ".trk/permissions_list"
  assert_file_contains ".trk/permissions_list" "script.sh"
}

@test "permissions mark: prevents duplicate entries" {
  run trk init --with-permissions
  assert_success

  create_file "file.txt" "content"

  run trk permissions mark "file.txt"
  assert_success

  run trk permissions mark "file.txt"
  assert_success
  assert_output --partial "already marked"

  # Should only appear once
  local count
  count=$(grep -c "^file.txt$" ".trk/permissions_list")
  [[ "$count" == "1" ]]
}

@test "permissions mark: handles relative paths" {
  run trk init --with-permissions
  assert_success

  mkdir subdir
  cd subdir
  create_file "file.txt" "content"

  # Mark with relative path
  run trk permissions mark "file.txt"
  assert_success

  cd -
  # Should be stored as relative path
  grep -qx "subdir/file.txt" ".trk/permissions_list"
}

@test "permissions mark: marks directory recursively" {
  run trk init --with-permissions
  assert_success

  mkdir -p "bin"
  create_file "bin/script1.sh" "#!/bin/bash"
  create_file "bin/script2.sh" "#!/bin/bash"

  run trk permissions mark "bin"
  assert_success

  # Directory should be in tracking list
  grep -qx "bin" ".trk/permissions_list"
}

@test "permissions mark: fails for non-existent file" {
  run trk init --with-permissions
  assert_success

  run trk permissions mark "nonexistent.txt"
  assert_failure
}

@test "permissions mark: stages permissions_list file" {
  run trk init --with-permissions
  assert_success

  create_file "file.txt" "content"

  run trk permissions mark "file.txt"
  assert_success

  # File should be staged
  git diff --cached --name-only | grep -q ".trk/permissions_list"
}

@test "permissions unmark: removes file from tracking list" {
  run trk init --with-permissions
  assert_success

  create_file "file.txt" "content"

  run trk permissions mark "file.txt"
  assert_success

  run trk permissions unmark "file.txt"
  assert_success

  # File should not be in tracking list
  if [[ -f ".trk/permissions_list" ]]; then
    ! grep -q "^file.txt$" ".trk/permissions_list"
  fi
}

@test "permissions unmark: handles non-marked files" {
  run trk init --with-permissions
  assert_success

  create_file "file.txt" "content"
  create_file "other.txt" "other"

  # Mark one file to create permissions_list
  run trk permissions mark "other.txt"
  assert_success

  # Try to unmark a different file
  run trk permissions unmark "file.txt"
  assert_output --partial "not marked"
}

@test "permissions unmark: stages permissions_list file" {
  run trk init --with-permissions
  assert_success

  create_file "file.txt" "content"

  run trk permissions mark "file.txt"
  assert_success
  git commit --quiet -m "Mark file"

  run trk permissions unmark "file.txt"
  assert_success

  # File should be staged
  git diff --cached --name-only | grep -q ".trk/permissions_list"
}

@test "permissions list: shows marked files" {
  run trk init --with-permissions
  assert_success

  create_file "file1.txt" "content1"
  create_file "file2.txt" "content2"

  run trk permissions mark "file1.txt"
  assert_success
  run trk permissions mark "file2.txt"
  assert_success

  run trk permissions list
  assert_success
  assert_output --partial "file1.txt"
  assert_output --partial "file2.txt"
}

@test "permissions list: shows nothing when no files marked" {
  run trk init --with-permissions
  assert_success

  run trk permissions list
  assert_output --partial "No permissions are being tracked"
}

@test "permissions list: shows error when permissions_list missing" {
  run trk init --with-permissions
  assert_success

  run trk permissions list
  assert_output --partial "No permissions are being tracked"
}

@test "permissions: only marked files are tracked" {
  run trk init --with-permissions
  assert_success

  create_file "tracked.sh" "#!/bin/bash"
  chmod 755 "tracked.sh"
  create_file "untracked.sh" "#!/bin/bash"
  chmod 755 "untracked.sh"

  # Only mark one file
  run trk permissions mark "tracked.sh"
  assert_success

  git add .
  git commit --quiet -m "Add files"

  # Only tracked file should be in permissions with complete ACL entries
  assert_file_contains ".trk/permissions" "# file: tracked.sh"
  assert_file_contains ".trk/permissions" "user::rwx"
  assert_file_contains ".trk/permissions" "group::r-x"
  assert_file_contains ".trk/permissions" "other::r-x"
  # Untracked file should not be in permissions
  ! grep -q "untracked.sh" ".trk/permissions"
}

@test "permissions mark: child path already tracked by parent" {
  run trk init --with-permissions
  assert_success

  mkdir -p "dir"
  create_file "dir/file.txt" "content"

  # Mark directory
  run trk permissions mark "dir"
  assert_success

  # Try to mark child file
  run trk permissions mark "dir/file.txt"
  assert_output --partial "already marked"
}

@test "permissions refresh: only updates when tracked files change" {
  run trk init --with-permissions
  assert_success

  create_file "tracked.txt" "content"
  create_file "untracked.txt" "content"

  run trk permissions mark "tracked.txt"
  assert_success

  git add .
  git commit --quiet -m "Initial"

  # Store initial permissions file content
  local initial_perms
  initial_perms=$(cat .trk/permissions)

  # Modify untracked file
  echo "modified" > "untracked.txt"
  git add untracked.txt
  git commit --quiet -m "Modify untracked"

  # Permissions file should not have changed
  [[ "$(cat .trk/permissions)" == "$initial_perms" ]]
}
