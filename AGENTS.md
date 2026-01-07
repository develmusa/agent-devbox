# AGENTS.md - DevContainer Infrastructure Guide

**Project:** agent-devbox - Security-hardened DevContainer for AI coding agents  
**Repository:** https://github.com/develmusa/agent-devbox  
**Type:** Infrastructure/DevOps (DevContainer configuration, security scripts)

This guide is for AI coding agents working on DevContainer configurations, security scripts, and infrastructure-as-code.

---

## 🏗️ Project Structure

```
.devcontainer/
├── devcontainer.json         # Main DevContainer configuration
├── Dockerfile                # Container image definition (Node.js 20 + tools)
├── scripts/
│   ├── init-firewall.sh      # Network egress filtering (iptables)
│   └── post-create.sh        # Dependency auto-detection & installation
├── README.md                 # User documentation
└── SECURITY.md               # Threat model & security architecture
```

**No application code** - This is a pure infrastructure project.

---

## 🧪 Build/Test Commands

### Testing the DevContainer

Since this is infrastructure, testing means **building and entering the container**:

```bash
# Rebuild container (VS Code)
# F1 → "Dev Containers: Rebuild Container"

# Build manually (from host)
cd .devcontainer
docker build -t agent-devbox-test .

# Run container with security settings (full Docker)
docker run -it --cap-add=NET_ADMIN \
  --memory=4g --cpus=2 --pids-limit=512 \
  agent-devbox-test /bin/bash
```

**Note on Podman/Rootless Environments:**
- The firewall will automatically detect if running in a restricted environment
- If iptables set module is unavailable, firewall gracefully skips with a warning
- Container will start successfully even without firewall capabilities
- Full firewall features require Docker Desktop or Docker Engine (not rootless)

### Script Validation

```bash
# Validate bash scripts (shellcheck required)
shellcheck .devcontainer/scripts/*.sh

# Validate JSON files
jq empty .devcontainer/devcontainer.json

# Test firewall script (requires container with NET_ADMIN)
sudo /usr/local/bin/init-firewall.sh
```

### Firewall Verification Tests

The firewall script has **built-in tests** (run automatically on container start in full Docker):

```bash
# Test 1: Block unauthorized domain
curl --connect-timeout 3 https://example.com  # Should FAIL

# Test 2: Allow GitHub API
curl --connect-timeout 5 https://api.github.com/zen  # Should SUCCEED

# Test 3: Allow npm registry
curl --connect-timeout 5 https://registry.npmjs.org  # Should SUCCEED
```

**Note:** In podman/rootless environments, these tests are skipped and firewall is disabled.

### View Firewall Logs

```bash
# Inside container
dmesg | grep FIREWALL_BLOCK

# From host
docker logs <container-name> 2>&1 | grep FIREWALL_BLOCK
```

### Check Whitelist Status

```bash
# List whitelisted IPv4 addresses
sudo ipset list allowed-domains

# List whitelisted IPv6 addresses
sudo ipset list allowed-domains-v6

# Show iptables rules
sudo iptables -L -n -v
sudo ip6tables -L -n -v
```

---

## 📝 Code Style Guidelines

### Bash Scripts

**Style:**
- Use `#!/bin/bash` shebang (NOT `#!/bin/sh`)
- Enable strict mode: `set -euo pipefail`
- Use `IFS=$'\n\t'` for safer word splitting
- Quote all variables: `"$VAR"` not `$VAR`
- Prefer `[[` over `[` for conditionals

**Comments:**
- Use section headers with `# ===...===`
- Explain WHY, not WHAT (code shows what)
- Document security rationale for firewall rules

**Example:**
```bash
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Fetch GitHub IP ranges (dynamic - updated frequently)
gh_ranges=$(curl -s --connect-timeout 5 https://api.github.com/meta || true)

if [ -n "$gh_ranges" ]; then
    echo "✓ Successfully fetched GitHub IP ranges"
fi
```

**Naming Conventions:**
- Variables: `UPPER_CASE` for globals, `lower_case` for locals
- Functions: `lower_case_with_underscores`
- Use descriptive names: `ALLOWED_DOMAINS` not `DOMAINS`

**Error Handling:**
- Always check command success with `|| true` for non-critical commands
- Use retry logic for network operations (see `init-firewall.sh:122-140`)
- Provide fallback values when external data fails

### JSON/JSONC Files

**devcontainer.json:**
- Use JSONC format (comments allowed)
- Indent: 2 spaces
- Group related settings with comment headers
- Order: name → build → security → features → mounts → customizations → lifecycle

**Formatting:**
```bash
# Validate and pretty-print
jq . .devcontainer/devcontainer.json
```

### Dockerfile

**Style:**
- Group related RUN commands with `&&` (minimize layers)
- Always run `apt-get clean && rm -rf /var/lib/apt/lists/*` after apt-get
- Use `--no-install-recommends` for minimal image size
- Comment each layer's purpose with header block

**Order:**
1. FROM + ARG + ENV
2. System dependencies (security tools, git, etc.)
3. Optional language runtimes (commented - user uncommments as needed)
4. AI tools (OpenCode)
5. User/permissions setup
6. Workspace configuration

---

## 🔒 Security Guidelines (CRITICAL)

### Network Firewall Rules

**When adding new allowed domains:**

1. **Justify the addition** - Explain why this domain is necessary
2. **Use official domains** - Prefer `registry.npmjs.org` over CDNs
3. **Avoid wildcards** - Explicit domains only (wildcards bypass security)
4. **Test after adding** - Verify domain resolves and firewall allows it

**Example:**
```bash
# In .devcontainer/scripts/init-firewall.sh
ALLOWED_DOMAINS=(
    # ... existing domains ...
    
    # Justification: Required for Rust crate downloads
    "crates.io"
    "static.crates.io"
)
```

### Dockerfile Security Rules

**NEVER:**
- Run as root user (always `USER node` at end)
- Copy SSH keys into image (`COPY ~/.ssh` is FORBIDDEN)
- Hardcode secrets in ENV variables
- Use `latest` tags for security-critical images

**ALWAYS:**
- Use specific base image versions: `node:20-bookworm-slim`
- Minimize capabilities (only `NET_ADMIN` for firewall)
- Set resource limits in `devcontainer.json` runArgs
- Use non-root user (UID 1000 to match host)

### DevContainer Configuration

**Security-critical settings:**
```json
{
  "capAdd": ["NET_ADMIN"],           // ONLY for firewall
  "runArgs": [
    "--memory=4g",                    // Prevent memory exhaustion
    "--cpus=2",                       // Limit CPU usage
    "--pids-limit=512"                // Prevent fork bombs
  ],
  "remoteUser": "node",               // Non-root execution
  "updateRemoteUserUID": true         // Match host UID
}
```

**DO NOT:**
- Add `--privileged` flag (defeats container isolation)
- Add `--cap-add=SYS_ADMIN` (unnecessary, security risk)
- Mount `/var/run/docker.sock` (Docker-in-Docker unnecessary here)
- Use `consistency=delegated` on Linux (Mac/Windows only)

---

## 🛠️ Modification Guidelines

### Adding Language Support

**Process:**
1. Edit `.devcontainer/Dockerfile`
2. Uncomment relevant language section (Python/Go/Rust)
3. Rebuild container to test
4. Update `.devcontainer/README.md` if adding new language

**Example (Python):**
```dockerfile
# Uncomment lines 70-86 in Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev build-essential \
    && pip3 install --no-cache-dir --break-system-packages \
        uv ruff black mypy pytest ipython
```

### Adding VS Code Extensions

Edit `.devcontainer/devcontainer.json`:
```json
"extensions": [
    "eamodio.gitlens",
    "usernamehw.errorlens",
    "your-extension-id"              // Add here
]
```

**Best practices:**
- Keep extensions minimal (they slow container builds)
- Group by category (productivity, language support, etc.)
- Comment out language-specific extensions until needed

### Modifying Resource Limits

Edit `devcontainer.json` runArgs:
```json
"runArgs": [
    "--memory=8g",        // Increase from 4g for heavy workloads
    "--cpus=4"           // Increase from 2 for parallel builds
]
```

**Guidelines:**
- Keep limits reasonable (prevent host resource exhaustion)
- Test on low-spec machines (4GB RAM minimum)
- Document why limits were increased

---

## 🔍 Testing & Verification

### Pre-commit Checklist

Before committing changes:

1. **Validate syntax:**
   ```bash
   shellcheck .devcontainer/scripts/*.sh
   jq empty .devcontainer/devcontainer.json
   ```

2. **Rebuild container:**
   ```bash
   # F1 → "Dev Containers: Rebuild Container Without Cache"
   ```

3. **Verify firewall tests pass:**
   ```bash
   # Container startup output should show:
   # ✅ [TEST 1] Blocking unauthorized domain... PASSED
   # ✅ [TEST 2] Allowing GitHub API access... PASSED
   # ✅ [TEST 3] Allowing npm registry access... PASSED
   ```

4. **Test dependency detection:**
   ```bash
   # Verify post-create.sh runs without errors
   # Check logs: View → Output → Dev Containers
   ```

### Common Issues

**Container won't build:**
```bash
# Clear Docker cache
docker system prune -a
```

**Sudo password required error:**
- Ensure `postStartCommand` uses `sudo -n` flag for non-interactive mode
- Verify sudoers file allows NOPASSWD for the script path

**Firewall blocks needed domain:**
1. Check error: `docker logs <container> | grep FIREWALL_BLOCK`
2. Add domain to `init-firewall.sh` ALLOWED_DOMAINS
3. Rebuild container

**Permission errors:**
1. Verify UID/GID in `devcontainer.json` match host: `id -u` and `id -g`
2. Rebuild container with correct values

**ipset errors in rootless containers (Podman):**
- This is expected in rootless/podman environments
- Firewall will work in full Docker with privileged NET_ADMIN
- For development, can be safely ignored

---

## 📚 Documentation Standards

### When to update docs:

| Change | Update File |
|--------|-------------|
| Add language support | `.devcontainer/README.md` |
| Add firewall domain | Comment in `init-firewall.sh` |
| Modify security settings | `.devcontainer/SECURITY.md` |
| Change build args | `.devcontainer/devcontainer.json` (comments) |

### Documentation style:

- Use emoji sparingly (only for section headers)
- Write in imperative mood ("Add domain", not "Adding domain")
- Include code examples for complex changes
- Explain security implications of changes

---

## ⚠️ Critical Rules for AI Agents

1. **NEVER disable the firewall** - It's the primary security boundary
2. **NEVER add wildcards to ALLOWED_DOMAINS** - Defeats whitelist security
3. **NEVER run container as root** - Always `USER node` in Dockerfile
4. **ALWAYS test firewall after modifying init-firewall.sh** - Verify tests pass
5. **ALWAYS rebuild container after Dockerfile changes** - Don't use cache for security changes

---

## 📖 Additional Resources

- **DevContainer Spec:** https://containers.dev/implementors/json_reference/
- **Dockerfile Best Practices:** https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- **iptables Tutorial:** https://www.netfilter.org/documentation/HOWTO/packet-filtering-HOWTO.html
- **OpenCode Docs:** https://opencode.ai/docs

---

**Last Updated:** 2026-01-07  
**Maintainer:** develmusa  
**License:** MIT
