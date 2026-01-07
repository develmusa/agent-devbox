# =============================================================================
#  agent-devbox - Secure, Minimal, Agent-Optimized
# =============================================================================
# Base: Node.js 20 LTS on Debian Bookworm (slim variant for minimal size)
# Security: Non-root user, minimal dependencies, network egress filtering
# Purpose: Development environment for AI coding agents
# Repository: https://github.com/develmusa/agent-devbox
# =============================================================================

FROM node:20-bookworm-slim

# Build arguments for customization
ARG NODE_USER_UID=1000
ARG NODE_USER_GID=1000
ARG OPENCODE_VERSION=latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    # Container identification
    DEVCONTAINER=true \
    # Set shell
    SHELL=/bin/bash \
    # Prevent Python bytecode generation
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# =============================================================================
# LAYER 1: Security & Core Tools (REQUIRED)
# =============================================================================
# Install minimal system dependencies required for:
# - Security: iptables, ipset, iproute2 (firewall)
# - Agent tooling: ripgrep, fd-find (fast code search)
# - Git operations: git, openssh-client
# - Basic editing: vim, nano

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Version control
    git \
    openssh-client \
    # Security & networking
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    ca-certificates \
    curl \
    wget \
    # Agent-friendly search tools (CRITICAL for OpenCode context gathering)
    ripgrep \
    fd-find \
    # Basic utilities
    vim \
    nano \
    less \
    sudo \
    procps \
    jq \
    unzip \
    # Cleanup to reduce image size
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# LAYER 2: Language Runtimes (OPTIONAL - Uncomment as needed)
# =============================================================================

# --- Python Support (Uncomment if needed) ---
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     python3 \
#     python3-pip \
#     python3-venv \
#     python3-dev \
#     build-essential \
#     && apt-get clean \
#     && rm -rf /var/lib/apt/lists/* \
#     # Install modern Python tooling
#     && pip3 install --no-cache-dir --break-system-packages \
#         uv \
#         ruff \
#         black \
#         mypy \
#         pytest \
#         ipython

# --- Go Support (Uncomment if needed) ---
# COPY --from=golang:1.22-bookworm /usr/local/go /usr/local/go
# ENV PATH="/usr/local/go/bin:${PATH}" \
#     GOPATH="/home/node/go" \
#     GO111MODULE=on
# RUN mkdir -p /home/node/go && chown -R node:node /home/node/go

# --- Rust Support (Uncomment if needed) ---
# USER node
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
# ENV PATH="/home/node/.cargo/bin:${PATH}"
# USER root

# =============================================================================
# LAYER 3: AI Coding Agent (OpenCode)
# =============================================================================

# Install OpenCode globally
# Note: This runs as root to install in /usr/local, but agent runs as 'node' user
RUN npm install -g opencode-ai@${OPENCODE_VERSION}

# =============================================================================
# LAYER 4: User & Permissions Setup
# =============================================================================

# Ensure 'node' user exists with correct UID/GID (maps to host user)
# This prevents file permission issues when editing files from host
RUN usermod -u ${NODE_USER_UID} -o node \
    && groupmod -g ${NODE_USER_GID} -o node \
    # Grant sudo access to 'node' user for firewall script only
    && echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall \
    && chmod 0440 /etc/sudoers.d/node-firewall

# Create workspace and config directories
RUN mkdir -p /workspace \
    /home/node/.local/share/opencode \
    /home/node/.config \
    /commandhistory \
    && chown -R node:node /workspace /home/node /commandhistory

# Copy firewall script (will be executed post-container-start)
COPY scripts/init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

# =============================================================================
# LAYER 5: Final Configuration
# =============================================================================

# Set working directory
WORKDIR /workspace

# Switch to non-root user for all subsequent operations
# Security best practice: agents run with limited privileges
USER node

# Configure bash history persistence
RUN echo 'export HISTFILE=/commandhistory/.bash_history' >> /home/node/.bashrc \
    && echo 'export PROMPT_COMMAND="history -a"' >> /home/node/.bashrc

# Default command (overridden by devcontainer)
CMD ["/bin/bash"]
