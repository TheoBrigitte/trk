# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2025-09-27

### Added

#### File Encryption
- File and pattern-based encryption marking with `mark`/`unmark` commands
- Automatic encryption/decryption using git clean/smudge filters
- OpenSSL-based AES-256-CBC encryption with PBKDF2 key derivation
- Salt generation per file for secure encryption
- List encrypted files with `list encrypted` command
- Bulk re-encryption of all encrypted files with `reencrypt` command
- Custom merge driver for handling encrypted file conflicts

#### Core Git Integration
- Git wrapper functionality that passes through all standard git commands
- Repository initialization with `trk init` command
- Repository cloning with `trk clone` command
- Global repository support with `--worktree` option for shared git directories
- Repository setup and configuration management with `setup`/`unsetup` commands
- Worktree information display with `worktree` command
- Git version compatibility handling (pre/post 2.46)

#### Passphrase Management
- Automatic passphrase generation with `passphrase generate`
- Passphrase import from file with `passphrase import`
- Passphrase retrieval with `passphrase get`

#### Configuration Management
- Export/import repository configuration with `config export`/`config import`
- Customizable OpenSSL encryption arguments with `openssl set-args`/`get-args`/`reset-args`
- Configuration validation and restoration of deleted files on import

#### Permission Tracking
- Optional file permission tracking with `permissions enable`/`disable`
- Git hooks for maintaining file permissions across operations

#### User Experience
- Comprehensive help system with command-specific documentation
- Force flag support (`-f`, `--force`) for overriding confirmations
- Interactive prompts with confirmation for destructive operations
- Flexible command-line parsing supporting various git workflows

[Unreleased]: https://github.com/TheoBrigitte/trk/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/TheoBrigitte/trk/releases/tag/v0.1.0
