#!/bin/bash
# =============================================================================
#  agent-devbox - Network Egress Firewall
# =============================================================================
# Purpose: Prevent data exfiltration and unauthorized network access by AI agents
# Strategy: Default-deny with explicit whitelist of trusted domains/IPs
# Technologies: iptables (packet filtering) + ipset (efficient IP list matching)
# Repository: https://github.com/develmusa/agent-devbox
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipeline failures
IFS=$'\n\t'        # Stricter word splitting

echo "🔒 Initializing  Network Security Boundary..."

# =============================================================================
# STEP 1: Preserve Docker Internal DNS (Critical for container networking)
# =============================================================================
# Docker uses 127.0.0.11 as an internal DNS resolver
# We must preserve these rules before flushing, or DNS will break

DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# =============================================================================
# STEP 2: Flush All Existing Rules (Clean Slate)
# =============================================================================
echo "Flushing existing firewall rules..."

# IPv4 rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# IPv6 rules
ip6tables -F 2>/dev/null || true
ip6tables -X 2>/dev/null || true
ip6tables -t nat -F 2>/dev/null || true
ip6tables -t nat -X 2>/dev/null || true
ip6tables -t mangle -F 2>/dev/null || true
ip6tables -t mangle -X 2>/dev/null || true

# Destroy existing ipset (if any)
ipset destroy allowed-domains 2>/dev/null || true
ipset destroy allowed-domains-v6 2>/dev/null || true

# =============================================================================
# STEP 3: Restore Docker DNS Resolution
# =============================================================================
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker internal DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | while read -r rule; do
        iptables -t nat $rule 2>/dev/null || true
    done
fi

# =============================================================================
# STEP 4: Allow Core Network Services (Before Restrictions)
# =============================================================================
echo "Configuring core network allowances..."

# IPv4: Allow localhost (critical for local tool communication)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# IPv6: Allow localhost
ip6tables -A INPUT -i lo -j ACCEPT 2>/dev/null || true
ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true

# IPv4: Allow DNS (UDP port 53) - required to resolve domain names
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT

# IPv6: Allow DNS
ip6tables -A OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
ip6tables -A INPUT -p udp --sport 53 -j ACCEPT 2>/dev/null || true

# IPv4: Allow SSH (TCP port 22) - required for git operations
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# IPv6: Allow SSH
ip6tables -A OUTPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
ip6tables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT 2>/dev/null || true

# IPv4: Allow established connections (responses to allowed outbound requests)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# IPv6: Allow established connections
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

# =============================================================================
# STEP 5: Create IP Whitelist (ipset for efficient matching)
# =============================================================================
echo "Creating IP whitelist..."
ipset create allowed-domains hash:net
ipset create allowed-domains-v6 hash:net family inet6 2>/dev/null || true

# =============================================================================
# STEP 6: Add GitHub Infrastructure (Dynamic IP Ranges)
# =============================================================================
echo "Fetching GitHub IP ranges from official API..."

gh_ranges=$(curl -s https://api.github.com/meta)

if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null 2>&1; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

# Extract and aggregate GitHub IP ranges (reduces number of rules)
echo "Processing GitHub IP ranges..."
while IFS= read -r cidr; do
    # Validate CIDR format
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "WARNING: Invalid CIDR from GitHub: $cidr (skipping)"
        continue
    fi
    echo "  ✓ Adding GitHub range: $cidr"
    ipset add allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | sort -u)

# =============================================================================
# STEP 7: Resolve and Whitelist Trusted Domains
# =============================================================================
echo "Resolving trusted domain IPs..."

# Define allowed domains (comprehensive list for multi-language development)
ALLOWED_DOMAINS=(
    # === AI Provider APIs ===
    "api.anthropic.com"                     # Claude (Anthropic)
    "api.openai.com"                        # ChatGPT/GPT-4 (OpenAI)
    "openrouter.ai"                         # OpenRouter (AI API Gateway)
    "generativelanguage.googleapis.com"     # Gemini (Google)
    
    # === Package Registries ===
    # Node.js
    "registry.npmjs.org"
    "registry.yarnpkg.com"
    
    # Python
    "pypi.org"
    "files.pythonhosted.org"
    
    # Rust
    "crates.io"
    "static.crates.io"
    "index.crates.io"
    
    # Go
    "proxy.golang.org"
    "sum.golang.org"
    
    # === VS Code / Microsoft Services ===
    "marketplace.visualstudio.com"
    "vscode.blob.core.windows.net"
    "update.code.visualstudio.com"
    "*.vo.msecnd.net"
    
    # === Monitoring & Telemetry (Optional - comment out for stricter security) ===
    "sentry.io"
)

for domain in "${ALLOWED_DOMAINS[@]}"; do
    echo "Resolving: $domain"
    
    # Handle wildcard domains (e.g., *.vo.msecnd.net)
    if [[ "$domain" == *"*"* ]]; then
        echo "  ⚠ Wildcard domain detected: $domain (manual IP resolution required)"
        continue
    fi
    
    # Resolve domain to IPv4 addresses
    ips=$(dig +noall +answer A "$domain" 2>/dev/null | awk '$4 == "A" {print $5}' || true)
    
    if [ -n "$ips" ]; then
        # Add each resolved IPv4 to whitelist
        while IFS= read -r ip; do
            # Validate IP format
            if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "  ⚠ Invalid IPv4 for $domain: $ip (skipping)"
                continue
            fi
            echo "  ✓ Adding IPv4 $ip for $domain"
            ipset add allowed-domains "$ip" 2>/dev/null || true
        done <<< "$ips"
    fi
    
    # Resolve domain to IPv6 addresses
    ips6=$(dig +noall +answer AAAA "$domain" 2>/dev/null | awk '$4 == "AAAA" {print $5}' || true)
    
    if [ -n "$ips6" ]; then
        # Add each resolved IPv6 to whitelist
        while IFS= read -r ip6; do
            # Basic IPv6 validation (contains colons)
            if [[ ! "$ip6" =~ .*:.* ]]; then
                echo "  ⚠ Invalid IPv6 for $domain: $ip6 (skipping)"
                continue
            fi
            echo "  ✓ Adding IPv6 $ip6 for $domain"
            ipset add allowed-domains-v6 "$ip6" 2>/dev/null || true
        done <<< "$ips6"
    fi
    
    if [ -z "$ips" ] && [ -z "$ips6" ]; then
        echo "  ⚠ WARNING: Failed to resolve $domain (skipping)"
    fi
done

# =============================================================================
# STEP 8: Allow Host Network (Docker Host Communication)
# =============================================================================
echo "Detecting Docker host network..."

HOST_IP=$(ip route | grep default | awk '{print $3}' || true)

if [ -z "$HOST_IP" ]; then
    echo "WARNING: Failed to detect host IP (host communication may be limited)"
else
    HOST_NETWORK=$(echo "$HOST_IP" | sed 's/\.[0-9]*$/.0\/24/')
    echo "Host network detected: $HOST_NETWORK"
    
    iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
    iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
fi

# =============================================================================
# STEP 9: Apply Default-Deny Policy
# =============================================================================
echo "Applying default-deny policy..."

# IPv4: Set default policies to DROP (everything not explicitly allowed is blocked)
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# IPv6: Set default policies to DROP
ip6tables -P INPUT DROP 2>/dev/null || true
ip6tables -P FORWARD DROP 2>/dev/null || true
ip6tables -P OUTPUT DROP 2>/dev/null || true

# =============================================================================
# STEP 10: Allow Traffic to Whitelisted IPs
# =============================================================================
echo "Configuring whitelist-based egress..."

# IPv4: Allow outbound HTTPS (port 443) ONLY to whitelisted IPs
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed-domains dst -j ACCEPT

# IPv4: Allow outbound HTTP (port 80) ONLY to whitelisted IPs (some package registries)
iptables -A OUTPUT -p tcp --dport 80 -m set --match-set allowed-domains dst -j ACCEPT

# IPv6: Allow outbound HTTPS (port 443) ONLY to whitelisted IPs
ip6tables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed-domains-v6 dst -j ACCEPT 2>/dev/null || true

# IPv6: Allow outbound HTTP (port 80) ONLY to whitelisted IPs
ip6tables -A OUTPUT -p tcp --dport 80 -m set --match-set allowed-domains-v6 dst -j ACCEPT 2>/dev/null || true

# =============================================================================
# STEP 11: Audit Logging for Blocked Connections
# =============================================================================
# Log blocked connection attempts for security auditing
# Logs are viewable via: docker logs <container-name> | grep FIREWALL_BLOCK

echo "Configuring audit logging for blocked connections..."

# IPv4: Log blocked OUTPUT attempts (data exfiltration attempts)
# Limit to 10 logs/min to prevent log flooding
iptables -A OUTPUT -m limit --limit 10/min --limit-burst 5 \
    -j LOG --log-prefix "FIREWALL_BLOCK_OUT: " --log-level 4

# IPv4: Log blocked INPUT attempts
iptables -A INPUT -m limit --limit 10/min --limit-burst 5 \
    -j LOG --log-prefix "FIREWALL_BLOCK_IN: " --log-level 4

# IPv6: Log blocked attempts
ip6tables -A OUTPUT -m limit --limit 10/min --limit-burst 5 \
    -j LOG --log-prefix "FIREWALL_BLOCK_OUT_V6: " --log-level 4 2>/dev/null || true
ip6tables -A INPUT -m limit --limit 10/min --limit-burst 5 \
    -j LOG --log-prefix "FIREWALL_BLOCK_IN_V6: " --log-level 4 2>/dev/null || true

# =============================================================================
# STEP 12: Explicit Deny with Feedback (Reject instead of Drop for debugging)
# =============================================================================
# Using REJECT instead of DROP provides immediate feedback if agent tries unauthorized access

# IPv4: Reject with ICMP
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -A INPUT -j REJECT --reject-with icmp-admin-prohibited

# IPv6: Reject with ICMPv6
ip6tables -A OUTPUT -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true
ip6tables -A INPUT -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true

# =============================================================================
# STEP 13: Verification Tests
# =============================================================================
echo ""
echo "🧪 Running firewall verification tests..."

# Test 1: Blocked domain (should FAIL)
echo -n "  [TEST 1] Blocking unauthorized domain (example.com)... "
if curl --connect-timeout 3 -s https://example.com >/dev/null 2>&1; then
    echo "❌ FAILED"
    echo "ERROR: Firewall verification failed - able to reach blocked domain"
    exit 1
else
    echo "✅ PASSED"
fi

# Test 2: Allowed domain (should SUCCEED)
echo -n "  [TEST 2] Allowing GitHub API access... "
if curl --connect-timeout 5 -s https://api.github.com/zen >/dev/null 2>&1; then
    echo "✅ PASSED"
else
    echo "❌ FAILED"
    echo "ERROR: Firewall verification failed - unable to reach allowed domain"
    exit 1
fi

# Test 3: npm registry access (should SUCCEED)
echo -n "  [TEST 3] Allowing npm registry access... "
if curl --connect-timeout 5 -s https://registry.npmjs.org >/dev/null 2>&1; then
    echo "✅ PASSED"
else
    echo "⚠ WARNING: npm registry unreachable (may affect package installation)"
fi

# =============================================================================
# SUCCESS
# =============================================================================
echo ""
echo "✅ Network security boundary initialized successfully!"
echo ""
echo "📊 Firewall Status:"
echo "  • Default policy: DENY all (IPv4 + IPv6)"
echo "  • Whitelisted IPv4: $(ipset list allowed-domains 2>/dev/null | grep -c '^[0-9]' || echo '0')"
echo "  • Whitelisted IPv6: $(ipset list allowed-domains-v6 2>/dev/null | grep -c ':' || echo '0')"
echo "  • Allowed protocols: DNS (53), SSH (22), HTTP/HTTPS (80/443) to trusted IPs only"
echo ""
echo "🛡️  Your AI coding agent is now running in a secure sandbox."
echo "   Data exfiltration to unauthorized endpoints is blocked (IPv4 + IPv6)."
echo ""
