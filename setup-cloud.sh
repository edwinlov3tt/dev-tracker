#!/bin/bash
# Setup script for Cloud-based Development Tracker
# Deploys to Cloudflare Workers + D1

set -e

TRACKER_DIR="$HOME/dev-tracker"
WORKERS_DIR="$TRACKER_DIR/workers"

echo "☁️  Setting up Dev Tracker Cloud..."
echo ""

# Check prerequisites
check_prereqs() {
    echo "Checking prerequisites..."

    if ! command -v node &>/dev/null; then
        echo "❌ Node.js not found. Please install Node.js 18+"
        exit 1
    fi

    if ! command -v npm &>/dev/null; then
        echo "❌ npm not found. Please install npm"
        exit 1
    fi

    echo "✅ Node.js $(node --version)"
    echo "✅ npm $(npm --version)"
}

# Install wrangler if needed
install_wrangler() {
    if ! command -v wrangler &>/dev/null; then
        echo "📦 Installing Wrangler CLI..."
        npm install -g wrangler
    fi
    echo "✅ Wrangler $(wrangler --version)"
}

# Check Cloudflare login
check_login() {
    echo ""
    echo "Checking Cloudflare authentication..."

    if ! wrangler whoami &>/dev/null; then
        echo "🔐 Please login to Cloudflare:"
        wrangler login
    fi

    echo "✅ Logged in to Cloudflare"
}

# Install dependencies
install_deps() {
    echo ""
    echo "📦 Installing dependencies..."
    cd "$WORKERS_DIR"
    npm install
    echo "✅ Dependencies installed"
}

# Create D1 database
create_database() {
    echo ""
    echo "🗄️  Setting up D1 database..."

    cd "$WORKERS_DIR"

    # Check if database already exists
    existing=$(wrangler d1 list 2>/dev/null | grep "dev-tracker" || true)

    if [ -n "$existing" ]; then
        echo "✅ Database 'dev-tracker' already exists"
        db_id=$(echo "$existing" | awk '{print $1}')
    else
        echo "Creating new D1 database..."
        output=$(wrangler d1 create dev-tracker 2>&1)
        db_id=$(echo "$output" | grep -oE '[a-f0-9-]{36}' | head -1)
        echo "✅ Database created: $db_id"
    fi

    # Update wrangler.toml with database ID
    if [ -n "$db_id" ]; then
        sed -i.bak "s/database_id = \"\"/database_id = \"$db_id\"/" wrangler.toml
        rm -f wrangler.toml.bak
        echo "✅ Updated wrangler.toml with database ID"
    fi
}

# Run migrations
run_migrations() {
    echo ""
    echo "📊 Running database migrations..."
    cd "$WORKERS_DIR"
    wrangler d1 execute dev-tracker --file=./schema.sql --remote
    echo "✅ Migrations complete"
}

# Generate and set API token
setup_token() {
    echo ""
    echo "🔑 Setting up API token..."

    # Generate token
    API_TOKEN=$(openssl rand -hex 32)

    echo "Generated API token (save this!):"
    echo ""
    echo "  $API_TOKEN"
    echo ""

    # Set as secret
    echo "$API_TOKEN" | wrangler secret put API_TOKEN

    echo "✅ API token set as secret"

    # Save to local config
    cat > "$TRACKER_DIR/.env.cloud" << EOF
# Dev Tracker Cloud Configuration
# Generated on $(date)

DEV_TRACKER_API_TOKEN=$API_TOKEN
# DEV_TRACKER_API_URL will be set after deployment
EOF

    echo "✅ Token saved to $TRACKER_DIR/.env.cloud"
}

# Deploy worker
deploy_worker() {
    echo ""
    echo "🚀 Deploying to Cloudflare Workers..."
    cd "$WORKERS_DIR"

    output=$(wrangler deploy 2>&1)
    echo "$output"

    # Extract worker URL
    worker_url=$(echo "$output" | grep -oE 'https://[a-z0-9-]+\.workers\.dev' | head -1)

    if [ -n "$worker_url" ]; then
        echo ""
        echo "✅ Deployed to: $worker_url"

        # Update .env.cloud with URL
        echo "DEV_TRACKER_API_URL=$worker_url" >> "$TRACKER_DIR/.env.cloud"

        # Create convenience script
        cat > "$TRACKER_DIR/source-cloud.sh" << EOF
# Source this file to use cloud tracker
# Usage: source ~/dev-tracker/source-cloud.sh

export DEV_TRACKER_API_URL="$worker_url"
export DEV_TRACKER_API_TOKEN="\$(grep DEV_TRACKER_API_TOKEN $TRACKER_DIR/.env.cloud | cut -d= -f2)"
EOF
        chmod +x "$TRACKER_DIR/source-cloud.sh"
    fi
}

# Setup Claude hooks for cloud
setup_hooks() {
    echo ""
    echo "🪝 Setting up Claude Code hooks..."

    CLAUDE_CONFIG_DIR="$HOME/.claude"
    mkdir -p "$CLAUDE_CONFIG_DIR"

    if [ -f "$CLAUDE_CONFIG_DIR/hooks.json" ]; then
        cp "$CLAUDE_CONFIG_DIR/hooks.json" "$CLAUDE_CONFIG_DIR/hooks.json.local.bak"
        echo "📁 Backed up existing hooks.json"
    fi

    cp "$TRACKER_DIR/claude_hooks_cloud.json" "$CLAUDE_CONFIG_DIR/hooks.json"
    echo "✅ Cloud hooks configured"
}

# Make scripts executable
setup_scripts() {
    chmod +x "$TRACKER_DIR/hooks/track-cloud.sh"
    echo "✅ Scripts made executable"
}

# Print summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "☁️  Cloud Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Your API is deployed at:"
    grep DEV_TRACKER_API_URL "$TRACKER_DIR/.env.cloud" 2>/dev/null || echo "  (check wrangler output above)"
    echo ""
    echo "Quick Start:"
    echo ""
    echo "1. Load environment variables:"
    echo "   source ~/dev-tracker/source-cloud.sh"
    echo ""
    echo "2. Test the connection:"
    echo "   ~/dev-tracker/hooks/track-cloud.sh health"
    echo ""
    echo "3. Link a repo to a project:"
    echo "   cd /path/to/your/repo"
    echo "   ~/dev-tracker/hooks/track-cloud.sh link 'api-key' 'Project Name'"
    echo ""
    echo "4. View dashboard:"
    echo "   Open the API URL in your browser, or deploy the dashboard:"
    echo "   cd ~/dev-tracker/demo && npx wrangler pages deploy ."
    echo ""
    echo "The hooks will automatically track your Claude Code sessions!"
    echo ""
}

# Main
main() {
    check_prereqs
    install_wrangler
    check_login
    install_deps
    create_database
    run_migrations
    setup_token
    deploy_worker
    setup_hooks
    setup_scripts
    print_summary
}

main
