#!/bin/bash
# Service management for Development Tracker Dashboard
# Usage: ./service.sh [start|stop|restart|status|logs|install|uninstall]

set -e

PLIST_NAME="com.devtracker.dashboard"
PLIST_SRC="$HOME/dev-tracker/com.devtracker.dashboard.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
LOG_DIR="$HOME/dev-tracker/logs"
DASHBOARD_URL="http://localhost:8080"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Expand ~ and $HOME in plist before installing
expand_plist() {
    sed "s|\${HOME}|$HOME|g" "$PLIST_SRC"
}

install_service() {
    echo "Installing dashboard service..."

    # Create logs directory
    mkdir -p "$LOG_DIR"

    # Expand variables and install plist
    expand_plist > "$PLIST_DEST"

    echo -e "${GREEN}Service installed at $PLIST_DEST${NC}"
    echo "Run './service.sh start' to start the dashboard"
}

uninstall_service() {
    echo "Uninstalling dashboard service..."

    # Stop if running
    launchctl unload "$PLIST_DEST" 2>/dev/null || true

    # Remove plist
    rm -f "$PLIST_DEST"

    echo -e "${GREEN}Service uninstalled${NC}"
}

start_service() {
    if [ ! -f "$PLIST_DEST" ]; then
        echo -e "${YELLOW}Service not installed. Installing first...${NC}"
        install_service
    fi

    echo "Starting dashboard service..."
    launchctl load "$PLIST_DEST" 2>/dev/null || launchctl kickstart -k "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true

    # Wait for startup
    sleep 2
    check_status
}

stop_service() {
    echo "Stopping dashboard service..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    echo -e "${GREEN}Service stopped${NC}"
}

restart_service() {
    stop_service
    sleep 1
    start_service
}

check_status() {
    echo "Dashboard Service Status"
    echo "========================"

    # Check if launchd job is loaded
    if launchctl list | grep -q "$PLIST_NAME"; then
        echo -e "LaunchAgent: ${GREEN}Loaded${NC}"
    else
        echo -e "LaunchAgent: ${RED}Not loaded${NC}"
    fi

    # Check if server is responding
    if curl -s --max-time 2 "$DASHBOARD_URL/api/health" > /dev/null 2>&1; then
        echo -e "HTTP Server:  ${GREEN}Running${NC}"
        echo -e "Dashboard:    ${GREEN}$DASHBOARD_URL${NC}"

        # Show health details
        health=$(curl -s "$DASHBOARD_URL/api/health" 2>/dev/null)
        if [ -n "$health" ]; then
            echo ""
            echo "Health Check:"
            echo "$health" | python3 -m json.tool 2>/dev/null || echo "$health"
        fi
    else
        echo -e "HTTP Server:  ${RED}Not responding${NC}"
    fi

    # Show recent log entries if available
    if [ -f "$LOG_DIR/dashboard.error.log" ]; then
        errors=$(tail -5 "$LOG_DIR/dashboard.error.log" 2>/dev/null | grep -v "^$" | head -3)
        if [ -n "$errors" ]; then
            echo ""
            echo -e "${YELLOW}Recent errors:${NC}"
            echo "$errors"
        fi
    fi
}

show_logs() {
    echo "Dashboard Logs"
    echo "=============="

    if [ "$1" = "error" ] || [ "$1" = "errors" ]; then
        echo "Error log: $LOG_DIR/dashboard.error.log"
        echo ""
        tail -50 "$LOG_DIR/dashboard.error.log" 2>/dev/null || echo "No error log found"
    elif [ "$1" = "follow" ] || [ "$1" = "-f" ]; then
        echo "Following logs (Ctrl+C to stop)..."
        tail -f "$LOG_DIR/dashboard.log" "$LOG_DIR/dashboard.error.log" 2>/dev/null
    else
        echo "Output log: $LOG_DIR/dashboard.log"
        echo ""
        tail -50 "$LOG_DIR/dashboard.log" 2>/dev/null || echo "No log found"
    fi
}

show_help() {
    echo "Development Tracker Dashboard Service Manager"
    echo ""
    echo "Usage: ./service.sh [command]"
    echo ""
    echo "Commands:"
    echo "  install     Install the launchd service (runs on login)"
    echo "  uninstall   Remove the launchd service"
    echo "  start       Start the dashboard server"
    echo "  stop        Stop the dashboard server"
    echo "  restart     Restart the dashboard server"
    echo "  status      Check if the dashboard is running"
    echo "  logs        Show recent log output"
    echo "  logs error  Show recent error log"
    echo "  logs -f     Follow logs in real-time"
    echo ""
    echo "The dashboard will auto-restart if it crashes."
    echo "Dashboard URL: $DASHBOARD_URL"
}

# Main
case "${1:-status}" in
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        check_status
        ;;
    logs|log)
        show_logs "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
