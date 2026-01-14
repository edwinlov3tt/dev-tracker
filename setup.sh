#!/bin/bash
# Setup script for Development Tracker
# Safe to run multiple times (idempotent)

set -e

TRACKER_DIR="$HOME/dev-tracker"
DB_PATH="$TRACKER_DIR/dev_tracker.db"

echo "🚀 Setting up Development Tracker..."

# Create directories
mkdir -p "$TRACKER_DIR/hooks"
mkdir -p "$TRACKER_DIR/logs"

# Initialize database
if [ ! -f "$DB_PATH" ]; then
    echo "📦 Initializing database..."
    sqlite3 "$DB_PATH" < "$TRACKER_DIR/schema.sql"
    echo "✅ Database created at $DB_PATH"
else
    echo "✅ Database already exists"
fi

# Make hook script executable
chmod +x "$TRACKER_DIR/hooks/track.sh"
echo "✅ Hook script is executable"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install -r "$TRACKER_DIR/requirements.txt" --quiet

# Setup Claude Code hooks
CLAUDE_CONFIG_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_CONFIG_DIR"

if [ -f "$CLAUDE_CONFIG_DIR/hooks.json" ]; then
    echo "⚠️  Existing hooks.json found. Backing up to hooks.json.bak"
    cp "$CLAUDE_CONFIG_DIR/hooks.json" "$CLAUDE_CONFIG_DIR/hooks.json.bak"
fi

cp "$TRACKER_DIR/claude_hooks.json" "$CLAUDE_CONFIG_DIR/hooks.json"
echo "✅ Claude Code hooks configured"

# Create git post-commit hook template
cat > "$TRACKER_DIR/hooks/post-commit" << 'EOF'
#!/bin/bash
# Git post-commit hook for development tracking
# Copy this to your repo's .git/hooks/post-commit

$HOME/dev-tracker/hooks/track.sh commit
EOF
chmod +x "$TRACKER_DIR/hooks/post-commit"
echo "✅ Git hook template created"

# Create environment file template
cat > "$TRACKER_DIR/.env.example" << 'EOF'
# Development Tracker Environment Variables
# Copy this to .env and fill in your values

# Roadmap API token (get from admin)
ROADMAP_API_TOKEN=your_64_character_token_here

# Optional: Custom database path
# DEV_TRACKER_DB=$HOME/dev-tracker/dev_tracker.db
EOF
echo "✅ Environment template created"

# Make service script executable
chmod +x "$TRACKER_DIR/service.sh"
echo "✅ Service manager ready"

# Install and start the dashboard service
echo "📦 Installing dashboard service..."
"$TRACKER_DIR/service.sh" install

echo ""
echo "=========================================="
echo "🎉 Setup complete!"
echo "=========================================="
echo ""
echo "Dashboard Service:"
echo "  Start:   $TRACKER_DIR/service.sh start"
echo "  Stop:    $TRACKER_DIR/service.sh stop"
echo "  Status:  $TRACKER_DIR/service.sh status"
echo "  Logs:    $TRACKER_DIR/service.sh logs"
echo ""
echo "The dashboard auto-starts on login and auto-restarts on crash."
echo ""
echo "Next steps:"
echo ""
echo "1. Start the dashboard:"
echo "   $TRACKER_DIR/service.sh start"
echo ""
echo "2. Set your Roadmap API token (optional):"
echo "   export ROADMAP_API_TOKEN='your_token_here'"
echo ""
echo "3. Add the MCP server to your Claude configuration."
echo "   See: $TRACKER_DIR/mcp_config.json"
echo ""
echo "4. Install the git hook in your repos:"
echo "   cp $TRACKER_DIR/hooks/post-commit /path/to/repo/.git/hooks/"
echo ""
echo "5. Link your repos to projects:"
echo "   $TRACKER_DIR/hooks/track.sh link 'api-key' 'Project Name'"
echo ""
echo "Dashboard URL: http://localhost:8080"
echo ""
echo "Happy tracking! 📊"
