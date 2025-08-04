#!/bin/bash
# ABOUTME: Runtime permission fixer for claude-user in Docker container
# ABOUTME: Handles mounted volumes and ensures claude-user can write everywhere needed
# This script runs as claude-user and uses sudo when needed

set -e

echo "🔧 Checking and fixing runtime permissions for claude-user..."

# Function to safely create directory and set permissions
ensure_writable_dir() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        echo "📁 Creating directory: $dir"
        mkdir -p "$dir" 2>/dev/null || {
            echo "🔐 Using sudo to create: $dir"
            sudo mkdir -p "$dir"
            sudo chown claude-user:claude-user "$dir"
        }
    fi
    
    # Test if we can write to the directory
    if ! touch "$dir/.write_test" 2>/dev/null; then
        echo "🔐 Fixing permissions for: $dir"
        sudo chown -R claude-user:claude-user "$dir" 2>/dev/null || true
        sudo chmod -R 755 "$dir" 2>/dev/null || true
    else
        rm -f "$dir/.write_test"
        echo "✅ Directory $dir is writable"
    fi
}

# Get current user info
echo "📋 Current user: $(whoami), UID: $(id -u), GID: $(id -g)"

# Ensure workspace is writable (this is the mounted volume)
echo "🏠 Ensuring workspace permissions..."
ensure_writable_dir "/workspace"

# Ensure home directory permissions
echo "🏠 Ensuring home directory permissions..."
ensure_writable_dir "/home/claude-user/.claude"
ensure_writable_dir "/home/claude-user/.local"

# Test that we can create the specific directories that claude-flow needs
echo "🧪 Testing dynamic directory creation..."
test_dirs=(
    "/workspace/.hive-mind"
    "/workspace/.plan"
    "/workspace/test-dir-$$"
)

for dir in "${test_dirs[@]}"; do
    if mkdir -p "$dir" 2>/dev/null; then
        echo "✅ Can create: $dir"
        # Clean up test directory
        [[ "$dir" == *"test-dir-"* ]] && rmdir "$dir" 2>/dev/null || true
    else
        echo "⚠️  Cannot create: $dir"
        echo "💡 This may require running docker with --user $(id -u):$(id -g) on the host"
    fi
done

# Verify NPM global packages are accessible
echo "🔍 Verifying NPM global package access..."
if command -v claude >/dev/null 2>&1; then
    echo "✅ Claude CLI is accessible"
else
    echo "⚠️  Claude CLI not found in PATH"
fi

if command -v claude-flow >/dev/null 2>&1; then
    echo "✅ Claude Flow is accessible"
else
    echo "⚠️  Claude Flow not found in PATH"
fi

echo "🎉 Runtime permission check completed!"