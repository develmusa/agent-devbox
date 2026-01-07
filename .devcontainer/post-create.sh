#!/bin/bash
set -e

echo "🔧 Running post-create setup..."

# Configure git for better agent interaction
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait"
git config --global diff.tool vscode
git config --global merge.tool vscode

# Setup pre-commit hooks if .pre-commit-config.yaml exists
if [ -f ".pre-commit-config.yaml" ]; then
    echo "📋 Installing pre-commit hooks..."
    pip install pre-commit
    pre-commit install
fi

# Install project dependencies based on what's present
echo "📦 Installing project dependencies..."

# Python projects
if [ -f "requirements.txt" ]; then
    echo "Installing Python requirements..."
    pip install -r requirements.txt
fi

if [ -f "pyproject.toml" ]; then
    echo "Installing Python project..."
    pip install -e .
fi

if [ -f "Pipfile" ]; then
    echo "Installing with Pipenv..."
    pipenv install --dev
fi

if [ -f "poetry.lock" ]; then
    echo "Installing with Poetry..."
    poetry install
fi

# Node.js projects
if [ -f "package.json" ]; then
    echo "Installing Node.js dependencies..."
    if [ -f "pnpm-lock.yaml" ]; then
        pnpm install
    elif [ -f "yarn.lock" ]; then
        yarn install
    else
        npm install
    fi
fi

# Go projects
if [ -f "go.mod" ]; then
    echo "Installing Go dependencies..."
    go mod download
fi

# Rust projects
if [ -f "Cargo.toml" ]; then
    echo "Building Rust project..."
    cargo build
fi

# Create .env file from .env.example if it exists and .env doesn't
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
fi

# Setup database if docker-compose.yml exists
if [ -f "docker-compose.yml" ] || [ -f "compose.yaml" ]; then
    echo "🐳 Docker Compose configuration detected"
    echo "Run 'docker-compose up -d' to start services"
fi

# Create common development files if they don't exist
if [ ! -f ".gitignore" ]; then
    echo "Creating default .gitignore..."
    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
.Python
venv/
.venv/
env/
ENV/
*.egg-info/
.pytest_cache/
.mypy_cache/
.coverage

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.pnpm-store/

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Environment
.env
.env.local

# Build outputs
dist/
build/
*.log
EOF
fi

# Create a README for coding agents if it doesn't exist
if [ ! -f "AGENT_README.md" ]; then
    cat > AGENT_README.md << 'EOF'
# AI Coding Agent Guide

## Project Structure
This project is set up for optimal interaction with AI coding agents.

## Quick Start
1. All dependencies should be installed automatically
2. Check `.env.example` for required environment variables
3. Run tests with the appropriate command for your language
4. Lint and format code before committing

## Key Files
- `.devcontainer/`: Development container configuration
- `.github/workflows/`: CI/CD pipelines
- `tests/`: Test files
- `docs/`: Documentation

## Working with AI Agents
- Code is auto-formatted on save
- Linting runs automatically
- Type checking is enabled
- All standard dev tools are pre-installed

## Commands
See package.json, Makefile, or justfile for available commands.
EOF
fi

echo "✅ Post-create setup complete!"
echo ""
echo "🎉 Your environment is ready for AI-powered development!"
echo "💡 Tips:"
echo "   - Use 'code .' to open VS Code"
echo "   - Check AGENT_README.md for project-specific info"
echo "   - All standard dev tools are pre-installed"
