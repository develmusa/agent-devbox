# agent-devbox

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![DevContainer](https://img.shields.io/badge/DevContainer-enabled-blue.svg)](https://containers.dev/)
[![Security: Hardened](https://img.shields.io/badge/Security-Hardened-green.svg)](#security)
[![Documentation](https://img.shields.io/badge/Docs-online-blue.svg)](https://develmusa.github.io/agent-devbox)

> 📚 **Full Documentation**: https://develmusa.github.io/agent-devbox

Security-hardened DevContainer for AI coding agents. IDE-agnostic, works with VS Code, Neovim, JetBrains, and more.

## Features

- 🔒 **Network Egress Filtering** - IPv4/IPv6 firewall blocks unauthorized access
- 🔑 **SSH Agent Forwarding** - Private keys never enter container
- 📊 **Resource Limits** - 4GB RAM, 2 CPU cores, fork bomb protection
- 🔍 **Audit Logging** - All blocked connections logged
- 🚀 **OpenCode Pre-installed** - Ready to use immediately
- 🌐 **Multi-Language** - Node.js, Python, Go, Rust support

## Quick Start

### VS Code
```bash
# F1 → "Dev Containers: Reopen in Container"
```

### DevPod
```bash
# Install: https://devpod.sh
devpod up https://github.com/develmusa/agent-devbox

# With specific IDE
devpod up . --ide vscode
devpod up . --ide nvim
devpod up . --ide intellij
```

## IDE Support

| IDE | Support | Notes |
|-----|---------|-------|
| **VS Code** | ✅ Full | Extensions included |
| **Neovim** | ✅ Pre-installed | Bring your config |
| **Vim** | ✅ Pre-installed | Classic vim |
| **JetBrains** | ✅ Via DevPod | IntelliJ, WebStorm, etc. |
| **Any terminal editor** | ✅ SSH access | Use any CLI tool |

VS Code extensions are optional. Other IDEs ignore VS Code-specific configuration.

## Security

Implements defense-in-depth architecture:
- Container isolation (Linux namespaces)
- Network egress filtering (iptables)
- Identity bridging (SSH agent forwarding)
- Non-root execution
- Resource constraints

## Customization

Extend for additional languages or AI agents:
- Add domains to firewall whitelist in `scripts/init-firewall.sh`
- Modify resource limits in `devcontainer.json`

Works with any AI coding agent (Cursor, Aider, Continue, etc.).

## License

MIT © [develmusa](LICENSE)
