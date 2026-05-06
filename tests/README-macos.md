# macOS Integration Tests

Integration tests run inside a disposable UTM virtual machine over SSH.

## Prerequisites

- macOS host with Apple Silicon
- [UTM](https://mac.getutm.app/) installed
- Environment variables: `AGE_PASSPHRASE`, `RBW_EMAIL`, `RBW_PASSWORD`, `RBW_TOTP_SEED`

## Base VM Setup

### 1. Create the VM

- In UTM, create a new macOS VM using Apple Virtualization backend
- Name it `base: Tahoe 26.2`
- Allocate at least 4 CPU cores and 8 GB RAM
- Allocate at least 64 GB disk

### 2. Install macOS

- Boot and complete macOS setup
- Create a user named `tester`

### 3. Set hostname

```shell
sudo scutil --set HostName tahoe26base
sudo scutil --set LocalHostName tahoe26base
sudo scutil --set ComputerName tahoe26base
```

The VM will be discoverable as `tahoe26base.local` via mDNS.

### 4. Enable SSH

```shell
sudo systemsetup -setremotelogin on
```

This requires Full Disk Access for Terminal (System Settings > Privacy & Security > Full Disk Access).

### 5. Configure passwordless sudo

```shell
sudo visudo -f /etc/sudoers.d/tester
```

Add:

```plaintext
tester ALL=(ALL) NOPASSWD: ALL
```

### 6. Copy SSH key from host

On the host machine:

```shell
ssh-copy-id -i ~/.ssh/<your-key>.pub tester@tahoe26base.local
```

Verify passwordless SSH works:

```shell
ssh tester@tahoe26base.local echo "ok"
```

### 7. Shut down the VM

The base VM must be stopped before the test script can clone it.

## Running Tests

```shell
make test-macos
```

## How It Works

1. Clones the base VM to a disposable `test: dotfiles` instance
2. Starts the clone and waits for SSH
3. Renames the clone's hostname to `dotfiles-test` (avoids mDNS collision with base)
4. Deploys a non-interactive `pinentry-env` script that provides Bitwarden credentials
5. Pre-seeds chezmoi config to bypass interactive prompts
6. Transfers the repository and runs `integration-tests-runner.zsh --local`
7. Deletes the clone on exit (pass or fail)

## Troubleshooting

### "The virtual machine must be stopped before this operation can be performed"

Stop the base VM before running tests: `utmctl stop "base: Tahoe 26.2"`

### "SSH not available after 120s"

- Verify the base VM has SSH enabled
- Check that your SSH key is authorized on the VM
- Ensure the key is loaded in the agent: `ssh-add -l`

### "Two-step token is invalid"

- Verify `RBW_TOTP_SEED` is the base32 secret from your TOTP URL
- Test locally: `oathtool --totp -b "$RBW_TOTP_SEED"`

### pinentry debug log

On failure, the test script dumps `~/.local/share/pinentry-debug.log` from the VM, showing all pinentry protocol messages received.
