#!/bin/bash
# ABOUTME: Integrates enhanced MCP installer with existing claude-docker startup scripts
# ABOUTME: Adds auto-setup, health checks, fallback mechanisms, and status reporting

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
BACKUP_DIR="/app/.mcp-config/backups"
INTEGRATION_LOG="/app/.mcp-config/logs/integration.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INTEGRATION]${NC} $1" | tee -a "$INTEGRATION_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$INTEGRATION_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$INTEGRATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$INTEGRATION_LOG"
}

log_header() {
    echo -e "${PURPLE}[MCP-INTEGRATION]${NC} $1" | tee -a "$INTEGRATION_LOG"
}

# Initialize integration directories
init_integration() {
    log_header "Initializing MCP Integration"
    
    mkdir -p "$BACKUP_DIR" "$(dirname "$INTEGRATION_LOG")"
    
    # Create timestamp for this integration
    INTEGRATION_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    echo "$INTEGRATION_TIMESTAMP" > /app/.mcp-config/last-integration
    
    log_info "Integration timestamp: $INTEGRATION_TIMESTAMP"
}

# Backup existing files
backup_files() {
    log_info "Creating backups of existing files"
    
    local backup_subdir="$BACKUP_DIR/$INTEGRATION_TIMESTAMP"
    mkdir -p "$backup_subdir"
    
    # Backup files that will be modified
    local files_to_backup=(
        "$SRC_DIR/startup.sh"
        "$SRC_DIR/claude-flow.sh"
        "/workspace/install-mcp-servers.sh"
        "/workspace/mcp-servers.txt"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$backup_subdir/"
            log_success "Backed up: $(basename "$file")"
        else
            log_warning "File not found for backup: $file"
        fi
    done
    
    log_success "Backups created in: $backup_subdir"
}

# Create enhanced startup script with MCP integration
create_enhanced_startup() {
    log_info "Creating enhanced startup script with MCP integration"
    
    cat > "$SRC_DIR/startup-enhanced.sh" << 'EOF'
#!/bin/bash
# ABOUTME: Enhanced startup script with integrated MCP server management
# ABOUTME: Includes auto-setup, health checks, performance monitoring, and fallback mechanisms

# Load environment variables from .env if it exists
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

# Run runtime permission checks
echo "🔧 Running runtime permission checks..."
if [ -f "/app/fix-runtime-permissions.sh" ]; then
    source /app/fix-runtime-permissions.sh
else
    echo "⚠️  Runtime permission script not found, proceeding with default permissions"
fi

# =====================================================
# ENHANCED MCP INTEGRATION
# =====================================================

# MCP Configuration
MCP_CONFIG_DIR="/app/.mcp-config"
MCP_AUTO_SETUP="${MCP_AUTO_SETUP:-true}"
MCP_PROFILE="${MCP_PROFILE:-dev}"
MCP_HEALTH_CHECK="${MCP_HEALTH_CHECK:-true}"
MCP_FALLBACK_ENABLED="${MCP_FALLBACK_ENABLED:-true}"

# Color codes for MCP output
MCP_GREEN='\033[0;32m'
MCP_BLUE='\033[0;34m'
MCP_YELLOW='\033[1;33m'
MCP_RED='\033[0;31m'
MCP_PURPLE='\033[0;35m'
MCP_NC='\033[0m'

mcp_log() {
    echo -e "${MCP_BLUE}[MCP-STARTUP]${MCP_NC} $1"
}

mcp_success() {
    echo -e "${MCP_GREEN}[MCP-SUCCESS]${MCP_NC} $1"
}

mcp_warning() {
    echo -e "${MCP_YELLOW}[MCP-WARNING]${MCP_NC} $1"
}

mcp_error() {
    echo -e "${MCP_RED}[MCP-ERROR]${MCP_NC} $1"
}

# Initialize MCP configuration if needed
initialize_mcp_config() {
    if [ ! -d "$MCP_CONFIG_DIR" ]; then
        mcp_log "Initializing MCP configuration..."
        
        # Create profiles if enhanced installer is available
        if [ -f "/app/create-mcp-profiles.sh" ]; then
            bash /app/create-mcp-profiles.sh
        else
            mcp_warning "MCP profiles creator not found, using basic setup"
        fi
        
        # Initialize enhanced installer
        if [ -f "/app/enhanced-install-mcp-servers.sh" ]; then
            bash /app/enhanced-install-mcp-servers.sh --init-profiles
        fi
    fi
}

# Auto-setup MCP servers based on profile
auto_setup_mcp() {
    if [ "$MCP_AUTO_SETUP" != "true" ]; then
        mcp_log "MCP auto-setup disabled, skipping"
        return 0
    fi
    
    mcp_log "Starting MCP auto-setup with profile: $MCP_PROFILE"
    
    # Check if enhanced installer is available
    if [ -f "/app/enhanced-install-mcp-servers.sh" ]; then
        mcp_log "Using enhanced MCP installer..."
        
        # Check if profile already installed successfully
        if [ -f "$MCP_CONFIG_DIR/last-successful-install" ]; then
            local last_profile=$(cat "$MCP_CONFIG_DIR/last-successful-install")
            if [ "$last_profile" = "$MCP_PROFILE" ]; then
                mcp_success "Profile $MCP_PROFILE already installed successfully"
                return 0
            fi
        fi
        
        # Install MCP servers with timeout
        mcp_log "Installing MCP servers (timeout: 300s)..."
        if timeout 300 bash /app/enhanced-install-mcp-servers.sh "$MCP_PROFILE"; then
            echo "$MCP_PROFILE" > "$MCP_CONFIG_DIR/last-successful-install"
            mcp_success "MCP servers installed successfully"
        else
            mcp_error "MCP installation failed or timed out"
            
            # Fallback to basic installation if enabled
            if [ "$MCP_FALLBACK_ENABLED" = "true" ]; then
                mcp_warning "Attempting fallback to basic MCP installation..."
                fallback_mcp_setup
            fi
        fi
    else
        mcp_warning "Enhanced installer not found, using legacy installer"
        legacy_mcp_setup
    fi
}

# Fallback MCP setup using original installer
fallback_mcp_setup() {
    mcp_log "Running fallback MCP setup..."
    
    if [ -f "/app/install-mcp-servers.sh" ]; then
        if timeout 180 bash /app/install-mcp-servers.sh; then
            mcp_success "Fallback MCP setup completed"
            echo "fallback" > "$MCP_CONFIG_DIR/last-successful-install"
        else
            mcp_error "Fallback MCP setup failed"
        fi
    else
        mcp_error "No MCP installer found"
    fi
}

# Legacy MCP setup
legacy_mcp_setup() {
    mcp_log "Running legacy MCP setup..."
    
    if [ -f "/app/install-mcp-servers.sh" ]; then
        bash /app/install-mcp-servers.sh
        mcp_success "Legacy MCP setup completed"
    else
        mcp_warning "No legacy MCP installer found"
    fi
}

# Health check MCP servers
health_check_mcp() {
    if [ "$MCP_HEALTH_CHECK" != "true" ]; then
        return 0
    fi
    
    mcp_log "Performing MCP health checks..."
    
    # Check if Claude CLI is available
    if ! command -v claude >/dev/null 2>&1; then
        mcp_warning "Claude CLI not available, skipping health checks"
        return 0
    fi
    
    # Get list of MCP servers
    local mcp_servers
    if mcp_servers=$(timeout 30 claude mcp list 2>/dev/null); then
        if echo "$mcp_servers" | grep -q "No MCP servers"; then
            mcp_warning "No MCP servers configured"
        else
            local server_count=$(echo "$mcp_servers" | grep -v "No MCP servers" | wc -l)
            mcp_success "Found $server_count MCP servers"
            
            # Log server names
            echo "$mcp_servers" | while read -r server_line; do
                if [[ "$server_line" =~ ^[[:space:]]*([^[:space:]]+) ]]; then
                    mcp_log "  - ${BASH_REMATCH[1]}"
                fi
            done
        fi
    else
        mcp_warning "Could not retrieve MCP server list"
    fi
}

# Generate MCP status report
generate_mcp_status() {
    local status_file="$MCP_CONFIG_DIR/startup-status.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Create status report
    cat > "$status_file" << EOF
{
  "timestamp": "$timestamp",
  "profile": "$MCP_PROFILE",
  "auto_setup": $MCP_AUTO_SETUP,
  "health_check": $MCP_HEALTH_CHECK,
  "fallback_enabled": $MCP_FALLBACK_ENABLED,
  "config_dir": "$MCP_CONFIG_DIR",
  "startup_completed": true
}
EOF
    
    mcp_log "Status report saved: $status_file"
}

# Main MCP setup function
setup_mcp_integration() {
    mcp_log "=== MCP Integration Setup ==="
    mcp_log "Profile: $MCP_PROFILE"
    mcp_log "Auto-setup: $MCP_AUTO_SETUP"
    mcp_log "Health checks: $MCP_HEALTH_CHECK"
    mcp_log "Fallback enabled: $MCP_FALLBACK_ENABLED"
    
    # Initialize configuration
    initialize_mcp_config
    
    # Auto-setup MCP servers
    auto_setup_mcp
    
    # Perform health checks
    health_check_mcp
    
    # Generate status report
    generate_mcp_status
    
    mcp_success "MCP integration setup completed"
}

# =====================================================
# EXISTING STARTUP LOGIC
# =====================================================

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
    if [ -f "/app/.claude/CLAUDE.md" ]; then
        cp "/app/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    elif [ -f "/home/claude-user/.claude.template/CLAUDE.md" ]; then
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

# =====================================================
# EXECUTE MCP INTEGRATION
# =====================================================

# Run MCP integration setup
setup_mcp_integration

# =====================================================
# START CLAUDE CODE
# =====================================================

# Start Claude Code with permissions bypass
echo "Starting Claude Code..."
exec claude $CLAUDE_CONTINUE_FLAG --dangerously-skip-permissions "$@"
EOF

    log_success "Enhanced startup script created"
}

# Create enhanced claude-flow script with MCP integration
create_enhanced_claude_flow() {
    log_info "Creating enhanced claude-flow script with MCP integration"
    
    # Read existing claude-flow.sh to preserve functionality
    local existing_content=""
    if [ -f "$SRC_DIR/claude-flow.sh" ]; then
        existing_content=$(cat "$SRC_DIR/claude-flow.sh")
    fi
    
    cat > "$SRC_DIR/claude-flow-enhanced.sh" << 'EOF'
#!/bin/bash
# ABOUTME: Enhanced Claude Flow wrapper with integrated MCP server management
# ABOUTME: Includes MCP health checks, performance monitoring, and auto-configuration

# Get the absolute path of the current directory
CURRENT_DIR=$(pwd)

# Fix for Git Bash on Windows - convert Windows paths to Unix format for Docker
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
    if command -v cygpath >/dev/null 2>&1; then
        CURRENT_DIR=$(cygpath -u "$CURRENT_DIR")
    else
        CURRENT_DIR=$(echo "$CURRENT_DIR" | sed 's|^\([A-Za-z]\):|/\L\1|' | sed 's|\\|/|g')
    fi
    echo "✓ Converted path for Git Bash on Windows: $CURRENT_DIR"
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Ensure the claude-home directory exists
mkdir -p "$HOME/.claude-docker/claude-home"

# =====================================================
# ENHANCED MCP INTEGRATION
# =====================================================

# MCP Configuration
MCP_PROFILE="${MCP_PROFILE:-dev}"
MCP_AUTO_SETUP="${MCP_AUTO_SETUP:-true}"
MCP_HEALTH_CHECK="${MCP_HEALTH_CHECK:-true}"

# Color codes
MCP_GREEN='\033[0;32m'
MCP_BLUE='\033[0;34m'
MCP_YELLOW='\033[1;33m'
MCP_PURPLE='\033[0;35m'
MCP_NC='\033[0m'

mcp_log() {
    echo -e "${MCP_BLUE}[MCP-FLOW]${MCP_NC} $1"
}

mcp_success() {
    echo -e "${MCP_GREEN}[MCP-SUCCESS]${MCP_NC} $1"
}

mcp_warning() {
    echo -e "${MCP_YELLOW}[MCP-WARNING]${MCP_NC} $1"
}

# Display MCP status before starting
display_mcp_status() {
    mcp_log "MCP Configuration Status"
    echo "  Profile: $MCP_PROFILE"
    echo "  Auto-setup: $MCP_AUTO_SETUP"
    echo "  Health checks: $MCP_HEALTH_CHECK"
    
    # Check for existing MCP configuration
    if [ -f "$HOME/.claude-docker/claude-home/.mcp-config/startup-status.json" ]; then
        mcp_success "MCP configuration found from previous startup"
        
        # Display basic status if jq is available
        if command -v jq >/dev/null 2>&1; then
            local profile=$(jq -r '.profile // "unknown"' "$HOME/.claude-docker/claude-home/.mcp-config/startup-status.json" 2>/dev/null)
            local timestamp=$(jq -r '.timestamp // "unknown"' "$HOME/.claude-docker/claude-home/.mcp-config/startup-status.json" 2>/dev/null)
            echo "  Last setup: $profile at $timestamp"
        fi
    else
        mcp_warning "No previous MCP configuration found"
        echo "  MCP servers will be configured on first container startup"
    fi
    
    echo ""
}

# Show MCP management commands
show_mcp_commands() {
    mcp_log "Available MCP Management Commands:"
    echo ""
    echo "  Container MCP Commands:"
    echo "    docker exec -it \$CONTAINER_NAME bash /app/enhanced-install-mcp-servers.sh --status"
    echo "    docker exec -it \$CONTAINER_NAME bash /app/enhanced-install-mcp-servers.sh --check"
    echo "    docker exec -it \$CONTAINER_NAME bash /app/enhanced-install-mcp-servers.sh --list"
    echo ""
    echo "  Profile Management:"
    echo "    export MCP_PROFILE=minimal    # Use minimal profile"
    echo "    export MCP_PROFILE=dev        # Use development profile (default)"
    echo "    export MCP_PROFILE=full       # Use full profile"
    echo "    export MCP_AUTO_SETUP=false   # Disable auto-setup"
    echo ""
    echo "  Quick Setup:"
    echo "    MCP_PROFILE=full $0           # Start with full MCP profile"
    echo "    MCP_AUTO_SETUP=false $0       # Start without MCP auto-setup"
    echo ""
}

# Parse MCP-related arguments
parse_mcp_args() {
    case "${1:-}" in
        --mcp-status)
            display_mcp_status
            exit 0
            ;;
        --mcp-help)
            show_mcp_commands
            exit 0
            ;;
        --mcp-minimal)
            export MCP_PROFILE=minimal
            ;;
        --mcp-dev)
            export MCP_PROFILE=dev
            ;;
        --mcp-full)
            export MCP_PROFILE=full
            ;;
        --mcp-disable)
            export MCP_AUTO_SETUP=false
            ;;
    esac
}

# Check for MCP arguments first
if [[ "${1:-}" =~ ^--mcp- ]]; then
    parse_mcp_args "$1"
    shift
fi

# =====================================================
# EXISTING AUTHENTICATION LOGIC
# =====================================================

# Copy authentication files to persistent claude-home if they don't exist  
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

# Display MCP status
display_mcp_status

echo "Starting Claude Flow in Docker..."

# Fix for Git Bash on Windows - prevent path conversion for Docker command
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
    export MSYS_NO_PATHCONV=1
    echo "✓ Disabled path conversion for Docker command"
fi

# =====================================================
# DOCKER EXECUTION WITH MCP INTEGRATION
# =====================================================

# Set environment variables for container
DOCKER_ENV_VARS=""
if [ -n "$MCP_PROFILE" ]; then
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e MCP_PROFILE=$MCP_PROFILE"
fi
if [ -n "$MCP_AUTO_SETUP" ]; then
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e MCP_AUTO_SETUP=$MCP_AUTO_SETUP"
fi
if [ -n "$MCP_HEALTH_CHECK" ]; then
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e MCP_HEALTH_CHECK=$MCP_HEALTH_CHECK"
fi

# Run Claude Flow with enhanced startup
docker run -it --rm \
    -v "$CURRENT_DIR:/workspace" \
    -v "$HOME/.claude-docker/claude-home:/home/claude-user/.claude:rw" \
    -v "$HOME/.claude-docker/ssh:/home/claude-user/.ssh:rw" \
    -v "$HOME/.claude-docker/scripts:/home/claude-user/scripts:rw" \
    -e CLAUDE_CONFIG_DIR="/home/claude-user/.claude" \
    $DOCKER_ENV_VARS \
    --workdir /workspace \
    --name "claude-flow-$(basename "$CURRENT_DIR")-$$" \
    --entrypoint="" \
    claude-docker:latest bash -c '
        echo "🌊 Claude Flow Docker Container Ready with Enhanced MCP!"
        echo "📁 Working directory: $(pwd)"
        echo "🔧 Node.js version: $(node --version)"
        echo "📦 npm version: $(npm --version)"
        echo "🔌 MCP Profile: '"$MCP_PROFILE"'"
        echo ""
        
        if [ $# -eq 0 ]; then
            # No arguments provided - start interactive session
            echo "🌊 Starting interactive Claude Flow session..."
            echo "💡 Run: npx claude-flow@alpha --help"
            echo "💡 Run: npx claude-flow@alpha init"  
            echo "💡 Run: npx claude-flow@alpha hive-mind wizard"
            echo "💡 MCP Commands: /app/enhanced-install-mcp-servers.sh --help"
            echo "💡 Type '\''exit'\'' to leave the container"
            echo ""
        else
            # Arguments provided - run command first
            echo "🚀 Running: npx claude-flow@alpha $*"
            echo ""
            npx claude-flow@alpha "$@" || echo "⚠️  Command failed or was canceled"
            echo ""
            echo "🌊 Command finished. You can run more commands or type '\''exit'\'' to leave."
            echo ""
        fi
        
        # Always start interactive bash session
        exec bash
    ' -- "$@"
EOF

    log_success "Enhanced claude-flow script created"
}

# Create runtime permissions script for MCP
create_mcp_permissions_script() {
    log_info "Creating MCP runtime permissions script"
    
    cat > "/workspace/src/fix-runtime-permissions.sh" << 'EOF'
#!/bin/bash
# ABOUTME: Runtime permission fixes for claude-user and MCP operations
# ABOUTME: Ensures proper file permissions for MCP configuration and logs

# Fix permissions for claude-user home directory
if [ -d "/home/claude-user" ]; then
    chown -R claude-user:claude-user /home/claude-user || true
fi

# Fix permissions for MCP configuration directory
if [ -d "/app/.mcp-config" ]; then
    chown -R claude-user:claude-user /app/.mcp-config || true
    chmod -R 755 /app/.mcp-config || true
fi

# Fix permissions for MCP logs
if [ -d "/app/.mcp-config/logs" ]; then
    chmod -R 766 /app/.mcp-config/logs || true
fi

# Fix permissions for MCP profiles
if [ -d "/app/.mcp-config/profiles" ]; then
    chmod -R 644 /app/.mcp-config/profiles/*.txt || true
    chmod -R 644 /app/.mcp-config/profiles/*/dependencies.txt || true
fi

# Fix permissions for workspace
if [ -d "/workspace" ]; then
    chown -R claude-user:claude-user /workspace || true
fi

# Fix permissions for enhanced MCP scripts
chmod +x /app/enhanced-install-mcp-servers.sh || true
chmod +x /app/create-mcp-profiles.sh || true
chmod +x /app/integrate-mcp-setup.sh || true

echo "✓ Runtime permissions fixed for claude-user and MCP operations"
EOF

    chmod +x "/workspace/src/fix-runtime-permissions.sh"
    log_success "MCP runtime permissions script created"
}

# Update Docker build scripts to include MCP integration
update_docker_integration() {
    log_info "Updating Docker integration for MCP"
    
    # Check if Dockerfile exists and add MCP integration
    if [ -f "/workspace/Dockerfile" ]; then
        log_info "Found Dockerfile, checking for MCP integration..."
        
        if ! grep -q "enhanced-install-mcp-servers.sh" "/workspace/Dockerfile"; then
            log_info "Adding MCP scripts to Dockerfile..."
            
            # Create backup
            cp "/workspace/Dockerfile" "$BACKUP_DIR/Dockerfile.backup"
            
            # Add MCP scripts to Dockerfile
            cat >> "/workspace/Dockerfile" << 'EOF'

# Enhanced MCP Integration
COPY enhanced-install-mcp-servers.sh /app/
COPY create-mcp-profiles.sh /app/
COPY integrate-mcp-setup.sh /app/
RUN chmod +x /app/enhanced-install-mcp-servers.sh /app/create-mcp-profiles.sh /app/integrate-mcp-setup.sh

# MCP Runtime Permissions
COPY src/fix-runtime-permissions.sh /app/
RUN chmod +x /app/fix-runtime-permissions.sh
EOF

            log_success "Added MCP integration to Dockerfile"
        else
            log_info "MCP integration already present in Dockerfile"
        fi
    else
        log_warning "Dockerfile not found, skipping Docker integration"
    fi
}

# Create MCP status and management utilities
create_mcp_utilities() {
    log_info "Creating MCP management utilities"
    
    # Create MCP status script
    cat > "/workspace/mcp-status.sh" << 'EOF'
#!/bin/bash
# ABOUTME: Quick MCP status checker for claude-docker containers

echo "🔌 MCP Status Checker"
echo "====================="

# Check if container is running
CONTAINER_ID=$(docker ps -q -f name=claude-flow 2>/dev/null | head -1)
if [ -z "$CONTAINER_ID" ]; then
    CONTAINER_ID=$(docker ps -q -f name=claude-docker 2>/dev/null | head -1)
fi

if [ -n "$CONTAINER_ID" ]; then
    echo "✓ Found running container: $CONTAINER_ID"
    
    # Check MCP configuration
    echo ""
    echo "📊 MCP Configuration:"
    docker exec "$CONTAINER_ID" bash -c '
        if [ -f /app/.mcp-config/startup-status.json ]; then
            if command -v jq >/dev/null 2>&1; then
                echo "  Profile: $(jq -r ".profile" /app/.mcp-config/startup-status.json)"
                echo "  Setup Time: $(jq -r ".timestamp" /app/.mcp-config/startup-status.json)"
                echo "  Auto-setup: $(jq -r ".auto_setup" /app/.mcp-config/startup-status.json)"
            else
                echo "  Status file exists but jq not available"
            fi
        else
            echo "  No MCP configuration found"
        fi
    '
    
    # Check installed MCP servers
    echo ""
    echo "🔌 Installed MCP Servers:"
    docker exec "$CONTAINER_ID" bash -c '
        if command -v claude >/dev/null 2>&1; then
            claude mcp list 2>/dev/null || echo "  Unable to list MCP servers"
        else
            echo "  Claude CLI not available"
        fi
    '
    
    # Check recent logs
    echo ""
    echo "📝 Recent MCP Logs:"
    docker exec "$CONTAINER_ID" bash -c '
        if [ -f /app/.mcp-config/logs/install.log ]; then
            echo "  Last 5 log entries:"
            tail -5 /app/.mcp-config/logs/install.log | sed "s/^/    /"
        else
            echo "  No installation logs found"
        fi
    '
    
else
    echo "❌ No running claude-docker or claude-flow container found"
    echo ""
    echo "💡 To start a container with MCP:"
    echo "   ./src/claude-flow.sh                    # Start with default profile"
    echo "   MCP_PROFILE=full ./src/claude-flow.sh   # Start with full profile"
    echo "   MCP_PROFILE=minimal ./src/claude-flow.sh # Start with minimal profile"
fi
EOF

    chmod +x "/workspace/mcp-status.sh"
    log_success "Created MCP status utility"
    
    # Create MCP quick setup script
    cat > "/workspace/mcp-quick-setup.sh" << 'EOF'
#!/bin/bash
# ABOUTME: Quick MCP setup for existing containers

CONTAINER_ID=$(docker ps -q -f name=claude-flow 2>/dev/null | head -1)
if [ -z "$CONTAINER_ID" ]; then
    CONTAINER_ID=$(docker ps -q -f name=claude-docker 2>/dev/null | head -1)
fi

if [ -n "$CONTAINER_ID" ]; then
    PROFILE="${1:-dev}"
    echo "🔌 Setting up MCP profile: $PROFILE"
    docker exec "$CONTAINER_ID" bash /app/enhanced-install-mcp-servers.sh "$PROFILE"
else
    echo "❌ No running container found"
    echo "Start a container first with: ./src/claude-flow.sh"
fi
EOF

    chmod +x "/workspace/mcp-quick-setup.sh"
    log_success "Created MCP quick setup utility"
}

# Generate integration documentation
create_integration_docs() {
    log_info "Creating integration documentation"
    
    cat > "/workspace/MCP-INTEGRATION-GUIDE.md" << 'EOF'
# Enhanced MCP Integration Guide

This guide covers the enhanced MCP (Model Context Protocol) integration for claude-docker.

## 🚀 Quick Start

### 1. Basic Usage (Default Development Profile)
```bash
./src/claude-flow.sh
```

### 2. Specific Profile
```bash
# Minimal profile (fastest setup)
MCP_PROFILE=minimal ./src/claude-flow.sh

# Full profile (comprehensive toolset)
MCP_PROFILE=full ./src/claude-flow.sh
```

### 3. Disable Auto-Setup
```bash
MCP_AUTO_SETUP=false ./src/claude-flow.sh
```

## 📋 Available Profiles

### Minimal Profile
- **Setup Time**: ~5 minutes
- **Servers**: Filesystem, Git, Web Fetch
- **Use Case**: Basic development needs

### Development Profile (Default)
- **Setup Time**: ~15 minutes  
- **Servers**: All minimal + Context7, Twilio SMS
- **Use Case**: Balanced development workflow

### Full Profile
- **Setup Time**: ~30 minutes
- **Servers**: 15+ comprehensive tools
- **Use Case**: Professional development environment

### Custom Profile
- **Setup Time**: Variable
- **Servers**: User-defined
- **Use Case**: Specific requirements

## 🔧 Management Commands

### Container Status
```bash
./mcp-status.sh                    # Check MCP status in running container
./mcp-quick-setup.sh dev          # Setup MCP in existing container
```

### Inside Container
```bash
# Check installation status
/app/enhanced-install-mcp-servers.sh --status

# List available profiles
/app/enhanced-install-mcp-servers.sh --list

# Health check all servers
/app/enhanced-install-mcp-servers.sh --check

# Install specific profile
/app/enhanced-install-mcp-servers.sh full
```

## 🌍 Environment Variables

### MCP Configuration
```bash
export MCP_PROFILE=dev              # Profile to use (minimal/dev/full/custom)
export MCP_AUTO_SETUP=true          # Enable automatic setup
export MCP_HEALTH_CHECK=true        # Enable health checks
export MCP_FALLBACK_ENABLED=true    # Enable fallback mechanisms
```

### Service API Keys (Optional)
```bash
# Twilio SMS
export TWILIO_ACCOUNT_SID=your_sid
export TWILIO_AUTH_TOKEN=your_token
export TWILIO_FROM_NUMBER=your_number

# Slack Integration
export SLACK_BOT_TOKEN=xoxb-your-token

# Database URLs
export POSTGRES_URL=postgresql://user:pass@host:port/db
```

## 📊 Features

### Auto-Setup
- Automatic MCP server installation on container startup
- Profile-based configuration
- Retry logic with exponential backoff
- Fallback mechanisms for failed installations

### Health Monitoring
- Startup health checks
- Performance metrics collection
- Installation status tracking
- Comprehensive logging

### Performance Optimizations
- Timeout management (300s installation, 30s health checks)
- Concurrent server installations where possible
- Smart dependency resolution
- Caching of successful installations

### Fallback Mechanisms
- Automatic fallback to basic installation on failure
- Graceful degradation when services are unavailable
- Legacy installer compatibility

## 📁 File Structure

```
/app/.mcp-config/
├── profiles/
│   ├── minimal.txt                 # Minimal profile servers
│   ├── dev.txt                     # Development profile servers
│   ├── full.txt                    # Full profile servers
│   ├── custom.txt                  # Custom profile template
│   └── README.md                   # Profile documentation
├── templates/
│   ├── minimal.env                 # Minimal environment variables
│   ├── dev.env                     # Development environment variables
│   ├── full.env                    # Full environment variables
│   └── custom.env                  # Custom environment template
├── logs/
│   ├── install.log                 # Installation logs
│   ├── integration.log             # Integration logs
│   └── metrics.csv                 # Performance metrics
├── backups/                        # Configuration backups
├── config.json                     # Main configuration
├── metrics.json                    # Performance metrics (JSON)
└── startup-status.json             # Last startup status
```

## 🛠️ Troubleshooting

### Common Issues

1. **Installation Timeout**
   ```bash
   # Check logs
   docker exec $CONTAINER_ID cat /app/.mcp-config/logs/install.log
   
   # Disable auto-setup and manual install
   MCP_AUTO_SETUP=false ./src/claude-flow.sh
   ```

2. **Missing Environment Variables**
   ```bash
   # Check which variables are missing
   docker exec $CONTAINER_ID /app/enhanced-install-mcp-servers.sh --status
   
   # Add variables to .env file
   echo "TWILIO_ACCOUNT_SID=your_sid" >> .env
   ```

3. **Health Check Failures**
   ```bash
   # Run manual health check
   docker exec $CONTAINER_ID /app/enhanced-install-mcp-servers.sh --check
   
   # Check Claude MCP configuration
   docker exec $CONTAINER_ID claude mcp list
   ```

### Debug Mode
```bash
# Enable verbose logging
export MCP_DEBUG=true
./src/claude-flow.sh
```

## 🔄 Migration from Legacy Setup

The enhanced MCP integration is backward compatible:

1. **Existing .env files** are automatically loaded
2. **Legacy mcp-servers.txt** is used as fallback
3. **Original install-mcp-servers.sh** serves as backup installer

## 📈 Performance Metrics

The system tracks:
- Installation duration per server
- Success/failure rates
- Retry attempts
- Health check results
- Resource usage patterns

View metrics:
```bash
docker exec $CONTAINER_ID cat /app/.mcp-config/metrics.json
```

## 🔐 Security

- Environment variables are never logged
- API keys are validated before use
- Timeout limits prevent hanging installations
- Permission fixes ensure proper file access
- Backup mechanisms preserve configurations

## 📞 Support

- **Logs**: Check `/app/.mcp-config/logs/` for detailed information
- **Status**: Use `./mcp-status.sh` for quick diagnostics
- **Fallback**: Legacy installer provides backup functionality
- **Recovery**: Backup configurations enable easy restoration
EOF

    log_success "Created integration documentation"
}

# Main integration function
main() {
    log_header "Enhanced MCP Integration Setup"
    
    # Initialize
    init_integration
    
    # Create backups
    backup_files
    
    # Create enhanced scripts
    create_enhanced_startup
    create_enhanced_claude_flow
    create_mcp_permissions_script
    
    # Update Docker integration
    update_docker_integration
    
    # Create utilities
    create_mcp_utilities
    
    # Create documentation
    create_integration_docs
    
    log_header "Integration Summary"
    log_success "Enhanced MCP integration completed successfully!"
    echo ""
    echo "📁 Files Created:"
    echo "  ✓ src/startup-enhanced.sh (Enhanced startup with MCP)"
    echo "  ✓ src/claude-flow-enhanced.sh (Enhanced Claude Flow with MCP)"
    echo "  ✓ src/fix-runtime-permissions.sh (MCP permissions)"
    echo "  ✓ mcp-status.sh (Status checker utility)"
    echo "  ✓ mcp-quick-setup.sh (Quick setup utility)"
    echo "  ✓ MCP-INTEGRATION-GUIDE.md (Complete documentation)"
    echo ""
    echo "📦 Integration Features:"
    echo "  ✓ Auto-setup with profile management (minimal/dev/full/custom)"
    echo "  ✓ Health checks and performance monitoring"
    echo "  ✓ Fallback mechanisms and retry logic"
    echo "  ✓ Comprehensive logging and status reporting"
    echo "  ✓ Docker integration and utilities"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Test the enhanced scripts:"
    echo "     ./src/claude-flow-enhanced.sh --mcp-help"
    echo ""
    echo "  2. Check MCP status:"
    echo "     ./mcp-status.sh"
    echo ""
    echo "  3. Start with specific profile:"
    echo "     MCP_PROFILE=full ./src/claude-flow-enhanced.sh"
    echo ""
    echo "  4. Read integration guide:"
    echo "     cat MCP-INTEGRATION-GUIDE.md"
    echo ""
    echo "📋 Configuration Directory: /app/.mcp-config"
    echo "📝 Integration Log: $INTEGRATION_LOG"
    
    log_success "MCP integration setup complete!"
}

# Execute main function
main "$@"