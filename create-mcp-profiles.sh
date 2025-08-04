#!/bin/bash
# ABOUTME: Creates MCP configuration profiles (dev, minimal, full, custom) with dependencies and environment templates
# ABOUTME: Based on research findings for optimal MCP server selection by use case

set -e

PROFILES_DIR="/app/.mcp-config/profiles"
TEMPLATES_DIR="/app/.mcp-config/templates"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}[MCP-PROFILES]${NC} $1"
}

# Create directories
mkdir -p "$PROFILES_DIR" "$TEMPLATES_DIR"

log_header "Creating MCP Configuration Profiles"

# =====================================================
# MINIMAL PROFILE - Essential tools only
# =====================================================
log_info "Creating minimal profile (essential tools)"

cat > "$PROFILES_DIR/minimal.txt" << 'EOF'
# MCP Minimal Profile - Essential Development Tools
# Fast setup for basic development needs (~5 minutes)

# Filesystem Operations (Official - High Performance)
claude mcp add filesystem npx @modelcontextprotocol/server-filesystem /workspace

# Git Version Control (Official)
claude mcp add git npx @modelcontextprotocol/server-git --repository /workspace

# Web Content Fetching (Official)
claude mcp add fetch npx @modelcontextprotocol/server-fetch
EOF

cat > "$PROFILES_DIR/minimal/dependencies.txt" << 'EOF'
# Dependencies for minimal profile
npm:@modelcontextprotocol/server-filesystem:latest
npm:@modelcontextprotocol/server-git:latest  
npm:@modelcontextprotocol/server-fetch:latest
system:git
system:node
EOF

# =====================================================
# DEVELOPMENT PROFILE - Balanced for most development
# =====================================================
log_info "Creating development profile (balanced toolset)"

cat > "$PROFILES_DIR/dev.txt" << 'EOF'
# MCP Development Profile - Balanced Toolset for Most Development Needs
# Optimized for rapid development with essential integrations (~15 minutes)

# === ESSENTIAL TOOLS ===
# Filesystem Operations (Official - High Performance)
claude mcp add filesystem npx @modelcontextprotocol/server-filesystem /workspace

# Git Version Control (Official)
claude mcp add git npx @modelcontextprotocol/server-git --repository /workspace

# Web Content Fetching (Official)
claude mcp add fetch npx @modelcontextprotocol/server-fetch

# === PRODUCTIVITY ENHANCERS ===
# GitHub Integration (Official Partner - if available)
# claude mcp add github npx @modelcontextprotocol/server-github

# Context7 - Up-to-date documentation and code examples
claude mcp add -s user --transport sse context7 https://mcp.context7.com/sse

# === DATABASE INTEGRATION ===
# Uncomment based on your database needs:
# PostgreSQL (High Performance)
# claude mcp add postgres npx @crystaldba/postgres-mcp

# === COMMUNICATION (Optional - requires API keys) ===
# Slack Integration (requires SLACK_BOT_TOKEN)
# claude mcp add-json slack-mcp -s user '{"command":"npx","args":["@modelcontextprotocol/server-slack"],"env":{"SLACK_BOT_TOKEN":"${SLACK_BOT_TOKEN}"}}'

# Twilio SMS (requires Twilio credentials)
claude mcp add-json twilio -s user "{\"command\":\"npx\",\"args\":[\"-y\",\"@yiyang.1i/sms-mcp-server\"],\"env\":{\"ACCOUNT_SID\":\"${TWILIO_ACCOUNT_SID}\",\"AUTH_TOKEN\":\"${TWILIO_AUTH_TOKEN}\",\"FROM_NUMBER\":\"${TWILIO_FROM_NUMBER}\"}}"
EOF

cat > "$PROFILES_DIR/dev/dependencies.txt" << 'EOF'
# Dependencies for development profile
npm:@modelcontextprotocol/server-filesystem:latest
npm:@modelcontextprotocol/server-git:latest
npm:@modelcontextprotocol/server-fetch:latest
npm:@yiyang.1i/sms-mcp-server:latest
system:git
system:node
system:curl
env:TWILIO_ACCOUNT_SID
env:TWILIO_AUTH_TOKEN
env:TWILIO_FROM_NUMBER
EOF

# =====================================================
# FULL PROFILE - Comprehensive toolset
# =====================================================
log_info "Creating full profile (comprehensive toolset)"

cat > "$PROFILES_DIR/full.txt" << 'EOF'
# MCP Full Profile - Comprehensive Development Environment
# Complete toolset for professional development (~30 minutes)

# === CORE DEVELOPMENT TOOLS ===
# Filesystem Operations (Official - High Performance)
claude mcp add filesystem npx @modelcontextprotocol/server-filesystem /workspace

# Git Version Control (Official)
claude mcp add git npx @modelcontextprotocol/server-git --repository /workspace

# Web Content Fetching (Official)
claude mcp add fetch npx @modelcontextprotocol/server-fetch

# === ENHANCED INTEGRATIONS ===
# Context7 - Documentation and examples
claude mcp add -s user --transport sse context7 https://mcp.context7.com/sse

# GitHub Integration (if available)
# claude mcp add github npx @modelcontextprotocol/server-github

# === DATABASE INTEGRATIONS ===
# PostgreSQL (High Performance - requires DB_URL)
# claude mcp add-json postgres -s user '{"command":"npx","args":["@crystaldba/postgres-mcp"],"env":{"DATABASE_URL":"${POSTGRES_URL}"}}'

# ClickHouse (Analytics - requires CLICKHOUSE_URL)
# claude mcp add-json clickhouse -s user '{"command":"npx","args":["@clickhouse/mcp-clickhouse"],"env":{"CLICKHOUSE_URL":"${CLICKHOUSE_URL}","CLICKHOUSE_PASSWORD":"${CLICKHOUSE_PASSWORD}"}}'

# === COMMUNICATION & COLLABORATION ===
# Slack (requires SLACK_BOT_TOKEN)
# claude mcp add-json slack-mcp -s user '{"command":"npx","args":["@modelcontextprotocol/server-slack"],"env":{"SLACK_BOT_TOKEN":"${SLACK_BOT_TOKEN}"}}'

# Twilio SMS (requires Twilio credentials)
claude mcp add-json twilio -s user "{\"command\":\"npx\",\"args\":[\"-y\",\"@yiyang.1i/sms-mcp-server\"],\"env\":{\"ACCOUNT_SID\":\"${TWILIO_ACCOUNT_SID}\",\"AUTH_TOKEN\":\"${TWILIO_AUTH_TOKEN}\",\"FROM_NUMBER\":\"${TWILIO_FROM_NUMBER}\"}}"

# Notion (requires NOTION_API_KEY)
# claude mcp add-json notion -s user '{"command":"npx","args":["@modelcontextprotocol/server-notion"],"env":{"NOTION_API_KEY":"${NOTION_API_KEY}"}}'

# === API DEVELOPMENT & TESTING ===
# Puppeteer for browser automation (if available)
# claude mcp add puppeteer npx @modelcontextprotocol/server-puppeteer

# === AI/ML INTEGRATION ===
# Langfuse for LLM observability (requires LANGFUSE_API_KEY)
# claude mcp add-json langfuse -s user '{"command":"npx","args":["langfuse-mcp"],"env":{"LANGFUSE_PUBLIC_KEY":"${LANGFUSE_PUBLIC_KEY}","LANGFUSE_SECRET_KEY":"${LANGFUSE_SECRET_KEY}","LANGFUSE_HOST":"${LANGFUSE_HOST}"}}'

# Chroma for vector search (requires CHROMA_URL)
# claude mcp add-json chroma -s user '{"command":"npx","args":["@chroma/mcp-server"],"env":{"CHROMA_URL":"${CHROMA_URL}"}}'

# === SECURITY & COMPLIANCE ===
# Auth0 for identity management (requires AUTH0_DOMAIN, AUTH0_CLIENT_ID)
# claude mcp add-json auth0 -s user '{"command":"npx","args":["auth0-mcp-server"],"env":{"AUTH0_DOMAIN":"${AUTH0_DOMAIN}","AUTH0_CLIENT_ID":"${AUTH0_CLIENT_ID}","AUTH0_CLIENT_SECRET":"${AUTH0_CLIENT_SECRET}"}}'

# === CLOUD INTEGRATIONS ===
# AWS (requires AWS credentials)
# claude mcp add-json aws -s user '{"command":"npx","args":["aws-mcp-server"],"env":{"AWS_ACCESS_KEY_ID":"${AWS_ACCESS_KEY_ID}","AWS_SECRET_ACCESS_KEY":"${AWS_SECRET_ACCESS_KEY}","AWS_REGION":"${AWS_REGION}"}}'

# Azure (requires Azure credentials)
# claude mcp add-json azure -s user '{"command":"npx","args":["azure-mcp-server"],"env":{"AZURE_CLIENT_ID":"${AZURE_CLIENT_ID}","AZURE_CLIENT_SECRET":"${AZURE_CLIENT_SECRET}","AZURE_TENANT_ID":"${AZURE_TENANT_ID}"}}'

# === CI/CD & DEVOPS ===
# Buildkite (requires BUILDKITE_API_TOKEN)
# claude mcp add-json buildkite -s user '{"command":"npx","args":["buildkite-mcp"],"env":{"BUILDKITE_API_TOKEN":"${BUILDKITE_API_TOKEN}"}}'
EOF

cat > "$PROFILES_DIR/full/dependencies.txt" << 'EOF'
# Dependencies for full profile
npm:@modelcontextprotocol/server-filesystem:latest
npm:@modelcontextprotocol/server-git:latest
npm:@modelcontextprotocol/server-fetch:latest
npm:@yiyang.1i/sms-mcp-server:latest
npm:@crystaldba/postgres-mcp:latest
system:git
system:node
system:curl
system:docker
env:TWILIO_ACCOUNT_SID
env:TWILIO_AUTH_TOKEN
env:TWILIO_FROM_NUMBER
env:POSTGRES_URL
env:CLICKHOUSE_URL
env:SLACK_BOT_TOKEN
env:NOTION_API_KEY
env:LANGFUSE_PUBLIC_KEY
env:AWS_ACCESS_KEY_ID
env:AZURE_CLIENT_ID
EOF

# =====================================================
# CUSTOM PROFILE TEMPLATE
# =====================================================
log_info "Creating custom profile template"

cat > "$PROFILES_DIR/custom.txt" << 'EOF'
# MCP Custom Profile - User-Defined Configuration
# Customize this file with your specific MCP server requirements

# === EXAMPLE CONFIGURATIONS ===
# Copy and modify the configurations below based on your needs

# Filesystem (Essential)
claude mcp add filesystem npx @modelcontextprotocol/server-filesystem /workspace

# Git (Essential)  
claude mcp add git npx @modelcontextprotocol/server-git --repository /workspace

# === ADD YOUR CUSTOM MCP SERVERS BELOW ===
# Format: claude mcp add <name> <command> <args>
# Format: claude mcp add-json <name> -s user '{"command":"...","args":[...],"env":{...}}'

# Example with environment variables:
# claude mcp add-json custom-server -s user '{"command":"npx","args":["custom-package"],"env":{"API_KEY":"${CUSTOM_API_KEY}"}}'
EOF

cat > "$PROFILES_DIR/custom/dependencies.txt" << 'EOF'
# Dependencies for custom profile
npm:@modelcontextprotocol/server-filesystem:latest
npm:@modelcontextprotocol/server-git:latest
system:git
system:node
# Add your custom dependencies here:
# npm:package-name:version
# system:command-name  
# env:ENVIRONMENT_VARIABLE_NAME
EOF

# =====================================================
# ENVIRONMENT TEMPLATES
# =====================================================
log_header "Creating Environment Templates"

# Minimal environment template
log_info "Creating minimal environment template"
cat > "$TEMPLATES_DIR/minimal.env" << 'EOF'
# MCP Minimal Profile Environment Variables
# No additional environment variables required for minimal profile

# Optional: Set Claude Flow configuration
CLAUDE_FLOW_AUTO_COMMIT=false
CLAUDE_FLOW_AUTO_PUSH=false
CLAUDE_FLOW_HOOKS_ENABLED=true
EOF

# Development environment template
log_info "Creating development environment template"
cat > "$TEMPLATES_DIR/dev.env" << 'EOF'
# MCP Development Profile Environment Variables

# === COMMUNICATION SERVICES ===
# Twilio SMS Configuration (Optional)
# TWILIO_ACCOUNT_SID=your_account_sid_here
# TWILIO_AUTH_TOKEN=your_auth_token_here  
# TWILIO_FROM_NUMBER=your_phone_number_here

# Slack Integration (Optional)
# SLACK_BOT_TOKEN=xoxb-your-slack-bot-token

# === DATABASE CONFIGURATION ===
# PostgreSQL (Optional)
# POSTGRES_URL=postgresql://user:password@localhost:5432/database

# === CLAUDE FLOW SETTINGS ===
CLAUDE_FLOW_AUTO_COMMIT=false
CLAUDE_FLOW_AUTO_PUSH=false
CLAUDE_FLOW_HOOKS_ENABLED=true
CLAUDE_FLOW_TELEMETRY_ENABLED=true
CLAUDE_FLOW_REMOTE_EXECUTION=true
CLAUDE_FLOW_CHECKPOINTS_ENABLED=true
EOF

# Full environment template
log_info "Creating full environment template"
cat > "$TEMPLATES_DIR/full.env" << 'EOF'
# MCP Full Profile Environment Variables
# Complete environment configuration for professional development

# === COMMUNICATION SERVICES ===
# Twilio SMS Configuration
# TWILIO_ACCOUNT_SID=your_account_sid_here
# TWILIO_AUTH_TOKEN=your_auth_token_here
# TWILIO_FROM_NUMBER=your_phone_number_here

# Slack Integration
# SLACK_BOT_TOKEN=xoxb-your-slack-bot-token

# Notion Integration
# NOTION_API_KEY=secret_your_notion_integration_token

# === DATABASE CONFIGURATION ===
# PostgreSQL
# POSTGRES_URL=postgresql://user:password@localhost:5432/database

# ClickHouse (Analytics)  
# CLICKHOUSE_URL=http://localhost:8123
# CLICKHOUSE_PASSWORD=your_clickhouse_password
# CLICKHOUSE_USER=default

# === AI/ML SERVICES ===
# Langfuse (LLM Observability)
# LANGFUSE_PUBLIC_KEY=pk-lf-your-public-key
# LANGFUSE_SECRET_KEY=sk-lf-your-secret-key
# LANGFUSE_HOST=https://cloud.langfuse.com

# Chroma (Vector Search)
# CHROMA_URL=http://localhost:8000

# === SECURITY & IDENTITY ===
# Auth0 Configuration
# AUTH0_DOMAIN=your-domain.auth0.com
# AUTH0_CLIENT_ID=your_client_id
# AUTH0_CLIENT_SECRET=your_client_secret

# === CLOUD PROVIDERS ===
# AWS Configuration
# AWS_ACCESS_KEY_ID=your_access_key
# AWS_SECRET_ACCESS_KEY=your_secret_key
# AWS_REGION=us-east-1

# Azure Configuration
# AZURE_CLIENT_ID=your_client_id
# AZURE_CLIENT_SECRET=your_client_secret
# AZURE_TENANT_ID=your_tenant_id

# === CI/CD SERVICES ===
# Buildkite
# BUILDKITE_API_TOKEN=your_buildkite_token

# === CLAUDE FLOW SETTINGS ===
CLAUDE_FLOW_AUTO_COMMIT=false
CLAUDE_FLOW_AUTO_PUSH=false
CLAUDE_FLOW_HOOKS_ENABLED=true
CLAUDE_FLOW_TELEMETRY_ENABLED=true
CLAUDE_FLOW_REMOTE_EXECUTION=true
CLAUDE_FLOW_CHECKPOINTS_ENABLED=true
CLAUDE_FLOW_PERFORMANCE_MONITORING=true
EOF

# Custom environment template
log_info "Creating custom environment template"
cat > "$TEMPLATES_DIR/custom.env" << 'EOF'
# MCP Custom Profile Environment Variables
# Define your custom environment variables here

# === EXAMPLE CONFIGURATIONS ===
# API_KEY=your_api_key_here
# SERVICE_URL=https://your-service.com
# DATABASE_URL=your_database_connection_string

# === CLAUDE FLOW SETTINGS ===
CLAUDE_FLOW_AUTO_COMMIT=false
CLAUDE_FLOW_AUTO_PUSH=false
CLAUDE_FLOW_HOOKS_ENABLED=true

# === ADD YOUR CUSTOM VARIABLES BELOW ===
# Follow the pattern: VAR_NAME=value
# For secrets, use placeholder values and update during deployment
EOF

# =====================================================
# PROFILE DOCUMENTATION
# =====================================================
log_info "Creating profile documentation"

cat > "$PROFILES_DIR/README.md" << 'EOF'
# MCP Configuration Profiles

This directory contains MCP server configuration profiles for different use cases.

## Available Profiles

### 1. Minimal Profile (`minimal.txt`)
**Setup Time:** ~5 minutes  
**Use Case:** Basic development needs  
**Servers:** 3 essential tools
- Filesystem operations
- Git version control  
- Web content fetching

**Dependencies:** Node.js, Git

### 2. Development Profile (`dev.txt`)
**Setup Time:** ~15 minutes  
**Use Case:** Balanced development workflow  
**Servers:** 5-8 integrated tools
- All minimal profile servers
- Context7 documentation
- Twilio SMS (optional)
- Database integration (optional)

**Dependencies:** Node.js, Git, Optional API keys

### 3. Full Profile (`full.txt`)
**Setup Time:** ~30 minutes  
**Use Case:** Professional development environment  
**Servers:** 15+ comprehensive tools
- All development profile servers
- Cloud integrations (AWS, Azure)
- AI/ML tools (Langfuse, Chroma)
- Security tools (Auth0)
- CI/CD integrations

**Dependencies:** Node.js, Git, Docker, Multiple API keys

### 4. Custom Profile (`custom.txt`)
**Setup Time:** Variable  
**Use Case:** User-defined requirements  
**Servers:** Configurable
- Template for custom configurations
- Examples and documentation included

## Usage

```bash
# Install a specific profile
./enhanced-install-mcp-servers.sh dev

# List available profiles  
./enhanced-install-mcp-servers.sh --list

# Check installation status
./enhanced-install-mcp-servers.sh --status
```

## Environment Variables

Each profile has an associated environment template in `/templates/`:
- `minimal.env` - No additional variables required
- `dev.env` - Optional API keys for enhanced features  
- `full.env` - Complete environment configuration
- `custom.env` - Template for custom variables

## Profile Structure

Each profile directory contains:
- `{profile}.txt` - MCP server installation commands
- `dependencies.txt` - Required dependencies and environment variables
- Environment template in `/templates/{profile}.env`

## Customization

1. Copy `custom.txt` to create a new profile
2. Modify the server list based on your needs
3. Update the corresponding `dependencies.txt` file
4. Create an environment template if needed
5. Test the profile with the enhanced installer

## Performance Notes

- **Minimal**: Fastest setup, essential functionality only
- **Development**: Balanced performance and features  
- **Full**: Comprehensive but longer setup time
- **Custom**: Performance depends on selected servers

## Troubleshooting

- Check dependencies before installation
- Verify environment variables are set correctly
- Use `--check` flag for health checks after installation
- Review logs in `/app/.mcp-config/logs/` for detailed error information
EOF

log_success "Created profile documentation"

# Create directory structure summary
log_header "Profile Creation Summary"
log_success "Created MCP configuration profiles:"
echo "  📁 Profiles:"
echo "    - minimal.txt (3 servers, ~5 min setup)"
echo "    - dev.txt (5-8 servers, ~15 min setup)"  
echo "    - full.txt (15+ servers, ~30 min setup)"
echo "    - custom.txt (template for user customization)"
echo ""
echo "  📁 Dependencies:"
echo "    - minimal/dependencies.txt"
echo "    - dev/dependencies.txt"
echo "    - full/dependencies.txt"
echo "    - custom/dependencies.txt"
echo ""
echo "  📁 Environment Templates:"
echo "    - minimal.env (basic settings)"
echo "    - dev.env (development configuration)"
echo "    - full.env (comprehensive environment)"  
echo "    - custom.env (user template)"
echo ""
echo "  📄 Documentation:"
echo "    - README.md (complete usage guide)"

log_header "Next Steps"
echo "1. Run: ./enhanced-install-mcp-servers.sh --init-profiles"
echo "2. Configure environment variables in /app/.env"
echo "3. Install desired profile: ./enhanced-install-mcp-servers.sh [profile]"
echo "4. Check status: ./enhanced-install-mcp-servers.sh --status"

log_success "MCP profiles creation complete!"