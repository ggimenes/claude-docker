# ABOUTME: Docker image for Claude Code with Twilio MCP server
# ABOUTME: Provides autonomous Claude Code environment with SMS notifications

FROM node:23

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3 \
    build-essential \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Astral) for Serena MCP (todo make this modular.)
# Note: Will be installed for claude-user after user creation

# Install additional system packages if specified
ARG SYSTEM_PACKAGES=""
RUN if [ -n "$SYSTEM_PACKAGES" ]; then \
    echo "Installing additional system packages: $SYSTEM_PACKAGES" && \
    apt-get update && \
    apt-get install -y $SYSTEM_PACKAGES && \
    rm -rf /var/lib/apt/lists/*; \
    else \
    echo "No additional system packages specified"; \
    fi

# Create a non-root user with flexible UID/GID that can match host user
ARG USER_UID=1001
ARG USER_GID=1001
RUN groupadd -g $USER_GID claude-user && \
    useradd -m -s /bin/bash -u $USER_UID -g claude-user claude-user && \
    echo "claude-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "Defaults env_keep += \"HOME\"" >> /etc/sudoers

# Create app directory
WORKDIR /app

# Install Claude Code and Claude Flow globally with proper permissions
RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g claude-flow@alpha
# RUN npm install -g claude-flow@2.0.0-alpha.65

# Fix NPM global package permissions for claude-user
RUN chown -R claude-user:claude-user /usr/local/lib/node_modules \
    && chmod -R 755 /usr/local/lib/node_modules \
    && chown claude-user:claude-user /usr/local/bin/claude* \
    && chmod 755 /usr/local/bin/claude*



# Ensure npm global bin is in PATH
ENV PATH="/usr/local/bin:${PATH}"

# Create directories for configuration
RUN mkdir -p /app/.claude /home/claude-user/.claude

# Copy startup and permission scripts
COPY src/startup.sh /app/
COPY src/fix-runtime-permissions.sh /app/
RUN chmod +x /app/startup.sh /app/fix-runtime-permissions.sh

# Copy .claude directory for runtime use
COPY .claude /app/.claude

# Copy .env file during build to bake credentials into the image
# This enables one-time setup - no need for .env in project directories
COPY .env /app/.env

# Copy CLAUDE.md template directly to final location
COPY .claude/CLAUDE.md /home/claude-user/.claude/CLAUDE.md

# Copy Claude authentication files from host if they exist during build
# Authentication files are handled at runtime via volume mounts
# No need to bake them into the image for security reasons

# Copy MCP server configuration files (as root)
COPY mcp-servers.txt /app/
COPY install-mcp-servers.sh /app/
RUN chmod +x /app/install-mcp-servers.sh

# Set proper ownership for everything
RUN chown -R claude-user /app /home/claude-user

# Switch to non-root user
USER claude-user

# Set HOME immediately after switching user
ENV HOME=/home/claude-user

# Set Claude configuration directory to mounted volume location
# This is crucial for Claude Code to find authentication in containers
ENV CLAUDE_CONFIG_DIR=/home/claude-user/.claude

# Install uv (Astral) for claude-user
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Add claude-user's local bin and scripts to PATH and PYTHONPATH
ENV PATH="/home/claude-user/scripts:/home/claude-user/.local/bin:${PATH}"
ENV PYTHONPATH="/home/claude-user/scripts"

# Install MCP servers from configuration file
RUN /app/install-mcp-servers.sh

# Configure git user during build using host git config passed as build args
ARG GIT_USER_NAME=""
ARG GIT_USER_EMAIL=""
RUN if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then \
    echo "Configuring git user from host: $GIT_USER_NAME <$GIT_USER_EMAIL>" && \
    git config --global user.name "$GIT_USER_NAME" && \
    git config --global user.email "$GIT_USER_EMAIL" && \
    echo "Git configuration complete"; \
    else \
    echo "Warning: No git user configured on host system"; \
    echo "Run 'git config --global user.name \"Your Name\"' and 'git config --global user.email \"you@example.com\"' on host first"; \
    fi

# Claude flow will be available globally - no need for npx - init should be don in the desired directory
# RUN claude-flow --help

# Set working directory to mounted volume
WORKDIR /workspace

# Environment variables will be passed from host
ENV NODE_ENV=production

# Start both MCP server and Claude Code
ENTRYPOINT ["/app/startup.sh"]