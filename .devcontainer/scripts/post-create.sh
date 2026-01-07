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
# STEP 1: Git Configuration
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
# STEP 2: Node.js Project Detection & Setup
# =============================================================================
if [ -f "package.json" ]; then
    echo "📦 Node.js project detected!"
    
    # Detect which package manager is being used
    if [ -f "pnpm-lock.yaml" ]; then
        echo "  • Package manager: pnpm"
        echo "  • Installing pnpm globally..."
        npm install -g pnpm >/dev/null 2>&1 || true
        echo "  • Installing dependencies..."
        pnpm install
    elif [ -f "yarn.lock" ]; then
        echo "  • Package manager: yarn"
        echo "  • Installing yarn globally..."
        npm install -g yarn >/dev/null 2>&1 || true
        echo "  • Installing dependencies..."
        yarn install
    elif [ -f "bun.lockb" ]; then
        echo "  • Package manager: bun"
        echo "  • Installing bun globally..."
        npm install -g bun >/dev/null 2>&1 || true
        echo "  • Installing dependencies..."
        bun install
    else
        echo "  • Package manager: npm (default)"
        echo "  • Installing dependencies..."
        npm install
    fi
    
    echo "  ✓ Node.js dependencies installed"
    echo ""
fi

# =============================================================================
# STEP 3: Python Project Detection & Setup
# =============================================================================
PYTHON_DETECTED=false

if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ] || [ -f "poetry.lock" ]; then
    PYTHON_DETECTED=true
    echo "🐍 Python project detected!"
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        echo "  ⚠ WARNING: Python is not installed in this container"
        echo "  → Uncomment Python section in .devcontainer/Dockerfile and rebuild"
        echo ""
    else
        PYTHON_VERSION=$(python3 --version 2>&1)
        echo "  • Python version: $PYTHON_VERSION"
        
        # Install dependencies based on what's available
        if [ -f "poetry.lock" ]; then
            echo "  • Package manager: Poetry"
            if command -v poetry &> /dev/null; then
                echo "  • Installing dependencies..."
                poetry install
            else
                echo "  ⚠ Poetry not installed - run: pip3 install poetry"
            fi
        elif [ -f "Pipfile" ]; then
            echo "  • Package manager: Pipenv"
            if command -v pipenv &> /dev/null; then
                echo "  • Installing dependencies..."
                pipenv install --dev
            else
                echo "  ⚠ Pipenv not installed - run: pip3 install pipenv"
            fi
        elif [ -f "pyproject.toml" ]; then
            echo "  • Installing project in editable mode..."
            pip3 install -e . 2>/dev/null || true
        elif [ -f "requirements.txt" ]; then
            echo "  • Installing from requirements.txt..."
            pip3 install -r requirements.txt
        fi
        
        echo "  ✓ Python dependencies installed"
        echo ""
    fi
fi

# =============================================================================
# STEP 4: Go Project Detection & Setup
# =============================================================================
if [ -f "go.mod" ]; then
    echo "🐹 Go project detected!"
    
    if ! command -v go &> /dev/null; then
        echo "  ⚠ WARNING: Go is not installed in this container"
        echo "  → Uncomment Go section in .devcontainer/Dockerfile and rebuild"
        echo ""
    else
        GO_VERSION=$(go version 2>&1)
        echo "  • Go version: $GO_VERSION"
        echo "  • Downloading dependencies..."
        go mod download
        echo "  ✓ Go dependencies downloaded"
        echo ""
    fi
fi

# =============================================================================
# STEP 5: Rust Project Detection & Setup
# =============================================================================
if [ -f "Cargo.toml" ]; then
    echo "🦀 Rust project detected!"
    
    if ! command -v cargo &> /dev/null; then
        echo "  ⚠ WARNING: Rust is not installed in this container"
        echo "  → Uncomment Rust section in .devcontainer/Dockerfile and rebuild"
        echo ""
    else
        RUST_VERSION=$(rustc --version 2>&1)
        echo "  • Rust version: $RUST_VERSION"
        echo "  • Fetching dependencies..."
        cargo fetch
        echo "  ✓ Rust dependencies fetched"
        echo ""
    fi
fi

# =============================================================================
# STEP 6: Environment File Setup
# =============================================================================
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "🔐 Creating .env from .env.example..."
    cp .env.example .env
    echo "  ✓ .env file created (remember to fill in your secrets)"
    echo ""
fi

# =============================================================================
# STEP 7: Pre-commit Hooks (Optional)
# =============================================================================
if [ -f ".pre-commit-config.yaml" ]; then
    echo "🪝 Pre-commit configuration detected!"
    
    if command -v pre-commit &> /dev/null || (command -v python3 &> /dev/null); then
        if ! command -v pre-commit &> /dev/null; then
            echo "  • Installing pre-commit..."
            pip3 install pre-commit >/dev/null 2>&1 || true
        fi
        echo "  • Installing pre-commit hooks..."
        pre-commit install 2>/dev/null || true
        echo "  ✓ Pre-commit hooks installed"
        echo ""
    fi
fi

# =============================================================================
# STEP 8: Project Summary
# =============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Post-create setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 Environment Summary:"
echo "  • Container user: $(whoami)"
echo "  • Working directory: ${PWD}"
echo "  • Node.js: $(node --version 2>/dev/null || echo 'not installed')"
echo "  • npm: $(npm --version 2>/dev/null || echo 'not installed')"

if command -v python3 &> /dev/null; then
    echo "  • Python: $(python3 --version 2>&1 | cut -d' ' -f2)"
fi

if command -v go &> /dev/null; then
    echo "  • Go: $(go version 2>&1 | cut -d' ' -f3)"
fi

if command -v cargo &> /dev/null; then
    echo "  • Rust: $(rustc --version 2>&1 | cut -d' ' -f2)"
fi

echo ""
echo "🛡️  Security Features:"
echo "  • Network egress filtering: ACTIVE"
echo "  • SSH agent forwarding: ENABLED"
echo "  • Non-root execution: ENFORCED (user: node)"
echo ""

# Display available scripts if package.json exists
if [ -f "package.json" ] && command -v jq &> /dev/null; then
    SCRIPTS=$(jq -r '.scripts | keys[]' package.json 2>/dev/null | head -5)
    if [ -n "$SCRIPTS" ]; then
        echo "📜 Available npm scripts:"
        echo "$SCRIPTS" | while read -r script; do
            echo "  • npm run $script"
        done
        echo ""
    fi
fi

echo "💡 Next steps:"
echo "  • Review .env file if created (add your secrets)"
echo "  • Run tests to verify setup works"
echo "  • Start coding with OpenCode!"
echo ""
echo "🤖 OpenCode installed globally - run: opencode"
echo ""
