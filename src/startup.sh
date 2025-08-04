#!/bin/bash
# ABOUTME: Startup script for claude-docker container with MCP server
# ABOUTME: Loads twilio env vars, checks for .credentials.json, copies CLAUDE.md template if no claude.md in claude-docker/claude-home.
# ABOUTME: Starts claude code with permissions bypass and continues from last session.
# ABOUTME: Sets CLAUDE_CONFIG_DIR to fix authentication issues in containers (see GitHub issue #1736)
# NOTE: Need to call claude-docker --rebuild to integrate changes.

# Load environment variables from .env if it exists
# Use the .env file baked into the image at build time
if [ -f /app/.env ]; then
    echo "Loading environment from baked-in .env file"
    set -a
    source /app/.env 2>/dev/null || true
    set +a
    
    # Export Twilio variables for runtime use
    export TWILIO_ACCOUNT_SID
    export TWILIO_AUTH_TOKEN
    export TWILIO_FROM_NUMBER
    export TWILIO_TO_NUMBER
    
    # Add claude-docker scripts to PATH if configured in .env
    if [ -n "$CLAUDE_SCRIPTS_PATH" ]; then
        export PATH="$CLAUDE_SCRIPTS_PATH:$PATH"
        echo "✓ Added claude-docker scripts to PATH: $CLAUDE_SCRIPTS_PATH"
    fi
    
    # Add claude-docker scripts to PYTHONPATH if configured in .env
    if [ -n "$CLAUDE_PYTHON_PATH" ]; then
        export PYTHONPATH="$CLAUDE_PYTHON_PATH:$PYTHONPATH"
        echo "✓ Added claude-docker scripts to PYTHONPATH: $CLAUDE_PYTHON_PATH"
    fi
else
    echo "WARNING: No .env file found in image."
fi

# Run runtime permission checks to ensure claude-user can write to all necessary locations
echo "🔧 Running runtime permission checks..."
if [ -f "/app/fix-runtime-permissions.sh" ]; then
    source /app/fix-runtime-permissions.sh
else
    echo "⚠️  Runtime permission script not found, proceeding with default permissions"
fi

# Check for existing authentication - support multiple formats
AUTH_FOUND=false
AUTH_FILES=""

if [ -f "$HOME/.claude/.credentials.json" ]; then
    echo "✓ Found Claude .credentials.json authentication"
    AUTH_FOUND=true
    AUTH_FILES="$AUTH_FILES .credentials.json"
fi

if [ -f "$HOME/.claude/.claude.json" ]; then
    echo "✓ Found Claude .claude.json authentication"  
    AUTH_FOUND=true
    AUTH_FILES="$AUTH_FILES .claude.json"
fi

# Check for any other JSON files in .claude directory
for auth_file in "$HOME/.claude"/*.json; do
    if [ -f "$auth_file" ]; then
        filename=$(basename "$auth_file")
        if [ "$filename" != ".credentials.json" ] && [ "$filename" != ".claude.json" ]; then
            echo "✓ Found additional Claude auth file: $filename"
            AUTH_FOUND=true
            AUTH_FILES="$AUTH_FILES $filename"
        fi
    fi
done 2>/dev/null

if [ "$AUTH_FOUND" = true ]; then
    echo "✓ Claude authentication ready -$AUTH_FILES"
    echo "✓ CLAUDE_CONFIG_DIR set to: $CLAUDE_CONFIG_DIR"
else
    echo "⚠️  No Claude authentication found in container!"
    echo "   This usually means authentication wasn't copied from host system"
    echo "   Please ensure you have run 'claude auth login' on your host"
    echo "   Then rebuild the container: ./src/claude-docker.sh --rebuild"
    echo "   Your login will be saved for future sessions"
    echo "   CLAUDE_CONFIG_DIR is set to: $CLAUDE_CONFIG_DIR"
fi

# Handle CLAUDE.md template
if [ ! -f "$HOME/.claude/CLAUDE.md" ]; then
    echo "✓ No CLAUDE.md found at $HOME/.claude/CLAUDE.md - copying template"
    # Copy from the template that was baked into the image
    if [ -f "/app/.claude/CLAUDE.md" ]; then
        cp "/app/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    elif [ -f "/home/claude-user/.claude.template/CLAUDE.md" ]; then
        # Fallback for existing images
        cp "/home/claude-user/.claude.template/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    fi
    echo "  Template copied to: $HOME/.claude/CLAUDE.md"
else
    echo "✓ Using existing CLAUDE.md from $HOME/.claude/CLAUDE.md"
    echo "  This maps to: ~/.claude-docker/claude-home/CLAUDE.md on your host"
    echo "  To reset to template, delete this file and restart"
fi

# Verify Twilio MCP configuration
if [ -n "$TWILIO_ACCOUNT_SID" ] && [ -n "$TWILIO_AUTH_TOKEN" ]; then
    echo "✓ Twilio MCP server configured - SMS notifications enabled"
else
    echo "No Twilio credentials found - SMS notifications disabled"
fi

# # Export environment variables from settings.json
# # This is a workaround for Docker container not properly exposing these to Claude
# if [ -f "$HOME/.claude/settings.json" ] && command -v jq >/dev/null 2>&1; then
#     echo "Loading environment variables from settings.json..."
#     # First remove comments from JSON, then extract env vars
#     # Using sed to remove // comments before parsing with jq
#     while IFS='=' read -r key value; do
#         if [ -n "$key" ] && [ -n "$value" ]; then
#             export "$key=$value"
#             echo "  Exported: $key=$value"
#         fi
#     done < <(sed 's://.*$::g' "$HOME/.claude/settings.json" | jq -r '.env // {} | to_entries | .[] | "\(.key)=\(.value)"' 2>/dev/null)
# fi

# Start Claude Code with permissions bypass
echo "Starting Claude Code..."
# Uncomment the line below to use Claude Flow instead
# exec claude-flow "$@"
exec claude $CLAUDE_CONTINUE_FLAG --dangerously-skip-permissions "$@"