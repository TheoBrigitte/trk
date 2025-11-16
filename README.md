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

Trk uses a **selective tracking** approach where you explicitly mark which files or directories should have their permissions tracked:

1. **Mark files** for permission tracking using `trk permissions mark <path>`
2. **Before commit** (pre-commit hook): Automatically captures permissions for marked paths using `getfacl` and stores them in `.trk/permissions`
3. **After checkout** (post-checkout hook): Automatically restores permissions using `setfacl` from `.trk/permissions`

The system is optimized to only update permissions when tracked files actually change, minimizing overhead.

### Enable Permission Tracking

Permission tracking is **enabled by default**. You can explicitly control it during initialization:

```bash
# For new repositories
trk init --with-permissions     # Enable (default)
trk init --without-permissions  # Disable

# For existing repositories
trk setup --with-permissions
```

### Marking Files for Permission Tracking

Unlike automatic tracking of all files, you must explicitly mark which paths should be tracked:

```bash
# Mark a specific file
trk permissions mark bin/script.sh

# Mark a directory (will track all files recursively)
trk permissions mark config/

# View which paths are being tracked
trk permissions list

# Remove a path from tracking
trk permissions unmark bin/script.sh
```

Marked paths are stored in `.trk/permissions_list` and should be committed to the repository.

### Manual Commands

```bash
# Mark a file/directory for permission tracking
trk permissions mark <path>

# Remove a file/directory from permission tracking
trk permissions unmark <path>

# List all paths tracked for permissions
trk permissions list

# Refresh permissions file with current state (runs pre-commit hook)
trk permissions refresh

# Apply stored permissions to files
trk permissions apply

# Check differences between stored and actual permissions
trk permissions status
```

### File Structure

Trk uses two files for permission management:

1. **`.trk/permissions_list`**: Lists paths tracked for permissions (one per line)
   ```
   bin/trk
   config/
   ```

2. **`.trk/permissions`**: Stores actual permissions in standard ACL format (output from `getfacl`)
   ```
   # file: bin/trk
   user::rwx
   group::r-x
   other::r-x

   # file: config/app.conf
   user::rw-
   group::r--
   other::---
   ```

This approach is:
- **Performant**: Only tracks specified files, uses optimized native tools
- **Reliable**: Standard ACL format, widely supported
- **Flexible**: Choose exactly what needs permission tracking
- **Simple**: Base ACL entries only (owner, group, other)

### Best Practices

1. **Mark files selectively**: Only track files that need specific permissions (executables, config files)
2. **Review `.trk/permissions`** before committing to ensure correct permissions are captured
3. **Commit `.trk/permissions_list`** so others know which files are tracked
4. **Run `trk permissions status`** periodically to detect drift
5. **Use with encryption** for sensitive system files with restricted permissions

### Example Workflow

```bash
# Enable permissions on existing repo
trk setup --with-permissions

# Mark executable files for permission tracking
trk permissions mark bin/trk
trk permissions mark bin/deploy.sh

# Verify they're marked
trk permissions list

# Commit the tracking list
trk add .trk/permissions_list
trk commit -m "Track permissions for bin/ scripts"

# Add files with specific permissions
chmod 755 bin/deploy.sh
trk add bin/deploy.sh
trk commit -m "Add deployment script"  # Permissions automatically captured

# Clone on another system
trk clone --key-file key https://example.com/repo.git
# Permissions automatically restored for marked files

# Check if permissions match
trk permissions status
```

### Alternatives

- https://github.com/AGWA/git-crypt
- https://github.com/elasticdog/transcrypt
- https://github.com/sobolevn/git-secret
