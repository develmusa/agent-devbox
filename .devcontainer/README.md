# agent-devbox

Security-hardened DevContainer for AI coding agents. Implements defense-in-depth architecture with network egress filtering, SSH agent forwarding, and resource limits.

**Repository:** https://github.com/develmusa/agent-devbox

---

## Features

**Security:**
- Network egress filtering (IPv4/IPv6 iptables firewall)
- SSH agent forwarding (private keys never copied)
- Non-root execution (UID 1000)
- Resource limits (4GB RAM, 2 CPU, 512 processes)
- Audit logging (all blocked connections logged)

**Development:**
- OpenCode pre-installed
- Fast code search (ripgrep, fd-find)
- Auto-detects dependencies (npm, pip, cargo, go mod)
- Multi-language support (Node.js, Python, Go, Rust)

---

## Quick Start

**Prerequisites:**
- Docker Desktop or Docker Engine
- SSH agent running on host
- One of: VS Code, DevPod, or Daytona

**VS Code:**
```bash
# Install: Dev Containers extension
# F1 → "Dev Containers: Reopen in Container"
```

**DevPod:**
```bash
# Install: https://devpod.sh
devpod up .
devpod up . --ide nvim      # Or vscode, intellij, etc.
devpod ssh .                # Access container
```

**Daytona:**
```bash
# Install: https://daytona.io
daytona create .
daytona code <workspace>    # Or ssh
```

---

## Tool Comparison

| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| **VS Code** | Local development | Seamless integration, extensions | VS Code only |
| **DevPod** | IDE flexibility | Any IDE, cloud backends | Extra tool install |
| **Daytona** | Teams, cloud workspaces | Workspace management, prebuilds | More complex setup |

**Choose:**
- **VS Code** - Solo developer, VS Code user
- **DevPod** - Use Neovim/JetBrains, need cloud backends
- **Daytona** - Team with standardized environments

All tools use the same `.devcontainer/` configuration.

---

## Customization

### Add Language Support

Edit `Dockerfile` and uncomment language sections:

```dockerfile
# Python
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv

# Go
COPY --from=golang:1.22 /usr/local/go /usr/local/go

# Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

Rebuild: `F1` → **Dev Containers: Rebuild Container**

### Add VS Code Extensions

Edit `devcontainer.json`:

```json
"extensions": [
  "eamodio.gitlens",
  "usernamehw.errorlens",
  "your-extension-id"
]
```

### Whitelist Domains

Edit `scripts/init-firewall.sh`:

```bash
ALLOWED_DOMAINS=(
    # ... existing ...
    "your-domain.com"
)
```

### Modify Resource Limits

Edit `devcontainer.json`:

```json
"runArgs": [
  "--memory=8g",     // Increase RAM
  "--cpus=4"         // More CPU cores
]
```

---

## Architecture

### Security Layers

```
Host Machine
└── DevContainer (isolated)
    ├── Firewall (iptables) → blocks unauthorized traffic
    ├── SSH Agent (forwarded) → keys stay on host
    └── AI Agent (non-root) → limited privileges
```

### Network Filtering

**Default-deny firewall with explicit whitelist:**

✅ **Allowed:** GitHub, npm, PyPI, crates.io, AI providers (Anthropic, OpenAI, Google)  
❌ **Blocked:** Everything else

Verified on startup:
- `example.com` → blocked
- `api.github.com` → allowed
- `registry.npmjs.org` → allowed

### Identity Bridging

| Component | Method | Security |
|-----------|--------|----------|
| SSH Keys | Agent forwarding | Never copied to container |
| Git Config | Read-only mount | Agent can't modify |
| Agent State | Docker volume | Isolated from host |

### Dependency Detection

Auto-installs based on project files:
- `package.json` → npm/pnpm/yarn/bun
- `requirements.txt` → pip
- `go.mod` → go modules
- `Cargo.toml` → cargo

---

## Working with OpenCode

**Run OpenCode:**
```bash
opencode
```

**Auto-approve mode (safe in container):**
```bash
opencode --dangerously-skip-permissions
```

**Why safe:**
- Firewall prevents exfiltration
- Container is disposable
- Non-root execution
- All changes in git

**Best practices:**
- Commit frequently
- Review diffs before pushing
- Use feature branches
- Monitor firewall logs

---

## Troubleshooting

### Container Won't Build
```bash
docker system prune -a
# F1 → "Dev Containers: Rebuild Container Without Cache"
```

### Firewall Blocks Needed Domain
1. Check error message for domain
2. Add to `scripts/init-firewall.sh` `ALLOWED_DOMAINS`
3. Rebuild container

### SSH Agent Not Working

**Mac/Linux:**
```bash
ssh-add -l                    # Verify agent
eval $(ssh-agent)             # Start if needed
ssh-add ~/.ssh/id_rsa
```

**Windows:**
```powershell
Start-Service ssh-agent
ssh-add
```

### File Permission Issues

Edit `devcontainer.json` with your UID/GID:
```json
"build": {
  "args": {
    "NODE_USER_UID": "1000",  // id -u
    "NODE_USER_GID": "1000"   // id -g
  }
}
```

### View Blocked Connections
```bash
# From host
docker logs <container-name> 2>&1 | grep FIREWALL_BLOCK

# Inside container
dmesg | grep FIREWALL_BLOCK
```

### Check Firewall Status
```bash
sudo ipset list allowed-domains        # IPv4
sudo ipset list allowed-domains-v6     # IPv6
curl -I https://api.anthropic.com      # Test access
```

---

## Architecture Reference

Implements principles from:
> *"State-of-the-Art Architectures for Secure Agentic Coding: A Comprehensive Analysis of Isolation, Identity Bridging, and Autonomous Workflows"*

**Key principles:**
- Container isolation (Linux namespaces, cgroups)
- Identity bridging (SSH forwarding, read-only mounts)
- Network boundaries (iptables egress filtering)
- Least privilege (non-root execution, minimal capabilities)

---

## Files

```
.devcontainer/
├── devcontainer.json    # Container configuration
├── Dockerfile           # Base image (Node.js 20 + tools)
├── scripts/
│   ├── init-firewall.sh # Network security (runs at startup)
│   └── post-create.sh   # Dependency installer (runs once)
├── README.md            # This file
└── SECURITY.md          # Threat model
```

---

## License

MIT © [develmusa](../LICENSE)
