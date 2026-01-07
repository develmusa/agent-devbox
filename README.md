# agent-devbox

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![DevContainer](https://img.shields.io/badge/DevContainer-enabled-blue.svg)](https://containers.dev/)
[![Security: Hardened](https://img.shields.io/badge/Security-Hardened-green.svg)](#security)

Security-hardened DevContainer for AI coding agents like OpenCode.

## Features

- 🔒 **Network Egress Filtering** - IPv4/IPv6 firewall blocks unauthorized access
- 🔑 **SSH Agent Forwarding** - Private keys never enter container
- 📊 **Resource Limits** - 4GB RAM, 2 CPU cores, fork bomb protection
- 🔍 **Audit Logging** - All blocked connections logged
- 🚀 **OpenCode Pre-installed** - Ready to use immediately
- 🌐 **Multi-Language** - Node.js, Python, Go, Rust support

## Quick Start

1. Open repository in VS Code
2. `F1` → **Dev Containers: Reopen in Container**
3. Wait for build (3-5 minutes first time)
4. Run `opencode` to start coding

## Security

Implements defense-in-depth architecture:
- Container isolation (Linux namespaces)
- Network egress filtering (iptables)
- Identity bridging (SSH agent forwarding)
- Non-root execution
- Resource constraints

See [SECURITY.md](.devcontainer/SECURITY.md) for threat model.

## Documentation

- **[Setup Guide](.devcontainer/README.md)** - Full configuration details
- **[Security Architecture](.devcontainer/SECURITY.md)** - Threat model and mitigations

## Customization

Extend for additional languages or AI agents:
- Uncomment language sections in `.devcontainer/Dockerfile`
- Add domains to firewall whitelist in `scripts/init-firewall.sh`
- Modify resource limits in `devcontainer.json`

Works with any AI coding agent (Cursor, Aider, Continue, etc.).

## License

MIT © [develmusa](LICENSE)
