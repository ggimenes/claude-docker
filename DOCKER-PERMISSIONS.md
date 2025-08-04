# Docker Permission Solutions for Claude-Docker

This document explains the permission issues you encountered and the solutions implemented, based on Docker best practices and research from the community.

## The Problem

You were experiencing permission errors like:
- `EACCES: permission denied` when claude-user tried to write files
- `attempt to write a readonly database` for SQLite databases
- Files created by Docker owned by `root:root` instead of your user

## Root Cause Analysis

Based on research from [Linux Containers Forum](https://discuss.linuxcontainers.org/t/docker-cant-write-volumes/21651) and [Docker security best practices](https://glebbahmutov.com/blog/docker-user/), the issues stem from:

1. **UID/GID Mismatch**: The `claude-user` (UID 1001) inside the container may not match your host user's UID
2. **Volume Mount Permissions**: Docker volumes retain host filesystem permissions
3. **NPM Global Package Access**: Packages installed as root need special handling for non-root users
4. **Dynamic Directory Creation**: Applications need permission to create directories anywhere in the workspace

## Solutions Implemented

### 1. Flexible User ID Mapping

**What it does**: Allows building the container with your exact host user UID/GID
**Why it works**: Eliminates UID/GID mismatches between container and host

```dockerfile
# Create a non-root user with flexible UID/GID that can match host user
ARG USER_UID=1001
ARG USER_GID=1001
RUN groupadd -g $USER_GID claude-user && \
    useradd -m -s /bin/bash -u $USER_UID -g claude-user claude-user && \
    echo "claude-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "Defaults env_keep += \"HOME\"" >> /etc/sudoers
```

### 2. NPM Global Package Permission Fix

**What it does**: Ensures `claude-user` can access globally installed NPM packages
**Why it works**: Changes ownership of global packages to `claude-user`

```dockerfile
# Fix NPM global package permissions for claude-user
RUN chown -R claude-user:claude-user /usr/local/lib/node_modules \
    && chmod -R 755 /usr/local/lib/node_modules \
    && chown claude-user:claude-user /usr/local/bin/claude* \
    && chmod 755 /usr/local/bin/claude*
```

### 3. Runtime Permission Checker

**What it does**: Automatically fixes permissions when the container starts
**Why it works**: Adapts to actual runtime conditions and mounted volumes

The script `/app/fix-runtime-permissions.sh`:
- Checks if `claude-user` can write to key directories
- Uses `sudo` to fix ownership when needed
- Tests dynamic directory creation capabilities
- Verifies NPM package accessibility

### 4. User-Optimized Build Script

**What it does**: `build-with-user-id.sh` builds the container with your exact UID/GID
**Why it works**: Prevents permission issues entirely by matching container user to host user

```bash
# Usage
./build-with-user-id.sh

# This automatically detects your UID/GID and builds with:
docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t claude-docker .
```

## Best Practices Applied

Based on the community research, these solutions follow Docker security best practices:

1. **Never run as root** - Uses non-root `claude-user` for all operations
2. **Match host permissions** - Aligns container user with host user when possible
3. **Runtime adaptability** - Fixes permissions dynamically at startup
4. **Minimal privilege escalation** - Uses `sudo` only when absolutely necessary
5. **Clear error messages** - Provides actionable feedback on permission issues

## Usage Recommendations

### For Optimal Experience (Recommended)
```bash
# Build with your user ID for seamless permissions
./build-with-user-id.sh

# Run with standard command
docker run -it --rm -v $(pwd):/workspace claude-docker
```

### For Debugging Permission Issues
```bash
# Build with default UID (1001)
docker build -t claude-docker .

# Run and let runtime fixer handle permissions
docker run -it --rm -v $(pwd):/workspace claude-docker
```

### For Manual Permission Control
```bash
# Run with explicit user mapping
docker run -it --rm --user $(id -u):$(id -g) -v $(pwd):/workspace claude-docker
```

## How It Solves Your Original Issues

1. **SQLite Database Errors**: Runtime permission fixer ensures `.hive-mind` directory is writable
2. **File Creation Errors**: Proper UID/GID mapping means files are created with correct ownership
3. **Dynamic Directory Creation**: `claude-user` has sudo access to create directories anywhere needed
4. **NPM Package Access**: Global packages are owned by `claude-user` and fully accessible

## Technical Details

The solution addresses the core Docker volume permission challenge: **mounted volumes retain host filesystem permissions, but container processes run with container user IDs**. 

By either:
- **Matching IDs** (preferred): Container `claude-user` has same UID/GID as host user
- **Runtime fixing** (fallback): Container dynamically adjusts permissions as needed

This ensures `claude-flow`, SQLite databases, and file operations work seamlessly across all scenarios.