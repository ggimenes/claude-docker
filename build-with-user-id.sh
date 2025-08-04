#!/bin/bash
# ABOUTME: Helper script to build claude-docker with matching host user UID/GID
# ABOUTME: This prevents most permission issues with mounted volumes

set -e

echo "🔧 Building claude-docker with your user ID for optimal permissions..."

# Get current user's UID and GID
HOST_UID=$(id -u)
HOST_GID=$(id -g)
HOST_USER=$(whoami)

echo "📋 Host user info:"
echo "   User: $HOST_USER"
echo "   UID: $HOST_UID"
echo "   GID: $HOST_GID"

# Get git configuration for container
GIT_USER_NAME=$(git config --global user.name 2>/dev/null || echo "")
GIT_USER_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
    echo "📋 Git configuration found:"
    echo "   Name: $GIT_USER_NAME"
    echo "   Email: $GIT_USER_EMAIL"
else
    echo "⚠️  No git configuration found. You may want to set:"
    echo "   git config --global user.name 'Your Name'"
    echo "   git config --global user.email 'you@example.com'"
fi

# Build arguments
BUILD_ARGS="--build-arg USER_UID=$HOST_UID --build-arg USER_GID=$HOST_GID"

if [ -n "$GIT_USER_NAME" ]; then
    BUILD_ARGS="$BUILD_ARGS --build-arg GIT_USER_NAME='$GIT_USER_NAME'"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
    BUILD_ARGS="$BUILD_ARGS --build-arg GIT_USER_EMAIL='$GIT_USER_EMAIL'"
fi

echo "🐳 Building Docker image with optimized permissions..."
echo "   Build command: docker build $BUILD_ARGS -t claude-docker ."

# Use eval to properly handle quoted arguments
eval "docker build $BUILD_ARGS -t claude-docker ."

echo "✅ Build completed!"
echo ""
echo "💡 Benefits of building with your user ID:"
echo "   ✓ Files created in mounted volumes will be owned by you"
echo "   ✓ No permission issues when accessing files from host"
echo "   ✓ SQLite databases and config files work seamlessly"
echo ""
echo "🚀 You can now run: docker run -it --rm -v \$(pwd):/workspace claude-docker"