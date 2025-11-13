<p align="center">
    <img src="assets/trk.jpg" alt="trk" height="100px">
</p>

# trk

Trk (or track) is a Git wrapper to managed repositories and encrypt files.

It can be used to manage regular Git repositories or to manage a global repository like a [dotfiles](https://wiki.archlinux.org/title/Dotfiles) repository.

It is shamelessly inspired from [yadm](https://github.com/yadm-dev/yadm) and [transcrypt](https://github.com/elasticdog/transcrypt).

Encryption is done via OpenSSL and leverage [Git clean/smudge filters](https://git-scm.com/book/ms/v2/Customizing-Git-Git-Attributes#filters_a) to encrypt and decrypt files seamlessly, meaning that encrypted files are stored in the repository and decrypted on the fly when checked out.

# Why trk ? Another dotfiles manager ?

Trk is more than a dotfiles manager, it can be used to manage any Git repository with encryption capabilities. There are many solutions out there for managing dotfiles and encryption in Git but none of them felt right:

- git-crypt is great and does the encryption job well, but it is not very pratical when it comes to actually managing encrypted files and handling of .gitattributes which must be done manually.
- chezmoi seems like a good tool overall but does not support transparent encryption of files.
- yadm is also very powerfull but does not provide anything on top of git-crypt and handle permissions in a very specific way

## Quick start

Grab the script and install it in your path:

```
wget https://raw.githubusercontent.com/TheoBrigitte/trk/refs/heads/main/trk
install -D -m 755 trk ~/.local/bin/trk
```

### From scratch

```
trk init
```

### From existing repository

```
trk setup
```

### From a remote repository

```
trk clone <url>
```

## Encryption

Trk encrypts files on the fly when added to the repository.
To define which files should be encrypted, you can set a file or pattern (see `man gitignore` for more information) with the following command:

```
trk mark <file>
or
trk mark '<pattern>' # Don't forget the quotes, otherwise the shell will expand the pattern
```

Encryption is done via OpenSSL and the key is stored in the GIT_DIR/config file. The key is generated when the repository is initialized. The key is then used to encrypt and decrypt files on the fly when they are added to the repository or checked out.
OpenSSL cipher and arguments can be viewed and modified using the following commands:

```
trk openssl get-args
trk openssl set-args <args>
```

You can then work with the repository as you would with a regular Git repository and encryption will happen seamlessly.

### Check content stored in Git

You can verify that the content stored in Git is encrypted by running the following commands:

```
trk rev-list --objects -g --no-walk --all
trk cat-file -p <hash>
```

## Global / dotfile repository

Trk can be used to manage a global repository, like a dotfiles repository. This happens with you use the `--worktree` option with the `init` and `clone` commands.

Global repository is created in a unique location and can be used to manage all files in the given worktree without having to create the Git repository there. For example creating a Git directory in your home directory is probably not a good idea as it will clutter your home directory with Git files and you may accidentally commit files that you don't want to when working on other projects where you forgot to initialize a Git repository.

### From scratch

```
trk init --worktree <path>
```

### From a remote repository

```
trk clone --worktree <path> <url>
```

You can then work with the repository using `trk` as you would with a regular Git repository, encryption works the same way.

## Permission Management

Git only tracks the executable bit for files, not full file permissions or ownership. Trk provides comprehensive permission tracking using `getfacl`/`setfacl` to preserve complete file metadata across different systems.

### How It Works

Trk uses git hooks to automatically:
1. **Before commit** (pre-commit): Capture current file permissions using `getfacl` in `.gitpermissions`
2. **After checkout** (post-checkout): Restore permissions using `setfacl` from `.gitpermissions`

The `.gitpermissions` file stores permissions in standard ACL format (base entries only: owner, group, other).

### Enable Permission Tracking

Permission tracking is **disabled by default**. Enable it during initialization:

```bash
# For new repositories
trk init --with-permissions

# For existing repositories
trk setup --with-permissions
```

### Manual Commands

```bash
# Refresh permissions file with current state
trk permissions refresh

# Apply stored permissions to files
trk permissions apply

# Check differences between stored and actual permissions
trk permissions status

# Migrate old format to new format (if upgrading from older version)
trk permissions migrate
```

### File Format

The `.gitpermissions` file uses standard ACL format (output from `getfacl`):
```
# file: bin/trk
user::rwx
group::r-x
other::r-x
# file: README.md
user::rw-
group::r--
other::r--
```

This format is:
- **Performant**: `getfacl`/`setfacl` are optimized native tools
- **Reliable**: Standard ACL format, widely supported
- **Simple**: Base ACL entries only (owner, group, other)

### Best Practices

1. **Review `.gitpermissions`** before committing to ensure correct permissions
2. **Run `trk permissions status`** periodically to detect drift
3. **Use with encryption** for sensitive system files
4. **Document special permissions** in your README if they're unusual

### Example Workflow

```bash
# Enable permissions on existing repo
trk setup --with-permissions

# Add files with specific permissions
chmod 755 bin/script.sh
git add bin/script.sh
git commit -m "Add script"  # Permissions automatically captured

# Clone on another system
trk clone --key-file key https://example.com/repo.git
# Permissions automatically restored

# Check if permissions match
trk permissions status
```

### Alternatives

- https://github.com/AGWA/git-crypt
- https://github.com/elasticdog/transcrypt
- https://github.com/sobolevn/git-secret
