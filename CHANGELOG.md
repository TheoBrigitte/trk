# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- **BREAKING**: Migrated from OpenSSL-based encryption to git-crypt for file encryption
- Disabled permissions tracking by default
- Renamed `worktree` command to `info` command
- Updated encryption setup to use git-crypt instead of custom OpenSSL implementation
- Improved git-crypt integration with automatic repository configuration

### Added
- `migrate` command for migrating repositories to new encryption methods
- `permissions list` command to list tracked file permissions
- `key-file` support in setup command for git-crypt key management
- Git trace detection for worktree identification after clone and init operations
- Comprehensive test suite with BATS (Bash Automated Testing System)

### Fixed
- Mark command now fails appropriately when encryption is not configured
- Repository validation now checks for shared repositories only under specific conditions
- File existence validation removed from mark command for better workflow support
- Pre-commit hook now properly uses git diff and calls permissions refresh
- Permissions changes detection improved with better filtering
- GIT_DIR and GIT_ROOT environment variable handling
- Init command handling of unexpected git options after directory argument
- Global init now creates missing parent directories correctly

### Removed
- OpenSSL-based encryption system (replaced by git-crypt)
- Passphrase management commands (no longer needed with git-crypt)
- Custom merge driver for encrypted files (handled by git-crypt)
- `trk.permissions` configuration setting
- `--prune` option to avoid destructive operations
- `--force` flag removed everywhere to avoid destructive operations

## [0.1.0] - 2025-09-27

### Added

- File Encryption
  - File and pattern-based encryption marking with `mark`/`unmark` commands
  - Automatic encryption/decryption using git clean/smudge filters
  - OpenSSL-based AES-256-CBC encryption with PBKDF2 key derivation
  - Salt generation per file for secure encryption
  - List encrypted files with `list encrypted` command
  - Bulk re-encryption of all encrypted files with `reencrypt` command
  - Custom merge driver for handling encrypted file conflicts

- Core Git Integration
  - Git wrapper functionality that passes through all standard git commands
  - Repository initialization with `trk init` command
  - Repository cloning with `trk clone` command
  - Global repository support with `--worktree` option for shared git directories
  - Repository setup and configuration management with `setup`/`unsetup` commands
  - Worktree information display with `worktree` command
  - Git version compatibility handling (pre/post 2.46)

- Passphrase Management
  - Automatic passphrase generation with `passphrase generate`
  - Passphrase import from file with `passphrase import`
  - Passphrase retrieval with `passphrase get`

- Configuration Management
  - Export/import repository configuration with `config export`/`config import`
  - Customizable OpenSSL encryption arguments with `openssl set-args`/`get-args`/`reset-args`
  - Configuration validation and restoration of deleted files on import

- Permission Tracking
  - Optional file permission tracking with `permissions enable`/`disable`
  - Git hooks for maintaining file permissions across operations

- User Experience
  - Comprehensive help system with command-specific documentation
  - Force flag support (`-f`, `--force`) for overriding confirmations
  - Interactive prompts with confirmation for destructive operations
  - Flexible command-line parsing supporting various git workflows

[Unreleased]: https://github.com/TheoBrigitte/trk/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/TheoBrigitte/trk/releases/tag/v0.1.0
