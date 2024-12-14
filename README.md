# trk

Trk is a Git wrapper to managed repositories and encrypt files.

It can be used to manage regular Git repositories or to manage a global repository like a dotfiles repository.

It is shamelssly inspired from [yadm](https://github.com/yadm-dev/yadm) and [transcrypt](https://github.com/elasticdog/transcrypt).

Encryption is done via OpenSSL and leverage Git filter to encrypt and decrypt files.

## Quick start

### Regular repository

```
trk init
```

### Global repository

```
trk init --worktree <path>
```

## Check content stored in git

```
trk rev-list --objects -g --no-walk --all
trk cat-file -p <hash>
```
