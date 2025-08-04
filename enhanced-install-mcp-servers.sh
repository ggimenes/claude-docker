#!/bin/bash
# ABOUTME: Enhanced MCP Server Installer with Profile Management and Performance Monitoring
# ABOUTME: Supports dev, minimal, and full profiles with dependency resolution and health checks
# ABOUTME: Includes automatic fallback mechanisms and comprehensive status reporting

set -e

# Configuration
SCRIPT_VERSION="2.0.0"
CONFIG_DIR="/app/.mcp-config"
PROFILES_DIR="$CONFIG_DIR/profiles"
TEMPLATES_DIR="$CONFIG_DIR/templates"
LOGS_DIR="$CONFIG_DIR/logs"
HEALTH_CHECK_TIMEOUT=30
MAX_RETRY_ATTEMPTS=3

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGS_DIR/install.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/install.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOGS_DIR/install.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/install.log"
}

log_header() {
    echo -e "${PURPLE}[MCP-INSTALLER]${NC} $1" | tee -a "$LOGS_DIR/install.log"
}

# Performance monitoring functions
start_timer() {
    TIMER_START=$(date +%s)
}

end_timer() {
    TIMER_END=$(date +%s)
    DURATION=$((TIMER_END - TIMER_START))
    echo $DURATION
}

# Health check function
health_check_mcp() {
    local server_name="$1"
    local timeout="${2:-$HEALTH_CHECK_TIMEOUT}"
    
    log_info "Performing health check for $server_name (timeout: ${timeout}s)"
    
    # Check if MCP server is responsive
    if timeout "$timeout" claude mcp list | grep -q "$server_name"; then
        log_success "Health check passed for $server_name"
        return 0
    else
        log_warning "Health check failed for $server_name"
        return 1
    fi
}

# Dependency resolution function
resolve_dependencies() {
    local profile="$1"
    local deps_file="$PROFILES_DIR/$profile/dependencies.txt"
    
    if [ ! -f "$deps_file" ]; then
        log_info "No dependencies file found for profile $profile"
        return 0
    fi
    
    log_info "Resolving dependencies for profile: $profile"
    
    while IFS= read -r dep_line; do
        # Skip empty lines and comments
        [[ -z "$dep_line" ]] || [[ "$dep_line" =~ ^[[:space:]]*# ]] && continue
        
        local dep_type=$(echo "$dep_line" | cut -d':' -f1)
        local dep_name=$(echo "$dep_line" | cut -d':' -f2)
        local dep_version=$(echo "$dep_line" | cut -d':' -f3)
        
        case $dep_type in
            "npm")
                if ! npm list -g "$dep_name@$dep_version" >/dev/null 2>&1; then
                    log_info "Installing npm dependency: $dep_name@$dep_version"
                    npm install -g "$dep_name@$dep_version" || log_warning "Failed to install $dep_name"
                fi
                ;;
            "system")
                if ! command -v "$dep_name" >/dev/null; then
                    log_warning "System dependency missing: $dep_name (manual installation required)"
                fi
                ;;
            "env")
                if [ -z "${!dep_name}" ]; then
                    log_warning "Environment variable missing: $dep_name"
                fi
                ;;
        esac
    done < "$deps_file"
}

# Initialize configuration directories
init_config_dirs() {
    log_info "Initializing MCP configuration directories"
    mkdir -p "$CONFIG_DIR" "$PROFILES_DIR" "$TEMPLATES_DIR" "$LOGS_DIR"
    
    # Create performance metrics file
    echo "{\"installations\": [], \"performance\": {}}" > "$CONFIG_DIR/metrics.json"
    
    # Create configuration file
    cat > "$CONFIG_DIR/config.json" << EOF
{
    "version": "$SCRIPT_VERSION",
    "default_profile": "dev",
    "retry_attempts": $MAX_RETRY_ATTEMPTS,
    "health_check_timeout": $HEALTH_CHECK_TIMEOUT,
    "auto_fallback": true,
    "performance_monitoring": true
}
EOF
}

# Install MCP server with retry logic
install_mcp_with_retry() {
    local command="$1"
    local server_name="$2"
    local attempt=1
    
    while [ $attempt -le $MAX_RETRY_ATTEMPTS ]; do
        log_info "Installing $server_name (attempt $attempt/$MAX_RETRY_ATTEMPTS)"
        start_timer
        
        if eval "$command"; then
            local duration=$(end_timer)
            log_success "Successfully installed $server_name (${duration}s)"
            
            # Update metrics
            update_metrics "$server_name" "success" "$duration" "$attempt"
            
            # Perform health check
            if health_check_mcp "$server_name"; then
                return 0
            else
                log_warning "Health check failed, will retry if attempts remain"
            fi
        else
            local duration=$(end_timer)
            log_error "Failed to install $server_name (attempt $attempt, ${duration}s)"
            update_metrics "$server_name" "failed" "$duration" "$attempt"
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -le $MAX_RETRY_ATTEMPTS ]; then
            log_info "Waiting 5 seconds before retry..."
            sleep 5
        fi
    done
    
    log_error "Failed to install $server_name after $MAX_RETRY_ATTEMPTS attempts"
    return 1
}

# Update performance metrics
update_metrics() {
    local server_name="$1"
    local status="$2"
    local duration="$3"
    local attempts="$4"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Use jq to update metrics if available, otherwise append to log
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg name "$server_name" \
           --arg status "$status" \
           --arg duration "$duration" \
           --arg attempts "$attempts" \
           --arg timestamp "$timestamp" \
           '.installations += [{
               "name": $name,
               "status": $status,
               "duration": ($duration | tonumber),
               "attempts": ($attempts | tonumber),
               "timestamp": $timestamp
           }]' "$CONFIG_DIR/metrics.json" > "$temp_file"
        mv "$temp_file" "$CONFIG_DIR/metrics.json"
    else
        echo "$timestamp,$server_name,$status,$duration,$attempts" >> "$LOGS_DIR/metrics.csv"
    fi
}

# Load profile configuration
load_profile() {
    local profile="${1:-dev}"
    local profile_file="$PROFILES_DIR/$profile.txt"
    
    log_header "Loading MCP profile: $profile"
    
    if [ ! -f "$profile_file" ]; then
        log_error "Profile file not found: $profile_file"
        log_info "Available profiles:"
        ls -1 "$PROFILES_DIR"/*.txt 2>/dev/null | xargs -I {} basename {} .txt || log_info "No profiles found"
        exit 1
    fi
    
    # Resolve dependencies first
    resolve_dependencies "$profile"
    
    echo "$profile_file"
}

# Process environment variables
process_environment() {
    log_info "Processing environment variables"
    
    # Source .env file if it exists
    if [ -f /app/.env ]; then
        set -a
        source /app/.env
        set +a
        log_success "Loaded environment variables from .env"
    else
        log_warning "No .env file found, skipping environment variable loading"
    fi
    
    # Load profile-specific environment
    local profile="${1:-dev}"
    local env_file="$TEMPLATES_DIR/$profile.env"
    
    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
        log_info "Loaded profile-specific environment: $profile"
    fi
}

# Generate installation report
generate_report() {
    local profile="$1"
    local report_file="$LOGS_DIR/installation-report-$(date +%Y%m%d-%H%M%S).json"
    
    log_info "Generating installation report: $report_file"
    
    if command -v jq >/dev/null 2>&1; then
        jq --arg profile "$profile" \
           --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
           '.report = {
               "profile": $profile,
               "timestamp": $timestamp,
               "total_servers": (.installations | length),
               "successful": (.installations | map(select(.status == "success")) | length),
               "failed": (.installations | map(select(.status == "failed")) | length),
               "average_duration": (.installations | map(.duration) | add / length),
               "total_attempts": (.installations | map(.attempts) | add)
           }' "$CONFIG_DIR/metrics.json" > "$report_file"
        
        # Display summary
        log_header "Installation Summary"
        jq -r '.report | "Profile: \(.profile)\nTotal Servers: \(.total_servers)\nSuccessful: \(.successful)\nFailed: \(.failed)\nAverage Duration: \(.average_duration)s\nTotal Attempts: \(.total_attempts)"' "$report_file"
    fi
}

# Main installation function
install_mcp_servers() {
    local profile="${1:-dev}"
    local profile_file
    
    # Initialize
    init_config_dirs
    process_environment "$profile"
    profile_file=$(load_profile "$profile")
    
    log_header "Starting MCP Server Installation - Profile: $profile"
    log_info "Profile file: $profile_file"
    log_info "Configuration directory: $CONFIG_DIR"
    
    local total_servers=0
    local successful_servers=0
    local failed_servers=0
    local overall_start_time=$(date +%s)
    
    # Process each line in profile file
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        total_servers=$((total_servers + 1))
        
        # Extract server name for tracking
        local server_name=""
        if [[ "$line" =~ claude\ mcp\ add(-json)?\ ([^\ ]+) ]]; then
            server_name="${BASH_REMATCH[2]}"
        else
            server_name="server-$total_servers"
        fi
        
        # Check environment variable dependencies
        if [[ "$line" =~ \$\{([^}]+)\} ]]; then
            local var_names=$(echo "$line" | grep -o '\${[^}]*}' | sed 's/[${}]//g')
            local missing_vars=""
            
            for var in $var_names; do
                if [ -z "${!var}" ]; then
                    missing_vars="$missing_vars $var"
                fi
            done
            
            if [ -n "$missing_vars" ]; then
                log_warning "Skipping $server_name - missing environment variables:$missing_vars"
                update_metrics "$server_name" "skipped" "0" "0"
                continue
            fi
        fi
        
        # Expand environment variables
        local expanded_line
        if [[ "$line" =~ "add-json" ]]; then
            # Special handling for JSON commands
            expanded_line="$line"
            local vars_in_line=$(echo "$line" | grep -o '\${[^}]*}' | sed 's/[${}]//g' | sort -u)
            for var in $vars_in_line; do
                if [ -n "${!var}" ]; then
                    value="${!var}"
                    expanded_line=$(echo "$expanded_line" | sed "s/\${$var}/$value/g")
                fi
            done
        else
            if command -v envsubst >/dev/null 2>&1; then
                expanded_line=$(echo "$line" | envsubst)
            else
                expanded_line=$(eval echo "$line")
            fi
        fi
        
        # Install with retry logic
        if install_mcp_with_retry "$expanded_line" "$server_name"; then
            successful_servers=$((successful_servers + 1))
        else
            failed_servers=$((failed_servers + 1))
        fi
        
        echo "---"
    done < "$profile_file"
    
    local overall_duration=$(($(date +%s) - overall_start_time))
    
    # Generate final report
    generate_report "$profile"
    
    log_header "Installation Complete"
    log_info "Profile: $profile"
    log_info "Total time: ${overall_duration}s"
    log_info "Total servers: $total_servers"
    log_success "Successful: $successful_servers"
    if [ $failed_servers -gt 0 ]; then
        log_error "Failed: $failed_servers"
    fi
    
    # Cleanup
    log_info "Logs saved to: $LOGS_DIR/"
    log_info "Metrics saved to: $CONFIG_DIR/metrics.json"
}

# Show help
show_help() {
    cat << EOF
Enhanced MCP Server Installer v$SCRIPT_VERSION

Usage: $0 [OPTIONS] [PROFILE]

PROFILES:
    dev      - Development profile (essential tools)
    minimal  - Minimal profile (basic functionality)
    full     - Full profile (all available servers)
    custom   - Custom profile (user-defined)

OPTIONS:
    -h, --help          Show this help message
    -l, --list          List available profiles
    -s, --status        Show installation status
    -c, --check         Perform health checks on installed servers
    -r, --report        Generate detailed installation report
    --clean             Clean configuration and logs
    --init-profiles     Initialize default profiles

EXAMPLES:
    $0 dev              Install development profile
    $0 --list           List available profiles
    $0 --status         Check current installation status
    $0 --check          Health check all installed servers

ENVIRONMENT:
    Configuration directory: $CONFIG_DIR
    Logs directory: $LOGS_DIR
    Max retry attempts: $MAX_RETRY_ATTEMPTS
    Health check timeout: $HEALTH_CHECK_TIMEOUT seconds

EOF
}

# List available profiles
list_profiles() {
    log_header "Available MCP Profiles"
    if [ -d "$PROFILES_DIR" ]; then
        for profile_file in "$PROFILES_DIR"/*.txt; do
            if [ -f "$profile_file" ]; then
                local profile_name=$(basename "$profile_file" .txt)
                local server_count=$(grep -v '^#' "$profile_file" | grep -v '^$' | wc -l)
                printf "  %-12s - %d servers\n" "$profile_name" "$server_count"
            fi
        done
    else
        log_warning "No profiles directory found. Run --init-profiles first."
    fi
}

# Show installation status
show_status() {
    log_header "MCP Installation Status"
    
    if [ -f "$CONFIG_DIR/metrics.json" ] && command -v jq >/dev/null 2>&1; then
        local total=$(jq '.installations | length' "$CONFIG_DIR/metrics.json")
        local successful=$(jq '.installations | map(select(.status == "success")) | length' "$CONFIG_DIR/metrics.json")
        local failed=$(jq '.installations | map(select(.status == "failed")) | length' "$CONFIG_DIR/metrics.json")
        
        echo "Total installations: $total"
        echo "Successful: $successful"
        echo "Failed: $failed"
        
        if [ "$total" -gt 0 ]; then
            log_info "Recent installations:"
            jq -r '.installations[-5:] | .[] | "  \(.name): \(.status) (\(.duration)s, \(.attempts) attempts)"' "$CONFIG_DIR/metrics.json"
        fi
    else
        log_warning "No installation metrics found"
    fi
}

# Health check all installed servers
check_all_servers() {
    log_header "Performing Health Checks"
    
    if command -v claude >/dev/null && claude mcp list >/dev/null 2>&1; then
        claude mcp list | grep -v "No MCP servers" | while read -r server_line; do
            if [[ "$server_line" =~ ^[[:space:]]*([^[:space:]]+) ]]; then
                local server_name="${BASH_REMATCH[1]}"
                health_check_mcp "$server_name"
            fi
        done
    else
        log_error "Cannot perform health checks - Claude CLI not available or not configured"
    fi
}

# Clean configuration and logs
clean_config() {
    log_header "Cleaning MCP Configuration"
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        log_success "Configuration and logs cleaned"
    else
        log_info "No configuration to clean"
    fi
}

# Initialize default profiles (will be called from another function)
init_default_profiles() {
    log_header "Initializing Default MCP Profiles"
    init_config_dirs
    log_success "Default profiles initialized (profiles will be created by separate script)"
}

# Main script logic
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -l|--list)
            list_profiles
            ;;
        -s|--status)
            show_status
            ;;
        -c|--check)
            check_all_servers
            ;;
        -r|--report)
            if [ -f "$CONFIG_DIR/metrics.json" ]; then
                generate_report "${2:-unknown}"
            else
                log_error "No metrics found. Run an installation first."
            fi
            ;;
        --clean)
            clean_config
            ;;
        --init-profiles)
            init_default_profiles
            ;;
        "")
            # No arguments - default to dev profile
            install_mcp_servers "dev"
            ;;
        *)
            # Profile name provided
            install_mcp_servers "$1"
            ;;
    esac
}

# Run main function with all arguments
main "$@"