# agent-devbox - Secure AI Coding Environment

A security-hardened development container optimized for AI coding agents like OpenCode. This configuration implements industry best practices for containerized development while maintaining the ergonomics of your local environment.

## 🎯 Key Features

### 🔒 Security Architecture ()

- **Network Egress Filtering**: Iptables-based firewall blocks unauthorized network access (IPv4 + IPv6)
- **SSH Agent Forwarding**: Private keys never enter the container (gold standard)
- **Non-Root Execution**: Agent runs as `node` user (UID 1000)
- **Resource Limits**: Memory (4GB), CPU (2 cores), and process limits prevent DoS attacks
- **Audit Logging**: All blocked connection attempts are logged for security review
- **Minimal Attack Surface**: Slim base image (~350MB) with only essential tools
- **State Isolation**: Agent config stored in Docker volumes, not host filesystem

### 🚀 Agent-Optimized

- **OpenCode Pre-installed**: Ready to use immediately
- **Fast Code Search**: ripgrep and fd-find for efficient context gathering
- **Smart Dependencies**: Auto-detects and installs only what your project needs
- **Minimal Friction**: Pre-configured for "vibe coding" workflows

### 🎨 Generic & Modular

- **Multi-Language Ready**: Commented sections for Python, Go, Rust (uncomment as needed)
- **Package Manager Agnostic**: Supports npm, pnpm, yarn, bun, pip, poetry, cargo, go mod
- **Minimal Extensions**: Only 2 installed (GitLens, ErrorLens) with clear examples for more

## 📋 Quick Start

### Prerequisites

- **Docker Desktop** (Mac/Windows) or **Docker Engine** (Linux)
- **VS Code** with "Dev Containers" extension
- **SSH Agent** running on host:
  - **Mac/Linux**: Usually enabled by default. Verify: `ssh-add -l`
  - **Windows**: Start "OpenSSH Authentication Agent" service (`services.msc`)

### Open Container

1. Open this project in VS Code
2. Press `F1` → **"Dev Containers: Reopen in Container"**
3. Wait 3-5 minutes for initial build (subsequent starts take ~30 seconds)
4. You're now in a secure, isolated development environment!

## 🔧 Customization

### Adding Language Support

**Uncomment relevant sections in `.devcontainer/Dockerfile`:**

#### Python
```dockerfile
# === Uncomment for Python ===
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv \
    && pip3 install --no-cache-dir uv ruff black mypy pytest
```

#### Go
```dockerfile
# === Uncomment for Go ===
COPY --from=golang:1.22 /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
```

#### Rust
```dockerfile
# === Uncomment for Rust ===
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/node/.cargo/bin:${PATH}"
```

After uncommenting, rebuild: `F1` → **"Dev Containers: Rebuild Container"**

### Adding VS Code Extensions

Edit `.devcontainer/devcontainer.json`:

```json
"extensions": [
  "eamodio.gitlens",
  "usernamehw.errorlens",
  "your-extension-id-here"  // Add your extensions
]
```

Commented examples are provided for:
- ESLint (JavaScript linting)
- Prettier (code formatting)
- Python language support
- Go language support
- Rust Analyzer

### Adding Trusted Domains (Firewall)

If your project needs access to additional domains (e.g., private package registry):

**Edit `.devcontainer/scripts/init-firewall.sh`:**

```bash
ALLOWED_DOMAINS=(
    # ... existing domains ...
    "your-private-registry.com"  # Add your domain here
)
```

Then rebuild container.

### Changing Port Forwarding

Edit `.devcontainer/devcontainer.json`:

```json
"forwardPorts": [3000, 5000, 8000, 8080, 9000],  // Add/remove ports
```

## 🛠️ How It Works

### Security Layers

```
┌─────────────────────────────────────────┐
│         Your Host Machine               │
│  ┌─────────────────────────────────┐   │
│  │   DevContainer (Isolated)       │   │
│  │  ┌──────────────────────────┐   │   │
│  │  │  OpenCode Agent          │   │   │
│  │  │  (Non-root: node user)   │   │   │
│  │  └──────────────────────────┘   │   │
│  │          ▲         ▲             │   │
│  │          │         │             │   │
│  │    ┌─────┴───┐ ┌──┴────────┐    │   │
│  │    │Firewall │ │SSH Agent  │    │   │
│  │    │(iptables)│ │Forwarding │    │   │
│  │    └─────────┘ └───────────┘    │   │
│  └─────────────────────────────────┘   │
│              ▲                          │
│              │ (socket)                 │
│      ┌───────┴────────┐                │
│      │ SSH Keys (HOST)│                │
│      │ ~/.ssh/id_rsa  │                │
│      └────────────────┘                │
└─────────────────────────────────────────┘
```

### Network Egress Filtering

The firewall (`init-firewall.sh`) implements **default-deny** with an explicit whitelist:

**✅ Allowed:**
- GitHub (api.github.com, github.com)
- AI Providers (api.anthropic.com, api.openai.com, Google Gemini)
- Package Registries (npm, PyPI, crates.io, Go proxy)
- VS Code services (marketplace, updates)

**❌ Blocked:**
- Everything else (prevents data exfiltration)

**Verification:** On container start, the firewall tests:
1. ❌ `example.com` should be blocked
2. ✅ `api.github.com` should be accessible
3. ✅ `registry.npmjs.org` should be accessible

### Identity Bridging

Your identity is projected into the container **securely**:

| What | How | Security |
|------|-----|----------|
| **SSH Keys** | Agent forwarding (socket) | ✅ Keys never copied |
| **Git Config** | Read-only bind mount | ✅ Agent can't modify |
| **OpenCode State** | Docker volume | ✅ Isolated from host |

### Smart Dependency Detection

The `post-create.sh` script auto-detects your project type:

```bash
package.json     → installs npm/pnpm/yarn/bun dependencies
requirements.txt → installs Python packages
go.mod           → downloads Go modules
Cargo.toml       → fetches Rust dependencies
.env.example     → creates .env file
```

## 🤖 Working with OpenCode

### Running OpenCode

```bash
# Inside the container terminal
opencode
```

OpenCode is installed globally and ready to use immediately.

### Safe Mode vs Auto Mode

**Because this environment is sandboxed**, you can safely run OpenCode in auto-approve mode:

```bash
opencode --dangerously-skip-permissions
```

**Why this is safe here:**
- ✅ Firewall prevents data exfiltration
- ✅ Container is disposable (easily rebuilt)
- ✅ Git repo is version-controlled (easy rollback)
- ✅ Agent runs non-root (limited system access)

**Still risky on bare metal!** This flag is only safe because of the container isolation.

### Best Practices

1. **Commit often**: Agent changes are easier to review in small chunks
2. **Check diffs**: Run `git diff` before accepting agent suggestions
3. **Use branches**: Let agent work on feature branches, you review PRs
4. **Monitor network**: Check firewall logs if suspicious activity occurs

## 🐛 Troubleshooting

### Container Won't Build

```bash
# Clear Docker cache and rebuild
docker system prune -a
# In VS Code: F1 → "Dev Containers: Rebuild Container Without Cache"
```

### Firewall Blocking Needed Domain

**Symptom:** Package installation fails with connection timeout

**Solution:**
1. Identify the domain from error message
2. Add to `ALLOWED_DOMAINS` in `scripts/init-firewall.sh`
3. Rebuild container

### SSH Agent Not Working

**Mac/Linux:**
```bash
# Check if agent is running
ssh-add -l

# Start agent if needed
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa
```

**Windows:**
```powershell
# Start OpenSSH Authentication Agent service
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add
```

### File Permission Issues

The container user (`node`) is mapped to your host UID (1000). If you have a different UID:

**Edit `.devcontainer/devcontainer.json`:**
```json
"build": {
  "args": {
    "NODE_USER_UID": "YOUR_UID",  // Get with: id -u
    "NODE_USER_GID": "YOUR_GID"   // Get with: id -g
  }
}
```

### OpenCode Can't Access Network

**Check firewall status inside container:**
```bash
# Should show whitelisted IPs (IPv4)
sudo ipset list allowed-domains

# Should show whitelisted IPs (IPv6)
sudo ipset list allowed-domains-v6

# Test specific domain
curl -I https://api.anthropic.com
```

If legitimate domain is blocked, add it to firewall config.

### Audit Blocked Connection Attempts

**View firewall logs to see blocked connections:**
```bash
# From host machine, view container logs
docker logs <container-name> 2>&1 | grep FIREWALL_BLOCK

# Inside container (if syslog is available)
dmesg | grep FIREWALL_BLOCK
```

This helps identify:
- Attempted data exfiltration by agent
- Legitimate domains that need whitelisting
- Unexpected network behavior

### Container Uses Too Much Disk Space

```bash
# Clean up unused containers/volumes
docker system prune -a --volumes

# Remove node_modules from volume (if needed)
docker volume rm $(docker volume ls -q | grep node-modules)
```

## 📊 Comparison to Other Approaches

| Approach | Security | "Keep It Close" | Performance | ? |
|----------|----------|-----------------|-------------|-------|
| **Host Execution** | ❌ Critical Risk | ✅ Perfect | ✅ Native | ❌ No |
| **Basic Docker** | ⚠️ Partial | ❌ Poor | ⚠️ OK | ❌ No |
| **This DevContainer** | ✅ High | ✅ Good | ✅ Good | ✅ **YES** |
| **Remote Micro-VM** | ✅ Maximum | ❌ None | ⚠️ Latency | ⚠️ Niche |

## 📚 Architecture References

**GitHub Repository:** https://github.com/develmusa/agent-devbox

This configuration implements the architecture described in:

> *"State-of-the-Art Architectures for Secure Agentic Coding: A Comprehensive Analysis of Isolation, Identity Bridging, and Autonomous Workflows"*

**Key principles applied:**
1. **Container Isolation** (Linux namespaces, cgroups)
2. **Identity Bridging** (SSH agent forwarding, read-only config mounts)
3. **Network Boundaries** (iptables egress filtering, ipset whitelisting)
4. **Principle of Least Privilege** (non-root execution, minimal capabilities)

## 🔍 Files Explained

```
.devcontainer/
├── devcontainer.json          # Orchestrator (mounts, features, lifecycle)
├── Dockerfile                 # Base image (minimal, secure)
├── scripts/
│   ├── init-firewall.sh      # Network security boundary (runs at startup)
│   └── post-create.sh        # Smart dependency installer (runs once)
├── README.md                  # This file (usage guide)
└── SECURITY.md                # Threat model and security details
```

## 🤝 Contributing

To improve this configuration:

1. Test changes in a clean environment
2. Verify security boundaries still work (firewall tests)
3. Update documentation
4. Consider backward compatibility

## 📝 License

This DevContainer configuration is provided as-is for development purposes.

## 💡 Pro Tips

- **Rebuild regularly**: `F1` → "Rebuild Container" picks up Dockerfile changes
- **Check logs**: `F1` → "Show Container Log" to debug startup issues
- **Volume cleanup**: Periodically prune Docker volumes to free disk space
- **Git branches**: Use feature branches for risky agent experiments
- **Version control**: Commit `.devcontainer/` to git so team shares config

---

**Questions?** Check `SECURITY.md` for threat model details or open an issue.

**Happy secure coding! 🚀🔒**
