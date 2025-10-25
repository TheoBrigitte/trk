# trk Test Suite

Comprehensive test suite for the trk project using the Bats (Bash Automated Testing System) framework.

## Prerequisites

Install Bats:

```bash
# Using npm
npm install -g bats

# Or on Arch Linux
sudo pacman -S bats

# Or from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## Running Tests

### Run all tests
```bash
make test
```

### Run specific test suites
```bash
make test-init          # Init command tests
make test-clone         # Clone command tests
make test-setup         # Setup/unsetup tests
make test-encryption    # Encryption tests
make test-passphrase    # Passphrase management tests
make test-openssl       # OpenSSL configuration tests
make test-permissions   # Permissions management tests
make test-config        # Config export/import tests
make test-integration   # Integration tests
```

### Run individual test files
```bash
bats tests/test_init.bats
bats tests/test_encryption.bats
```

### Run specific tests
```bash
bats tests/test_init.bats --filter "init: creates a new repository"
```

## Test Structure

```
tests/
├── README.md                  # This file
├── test_helper.bash           # Common test utilities and setup/teardown
├── test_init.bats            # Init command tests (25 tests)
├── test_clone.bats           # Clone command tests (16 tests)
├── test_setup.bats           # Setup/unsetup tests (21 tests)
├── test_encryption.bats      # Encryption tests (33 tests)
├── test_passphrase.bats      # Passphrase management tests (19 tests)
├── test_openssl.bats         # OpenSSL configuration tests (23 tests)
├── test_config.bats          # Config export/import tests (32 tests)
├── test_permissions.bats     # Permissions tests (28 tests)
└── test_integration.bats     # Integration tests (22 tests)
```

**Total: 219+ test cases**

## Test Coverage

### Core Commands
- ✅ `init` - Repository initialization (normal and global)
- ✅ `clone` - Repository cloning (normal and global)
- ✅ `setup` - Configure existing repository
- ✅ `unsetup` - Remove trk configuration

### Encryption Features
- ✅ `mark` - Mark files/patterns for encryption
- ✅ `unmark` - Remove encryption marks
- ✅ `list encrypted` - List encrypted files
- ✅ `reencrypt` - Re-encrypt all marked files

### Passphrase Management
- ✅ `passphrase get` - Retrieve passphrase
- ✅ `passphrase generate` - Generate new passphrase
- ✅ `passphrase import` - Import passphrase from file

### OpenSSL Configuration
- ✅ `openssl get-args` - Get OpenSSL arguments
- ✅ `openssl set-args` - Set custom OpenSSL arguments
- ✅ `openssl reset-args` - Reset to defaults

### Permissions Management
- ✅ `permissions refresh` - Store file permissions
- ✅ `permissions apply` - Restore permissions
- ✅ `permissions status` - Check permission differences

### Configuration
- ✅ `config export` - Export trk configuration
- ✅ `config import` - Import configuration from file

### Integration Tests
- ✅ Full encryption workflow
- ✅ Global repository workflow
- ✅ Clone with encrypted files
- ✅ Permissions workflow
- ✅ Config export/import workflow
- ✅ Multiple encrypted patterns
- ✅ Branch workflows
- ✅ Large repository handling

## Test Helper Functions

Located in `test_helper.bash`:

### Setup/Teardown
- `setup()` - Creates isolated test environment
- `teardown()` - Cleans up test artifacts

### Assertions
- `assert_success()` - Command succeeded
- `assert_failure()` - Command failed
- `assert_output_contains()` - Output contains string
- `assert_output_equals()` - Output matches exactly
- `assert_file_exists()` - File exists
- `assert_dir_exists()` - Directory exists
- `assert_file_contains()` - File contains string
- `assert_git_config()` - Git config value matches

### Utilities
- `create_file()` - Create file with content
- `create_remote_repo()` - Create bare git remote
- `init_test_repo()` - Initialize test repository
- `is_encrypted_in_git()` - Check if file is encrypted in git
- `wait_for_file()` - Wait for file to exist
- `debug_info()` - Print debug information

## Writing New Tests

Example test structure:

```bash
#!/usr/bin/env bats
# Tests for <feature>

load test_helper

@test "<feature>: <description>" {
  # Setup
  run trk init
  assert_success

  # Action
  run trk <command>

  # Assertions
  assert_success
  assert_output_contains "expected"
}
```

## CI/CD Integration

Tests can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run tests
  run: make test
```

## Notes

- Tests run in isolated temporary directories
- Each test gets a clean git configuration
- Tests use real git and OpenSSL binaries
- No mocking - tests validate actual behavior
- Tests are independent and can run in any order

## Debugging Tests

To debug a failing test:

```bash
# Run with verbose output
bats tests/test_init.bats --tap

# Add debug_info() calls in your test
@test "something" {
  debug_info
  run trk init
  debug_info
}
```

## Known Limitations

- Some tests marked with `skip` require interactive testing
- Tests assume Linux environment (uses `stat -c`)
- Requires git, openssl, and standard Unix tools
