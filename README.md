# KDE Plasma Widget Position Fix

Automatically saves and restores KDE Plasma widget positions when you plug/unplug monitors or change resolution.

## Problem

KDE Plasma 5.x has a long-standing bug where desktop widgets get stuck at the top-left corner when the display configuration changes (monitor plugged/unplugged, resolution change).

## Solution

A background script (systemd user service) that:

- **Restores** saved widget positions when display changes are detected
- **Auto-saves** widget layout when you lock widgets (exit edit mode)
- Keeps **per-display-configuration** backups — each unique monitor setup remembers its own layout

## Quick Install

```bash
curl -L https://gist.github.com/taghouttarek/d6729ae25bda6e1133cbad870ad287ae/raw/install-plasma-widget-fix.sh | bash
```

## Usage

| Action | What happens |
|--------|-------------|
| Rearrange widgets then lock them | Layout auto-saved for current display config |
| Plug in external monitor | Saved position restored after ~2 seconds |
| Unplug external monitor | Saved position restored after ~2 seconds |
| Change resolution | Same behavior |

### Manual commands

```bash
systemctl --user status  plasma-widget-fix.service   # check status
systemctl --user stop    plasma-widget-fix.service   # stop
systemctl --user start   plasma-widget-fix.service   # start
journalctl --user -u plasma-widget-fix.service -f    # view logs
```

### Reset all saved layouts

```bash
rm -rf ~/.config/plasma-widget-backups/
```

Then reposition your widgets and lock them — new backups will be created automatically.

## Requirements

- KDE Plasma 5.x
- `xrandr` (usually pre-installed)
- systemd (user mode)

## How it works

1. Polls `xrandr` every 3 seconds for display configuration changes
2. On display change: waits 2s for KDE to settle, then restores saved config and restarts `plasmashell`
3. Monitors the Plasma applets config file for changes
4. When change detected and widgets are locked: saves config as the reference for current display hash
5. Each unique display layout (identified by connected monitor hash) gets its own backup file in `~/.config/plasma-widget-backups/`
