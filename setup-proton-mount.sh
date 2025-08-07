#!/bin/bash

# Configuration
REMOTE_NAME="proton"
MOUNT_POINT="$HOME/ProtonDrive"
SYSTEMD_UNIT="$HOME/.config/systemd/user/rclone-proton.mount.service"
RCLONE_BIN="/usr/local/bin/rclone"
LOG_DIR="$HOME/.cache/rclone"
LOG_FILE="$LOG_DIR/rclone-proton.log"

# Step 1: Ensure required directories
echo "[+] Creating mount point and log directory..."
mkdir -p "$MOUNT_POINT" "$LOG_DIR" "$HOME/.config/systemd/user"

# Step 2: Write systemd unit
echo "[+] Writing systemd user unit..."
cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=Mount Proton Drive via rclone
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=$RCLONE_BIN mount $REMOTE_NAME: $MOUNT_POINT \\
    --vfs-cache-mode writes \\
    --vfs-cache-max-size 500M \\
    --vfs-cache-max-age 1h \\
    --dir-cache-time 12h \\
    --poll-interval 1m \\
    --log-level INFO \\
    --log-file $LOG_FILE \\
    --umask 002 \\
    --allow-other
ExecStop=/bin/fusermount3 -u $MOUNT_POINT
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

# Step 3: Enable allow-other (if not already)
if ! grep -q "^user_allow_other" /etc/fuse.conf 2>/dev/null; then
    echo "[+] Adding 'user_allow_other' to /etc/fuse.conf (requires sudo)..."
    sudo sh -c 'echo "user_allow_other" >> /etc/fuse.conf'
fi

# Step 4: Add user to fuse group if not already
if ! groups | grep -qw fuse; then
    echo "[+] Adding user to 'fuse' group (requires sudo)..."
    sudo usermod -aG fuse "$USER"
    echo "[!] Please log out and back in for group changes to apply."
fi

# Step 5: Reload and start service
echo "[+] Enabling and starting rclone mount via systemd..."
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable --now rclone-proton.mount.service

echo "[✓] Done. Mounted at: $MOUNT_POINT"
