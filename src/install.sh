#!/bin/bash
# ABOUTME: Installation script for claude-docker
# ABOUTME: Creates claude-docker/claude-home directory at home, copies .env.example to .env,
# ABOUTME: adds claude-docker alias to .zshrc, makes scripts executable.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Create claude persistence directory
mkdir -p "$HOME/.claude-docker/claude-home"

# Create scripts directory
mkdir -p "$HOME/.claude-docker/scripts"

# Copy template scripts
echo "✓ Copying template scripts to persistent directory"
cp -r "$PROJECT_ROOT/scripts/"* "$HOME/.claude-docker/scripts/"

# Copy template .claude contents to persistent directory
echo "✓ Copying template Claude configuration to persistent directory"
cp -r "$PROJECT_ROOT/.claude/"* "$HOME/.claude-docker/claude-home/"

# Copy example env file if doesn't exist
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
    echo "⚠️  Created .env file at $PROJECT_ROOT/.env"
    echo "   Please edit it with your API keys!"
fi

# Add alias to .zshrc
ALIAS_LINE="alias claude-docker='$PROJECT_ROOT/src/claude-docker.sh'"

if ! grep -q "alias claude-docker=" "$HOME/.zshrc"; then
    echo "" >> "$HOME/.zshrc"
    echo "# Claude Docker alias" >> "$HOME/.zshrc"
    echo "$ALIAS_LINE" >> "$HOME/.zshrc"
    echo "✓ Added 'claude-docker' alias to .zshrc"
else
    echo "✓ Claude-docker alias already exists in .zshrc"
fi

# Set default script paths in .env if not already configured
SCRIPTS_DIR="$HOME/.claude-docker/scripts"
if [ -f "$PROJECT_ROOT/.env" ]; then
    # Check if script paths are already configured in .env
    if ! grep -q "CLAUDE_SCRIPTS_PATH=" "$PROJECT_ROOT/.env"; then
        echo "" >> "$PROJECT_ROOT/.env"
        echo "# Claude Docker scripts path (automatically set by installer)" >> "$PROJECT_ROOT/.env"
        echo "CLAUDE_SCRIPTS_PATH=\"$SCRIPTS_DIR\"" >> "$PROJECT_ROOT/.env"
        echo "CLAUDE_PYTHON_PATH=\"$SCRIPTS_DIR\"" >> "$PROJECT_ROOT/.env"
        echo "✓ Added script paths to .env file (safer than modifying global PATH)"
    else
        echo "✓ Script paths already configured in .env file"
    fi
else
    echo "⚠️  No .env file found - script paths not configured"
    echo "   Run this script again after creating .env file"
fi

# Optional: Remove old PATH modifications from shell files (commented out by default)
# Uncomment these lines if you want to clean up previous installations
# sed -i '/# Claude Docker scripts directory/,+2d' "$HOME/.bashrc" 2>/dev/null || true
# sed -i '/# Claude Docker scripts directory/,+2d' "$HOME/.zshrc" 2>/dev/null || true

# Make scripts executable
chmod +x "$PROJECT_ROOT/src/claude-docker.sh"
chmod +x "$PROJECT_ROOT/src/startup.sh"

echo ""
echo "Installation complete! 🎉"
echo ""
echo "Next steps:"
echo "1. (Optional) Edit $PROJECT_ROOT/.env with your API keys"
echo "2. Run 'source ~/.zshrc' or start a new terminal"
echo "3. Navigate to any project and run 'claude-docker' to start"
echo "4. If no API key, Claude will prompt for interactive authentication"