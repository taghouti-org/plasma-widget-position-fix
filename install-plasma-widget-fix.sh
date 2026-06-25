#!/bin/bash
set -e

# KDE Plasma Widget Position Fix
# Saves & restores widget positions per display configuration.
# Auto-saves when you lock widgets after rearranging.
# Restores saved positions when monitor is plugged/unplugged.

INSTALL_DIR="$HOME/.local/bin"
SERVICE_DIR="$HOME/.config/systemd/user"
BACKUP_DIR="$HOME/.config/plasma-widget-backups"

echo "==> Creating directories..."
mkdir -p "$INSTALL_DIR" "$SERVICE_DIR" "$BACKUP_DIR"

echo "==> Installing plasma-widget-fix script..."
cat > "$INSTALL_DIR/plasma-widget-fix" << 'SCRIPT'
#!/bin/bash
CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
BACKUP_DIR="$HOME/.config/plasma-widget-backups"
DISPLAY_STATE_FILE="/tmp/.plasma-display-state"
POLL_INTERVAL=3

mkdir -p "$BACKUP_DIR"

get_display_hash() {
    xrandr --query 2>/dev/null | grep -E " connected" | md5sum | cut -d' ' -f1
}

save_config() {
    local hash="$1"
    cp "$CONFIG_FILE" "$BACKUP_DIR/$hash"
}

restore_config() {
    local hash="$1"
    cp "$BACKUP_DIR/$hash" "$CONFIG_FILE"
}

restart_plasma() {
    killall plasmashell 2>/dev/null
    kstart5 plasmashell &>/dev/null &
}

CURRENT_HASH=$(get_display_hash)
if [ -f "$BACKUP_DIR/$CURRENT_HASH" ]; then
    restore_config "$CURRENT_HASH"
    restart_plasma
else
    save_config "$CURRENT_HASH"
fi

echo "$CURRENT_HASH" > "$DISPLAY_STATE_FILE"

is_locked() {
    ! grep -q "lockDesktop=false" "$CONFIG_FILE" 2>/dev/null
}

LAST_MTIME=$(stat -c %Y "$CONFIG_FILE" 2>/dev/null || echo 0)

while true; do
    sleep "$POLL_INTERVAL"

    CURRENT_HASH=$(get_display_hash)
    PREVIOUS_HASH=$(cat "$DISPLAY_STATE_FILE" 2>/dev/null)

    if [ "$CURRENT_HASH" != "$PREVIOUS_HASH" ]; then
        echo "$CURRENT_HASH" > "$DISPLAY_STATE_FILE"
        sleep 2
        if [ -f "$BACKUP_DIR/$CURRENT_HASH" ]; then
            restore_config "$CURRENT_HASH"
        else
            save_config "$CURRENT_HASH"
        fi
        restart_plasma
    fi

    CURRENT_MTIME=$(stat -c %Y "$CONFIG_FILE" 2>/dev/null || echo 0)
    if [ "$CURRENT_MTIME" != "$LAST_MTIME" ]; then
        LAST_MTIME="$CURRENT_MTIME"
        sleep 1
        if is_locked; then
            DISPLAY_HASH=$(get_display_hash)
            save_config "$DISPLAY_HASH"
        fi
    fi
done
SCRIPT

chmod +x "$INSTALL_DIR/plasma-widget-fix"
echo "       -> $INSTALL_DIR/plasma-widget-fix"

echo "==> Installing systemd service..."
cat > "$SERVICE_DIR/plasma-widget-fix.service" << 'SERVICE'
[Unit]
Description=KDE Plasma Widget Position Manager
After=plasma-workspace.target

[Service]
ExecStart=%h/.local/bin/plasma-widget-fix
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE
echo "       -> $SERVICE_DIR/plasma-widget-fix.service"

echo "==> Reloading systemd and enabling service..."
systemctl --user daemon-reload
systemctl --user enable --now plasma-widget-fix.service

echo ""
echo "=== Done! ==="
echo ""
echo "How it works:"
echo "  - Saves current widget layout when you lock widgets (exit edit mode)"
echo "  - Restores saved positions when monitor is plugged/unplugged"
echo "  - Each unique display configuration keeps its own saved layout"
echo ""
echo "Commands:"
echo "  systemctl --user status  plasma-widget-fix.service   # check status"
echo "  systemctl --user stop    plasma-widget-fix.service   # stop"
echo "  systemctl --user start   plasma-widget-fix.service   # start"
echo "  journalctl --user -u plasma-widget-fix.service -f    # view logs"
echo ""
echo "To reset saved layouts:"
echo "  rm -rf ~/.config/plasma-widget-backups/"
echo "  Then reposition widgets and lock them to re-save."
