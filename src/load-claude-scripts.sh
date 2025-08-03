#!/bin/bash
# ABOUTME: Helper script to load claude-docker scripts into current shell session
# ABOUTME: Sources .env file and temporarily adds script paths to PATH/PYTHONPATH
# USAGE: source src/load-claude-scripts.sh

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if .env exists and load it
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading claude-docker environment from $ENV_FILE"
    
    # Source .env file
    set -a
    source "$ENV_FILE" 2>/dev/null || true
    set +a
    
    # Add scripts to PATH if configured
    if [ -n "$CLAUDE_SCRIPTS_PATH" ]; then
        export PATH="$CLAUDE_SCRIPTS_PATH:$PATH"
        echo "✓ Added scripts to PATH: $CLAUDE_SCRIPTS_PATH"
        
        # List available scripts
        if [ -d "$CLAUDE_SCRIPTS_PATH" ]; then
            echo "Available scripts:"
            for script in "$CLAUDE_SCRIPTS_PATH"/*; do
                if [ -f "$script" ] && [ -x "$script" ]; then
                    echo "  - $(basename "$script")"
                fi
            done
        fi
    else
        echo "⚠️  CLAUDE_SCRIPTS_PATH not configured in .env"
    fi
    
    # Add to PYTHONPATH if configured
    if [ -n "$CLAUDE_PYTHON_PATH" ]; then
        export PYTHONPATH="$CLAUDE_PYTHON_PATH:$PYTHONPATH"
        echo "✓ Added scripts to PYTHONPATH: $CLAUDE_PYTHON_PATH"
        
        # List available Python modules
        if [ -d "$CLAUDE_PYTHON_PATH" ]; then
            echo "Available Python modules:"
            for module in "$CLAUDE_PYTHON_PATH"/*.py; do
                if [ -f "$module" ]; then
                    echo "  - $(basename "$module" .py)"
                fi
            done
        fi
    else
        echo "⚠️  CLAUDE_PYTHON_PATH not configured in .env"
    fi
    
else
    echo "❌ No .env file found at $ENV_FILE"
    echo "   Please run the install script first: ./src/install.sh"
    return 1 2>/dev/null || exit 1
fi

echo ""
echo "Claude-docker scripts loaded! You can now:"
echo "  - Run any script directly by name"
echo "  - Import Python modules with 'import sys_utils'"
echo "  - Use 'which script_name' to see full path"
echo ""
echo "Note: These paths are only active in this shell session."