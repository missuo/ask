# ask

**A**dd **S**SH **K**ey - A simple command-line tool to automatically add SSH keys from GitHub users to your `authorized_keys` file.

## Features

- 🔍 **Auto-detection**: Validates GitHub usernames and checks if users exist
- 🔑 **SSH Key Management**: Fetches and validates SSH keys from GitHub
- 🛡️ **Security**: Prevents duplicate keys and validates SSH key formats
- 📁 **Auto-setup**: Creates `.ssh` directory and `authorized_keys` file with correct permissions
- 🖥️ **Cross-platform**: Supports Linux, macOS, Windows, and FreeBSD
- ⚡ **Fast**: Written in Go for optimal performance

## Installation

### Quick Install (Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/missuo/ask/main/install.sh | bash
```

### Manual Download

Download the latest binary from [releases](https://github.com/missuo/ask/releases) for your platform:

- **Linux**: `ask-linux-amd64`, `ask-linux-arm64`, `ask-linux-386`
- **macOS**: `ask-darwin-amd64`, `ask-darwin-arm64`
- **Windows**: `ask-windows-amd64.exe`, `ask-windows-386.exe`
- **FreeBSD**: `ask-freebsd-amd64`, `ask-freebsd-arm64`

### From Source

```bash
git clone https://github.com/missuo/ask.git
cd ask
go build -ldflags="-s -w" -o ask .
```

## Usage

```bash
ask <github-username>
```

### Examples

```bash
# Add SSH keys from GitHub user 'missuo'
ask missuo

# Add SSH keys from GitHub user 'octocat'
ask octocat
```

### Sample Output

```
Found 2 SSH key(s) for user 'missuo':
  1. ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... (truncated)
  2. ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... (truncated)

Successfully added 2 new SSH key(s) to ~/.ssh/authorized_keys
```

## How It Works

1. **Validates** the GitHub username format
2. **Fetches** SSH keys from `https://github.com/<username>.keys`
3. **Validates** each SSH key format
4. **Creates** `~/.ssh` directory (mode 0700) if it doesn't exist
5. **Creates** `~/.ssh/authorized_keys` file (mode 0600) if it doesn't exist
6. **Checks** for duplicate keys to prevent adding the same key twice
7. **Appends** new keys to the `authorized_keys` file

## Supported SSH Key Types

- `ssh-rsa`
- `ssh-dss`
- `ssh-ed25519`
- `ecdsa-sha2-nistp256`
- `ecdsa-sha2-nistp384`
- `ecdsa-sha2-nistp521`

## Error Handling

The tool handles various error scenarios:

- Invalid GitHub username format
- Non-existent GitHub users (404 error)
- Users with no SSH keys
- Network connectivity issues
- Permission errors
- Invalid SSH key formats

## Security

- **Permission Management**: Automatically sets correct permissions (0700 for `.ssh`, 0600 for `authorized_keys`)
- **Key Validation**: Validates SSH key formats before adding
- **Duplicate Prevention**: Checks existing keys to prevent duplicates
- **Username Validation**: Validates GitHub username format to prevent injection attacks

## Development

### Prerequisites

- Go 1.21 or later

### Building

```bash
# Build for current platform
go build -ldflags="-s -w" -o ask .

# Cross-compile for different platforms
GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o ask-linux-amd64 .
GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o ask-darwin-arm64 .
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o ask-windows-amd64.exe .
```

### Testing

```bash
go test -v ./...
```

### Release Process

1. Create a new tag: `git tag v1.0.0`
2. Push the tag: `git push origin v1.0.0`
3. GitHub Actions will automatically build and release binaries

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin feature/new-feature`
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Inspiration

This tool was inspired by the common need to quickly add SSH keys from GitHub users to server `authorized_keys` files, automating the manual process of:

```bash
curl https://github.com/username.keys | tee -a ~/.ssh/authorized_keys
```

## Related Projects

- [github-keys](https://github.com/drduh/github-keys) - Similar concept with different implementation
- [ssh-import-id](https://launchpad.net/ssh-import-id) - Import SSH keys from various sources

---

Made with ❤️ by [missuo](https://github.com/missuo)