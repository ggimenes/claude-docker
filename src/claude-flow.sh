#!/bin/bash
# ABOUTME: Wrapper script to run Claude Flow in Docker container  
# ABOUTME: Uses the same Docker setup as claude-docker.sh but launches claude-flow

# Get the absolute path of the current directory
CURRENT_DIR=$(pwd)

# Fix for Git Bash on Windows - convert Windows paths to Unix format for Docker
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
    # Convert Windows-style paths to Unix format
    if command -v cygpath >/dev/null 2>&1; then
        CURRENT_DIR=$(cygpath -u "$CURRENT_DIR")
    else
        # Fallback: manually convert C:\ to /c/ format
        CURRENT_DIR=$(echo "$CURRENT_DIR" | sed 's|^\([A-Za-z]\):|/\L\1|' | sed 's|\\|/|g')
    fi
    echo "✓ Converted path for Git Bash on Windows: $CURRENT_DIR"
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Ensure the claude-home directory exists
mkdir -p "$HOME/.claude-docker/claude-home"

# Copy authentication files to persistent claude-home if they don't exist  
# Support multiple Claude authentication file formats
COPIED_AUTH=false

# Check for .credentials.json (newer format)
if [ -f "$HOME/.claude/.credentials.json" ] && [ ! -f "$HOME/.claude-docker/claude-home/.credentials.json" ]; then
    echo "✓ Copying Claude .credentials.json to persistent directory"
    cp "$HOME/.claude/.credentials.json" "$HOME/.claude-docker/claude-home/.credentials.json"
    COPIED_AUTH=true
fi

# Check for .claude.json (older format) 
if [ -f "$HOME/.claude.json" ] && [ ! -f "$HOME/.claude-docker/claude-home/.claude.json" ]; then
    echo "✓ Copying Claude .claude.json to persistent directory"
    cp "$HOME/.claude.json" "$HOME/.claude-docker/claude-home/.claude.json"
    COPIED_AUTH=true
fi

# Check for other authentication files in ~/.claude/
if [ -d "$HOME/.claude" ]; then
    for auth_file in "$HOME/.claude"/*.json; do
        if [ -f "$auth_file" ]; then
            filename=$(basename "$auth_file")
            if [ ! -f "$HOME/.claude-docker/claude-home/$filename" ]; then
                echo "✓ Copying Claude $filename to persistent directory"
                cp "$auth_file" "$HOME/.claude-docker/claude-home/$filename"
                COPIED_AUTH=true
            fi
        fi
    done 2>/dev/null
fi

# Provide authentication status feedback
if [ "$COPIED_AUTH" = true ]; then
    echo "✓ Claude authentication files copied successfully"
elif [ -f "$HOME/.claude-docker/claude-home/.credentials.json" ] || [ -f "$HOME/.claude-docker/claude-home/.claude.json" ]; then
    echo "✓ Found existing Claude authentication in persistent directory"
else
    echo "⚠️  No Claude authentication found!"
    echo "   Please run 'claude auth login' on your host system first"
    echo "   Then run claude-flow again to copy authentication files"
fi

echo "Starting Claude Flow in Docker..."

# Fix for Git Bash on Windows - prevent path conversion for Docker command
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
    export MSYS_NO_PATHCONV=1
    echo "✓ Disabled path conversion for Docker command"
fi

# Run Claude Flow directly instead of the startup script
docker run -it --rm \
    -v "$CURRENT_DIR:/workspace" \
    -v "$HOME/.claude-docker/claude-home:/home/claude-user/.claude:rw" \
    -v "$HOME/.claude-docker/ssh:/home/claude-user/.ssh:rw" \
    -v "$HOME/.claude-docker/scripts:/home/claude-user/scripts:rw" \
    -e CLAUDE_CONFIG_DIR="/home/claude-user/.claude" \
    --workdir /workspace \
    --name "claude-flow-$(basename "$CURRENT_DIR")-$$" \
    claude-docker:latest claude-flow "$@"