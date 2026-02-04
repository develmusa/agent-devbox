#!/bin/bash
# =============================================================================
#  agent-devbox - Post-Create Script
# =============================================================================
# Purpose: Smart dependency detection and automatic project setup
# Strategy: Detect project type and install only what's needed (no bloat)
# Repository: https://github.com/develmusa/agent-devbox
# =============================================================================

set -e  # Exit on error

echo "🚀 Running post-create setup..."
echo ""

# =============================================================================
# Git Configuration
# =============================================================================
echo "📝 Configuring Git..."

# Set git safe directory (required for git operations in containers)
git config --global --add safe.directory "${PWD}" 2>/dev/null || true

# Configure git defaults for better agent interaction
git config --global init.defaultBranch main 2>/dev/null || true
git config --global pull.rebase false 2>/dev/null || true
git config --global core.autocrlf input 2>/dev/null || true

echo "  ✓ Git configured"
echo ""
# =============================================================================
# Environment File Setup
# =============================================================================
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "🔐 Creating .env from .env.example..."
    cp .env.example .env
    echo "  ✓ .env file created (remember to fill in your secrets)"
    echo ""
fi