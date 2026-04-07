#!/bin/bash
set -e

# Synology Torrent Stack Setup
# Automated setup for Gluetun VPN + qBittorrent on Synology NAS

INSTALL_DIR="/volume1/docker/torrent-stack"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Synology Torrent Stack Setup ==="
echo ""

# Check if running on Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "Warning: This doesn't appear to be a Synology NAS."
    echo "The script may still work on other Linux systems."
    echo ""
fi

# Check Docker
if ! command -v docker &>/dev/null && ! command -v /usr/local/bin/docker &>/dev/null; then
    echo "Error: Docker is not installed."
    echo "Install the Docker package from Synology Package Center first."
    exit 1
fi

DOCKER=$(command -v docker 2>/dev/null || echo "/usr/local/bin/docker")
COMPOSE="$DOCKER-compose"
if ! command -v "$COMPOSE" &>/dev/null; then
    COMPOSE="$DOCKER compose"
fi

# Check Docker permissions
if ! $DOCKER ps &>/dev/null; then
    echo "Error: Cannot connect to Docker. Fix with one of:"
    echo "  1. Run this script with sudo"
    echo "  2. Run: sudo chmod 666 /var/run/docker.sock"
    exit 1
fi

# Load TUN module (required for VPN)
echo "[1/5] Loading TUN kernel module..."
if [ ! -e /dev/net/tun ]; then
    if [ -f /lib/modules/tun.ko ]; then
        sudo insmod /lib/modules/tun.ko 2>/dev/null || true
    fi
    sudo mkdir -p /dev/net 2>/dev/null || true
    sudo mknod /dev/net/tun c 10 200 2>/dev/null || true
    sudo chmod 666 /dev/net/tun 2>/dev/null || true
fi

if [ ! -e /dev/net/tun ]; then
    echo "Error: Could not create /dev/net/tun device."
    echo "You may need to enable the TUN module in your kernel."
    exit 1
fi
echo "  TUN device ready."

# Set up .env file
echo "[2/5] Configuring environment..."
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        echo "  Created .env from .env.example"
        echo "  >>> Edit .env with your VPN credentials before continuing! <<<"
        echo "  >>> Run: nano $SCRIPT_DIR/.env <<<"
        exit 0
    else
        echo "Error: No .env or .env.example found."
        exit 1
    fi
fi

# Validate required vars
source "$SCRIPT_DIR/.env"
if [ -z "$WIREGUARD_PRIVATE_KEY" ] || [ "$WIREGUARD_PRIVATE_KEY" = "your-wireguard-private-key-here" ]; then
    echo "Error: WIREGUARD_PRIVATE_KEY is not set in .env"
    echo "Get your WireGuard credentials from your VPN provider's dashboard."
    exit 1
fi

# Create directories
echo "[3/5] Creating directories..."
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/volume1/public-media/Downloads}"
mkdir -p "$SCRIPT_DIR/gluetun"
mkdir -p "$SCRIPT_DIR/qbittorrent-config"
mkdir -p "$DOWNLOAD_DIR/movies"
mkdir -p "$DOWNLOAD_DIR/tv"
mkdir -p "$DOWNLOAD_DIR/incomplete"
echo "  Download directories created at $DOWNLOAD_DIR"

# Auto-detect PUID/PGID if not set
if [ -z "$PUID" ]; then
    PUID=$(id -u)
    echo "  Auto-detected PUID=$PUID"
fi
if [ -z "$PGID" ]; then
    PGID=$(id -g)
    echo "  Auto-detected PGID=$PGID"
fi

# Start containers
echo "[4/5] Starting containers..."
cd "$SCRIPT_DIR"
$COMPOSE up -d 2>&1

# Wait for VPN to connect
echo "[5/5] Waiting for VPN connection..."
for i in $(seq 1 30); do
    sleep 2
    if $DOCKER logs gluetun 2>&1 | grep -q "Public IP address is"; then
        VPN_IP=$($DOCKER logs gluetun 2>&1 | grep "Public IP address is" | tail -1 | grep -oP '(?<=is )\S+')
        echo "  VPN connected! Public IP: $VPN_IP"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  VPN is taking a while to connect. Check logs with:"
        echo "    docker logs gluetun"
    fi
done

# Get qBittorrent password
QB_PASS=$($DOCKER logs qbittorrent 2>&1 | grep "temporary password" | grep -oP '(?<=session: )\S+' || echo "check docker logs qbittorrent")

echo ""
echo "=== Setup Complete ==="
echo ""
echo "qBittorrent Web UI: http://$(hostname -I | awk '{print $1}'):${WEBUI_PORT:-8080}"
echo "  Username: admin"
echo "  Password: $QB_PASS"
echo "  (Change this in qBittorrent settings!)"
echo ""
echo "Download paths (inside qBittorrent):"
echo "  Movies:     /downloads/movies"
echo "  TV Shows:   /downloads/tv"
echo "  Incomplete: /downloads/incomplete"
echo ""
echo "Point Plex at: $DOWNLOAD_DIR/movies and $DOWNLOAD_DIR/tv"
echo ""
echo "Note: The TUN module does not persist across reboots."
echo "Create a Triggered Task in DSM (Control Panel > Task Scheduler)"
echo "that runs on boot: insmod /lib/modules/tun.ko"
