# Synology Torrent Stack

Private torrenting on Synology NAS with VPN protection. All torrent traffic is routed through a WireGuard VPN tunnel so your real IP is never exposed.

**Stack:** [Gluetun](https://github.com/qdm12/gluetun) (VPN) + [qBittorrent](https://github.com/qbittorrent/qBittorrent) (torrent client), designed to integrate with Plex.

## Supported VPN Providers

Any provider supported by Gluetun — including Surfshark, Mullvad, NordVPN, PIA, and [many more](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers).

## Requirements

- Synology NAS with the **Docker** package installed (DSM 7+)
- SSH access to your NAS
- A VPN subscription with WireGuard support

## Quick Start

### 1. SSH into your NAS

```bash
ssh -p <port> <user>@<nas-ip>
```

### 2. Fix Docker permissions (if needed)

If you get "permission denied" running `docker ps`:

```bash
sudo chmod 666 /var/run/docker.sock
```

### 3. Clone and configure

```bash
cd /volume1/docker
git clone https://github.com/<your-username>/synology-torrent-stack.git
cd synology-torrent-stack
cp .env.example .env
```

Edit `.env` with your VPN credentials:

```bash
nano .env
```

You'll need your **WireGuard private key** from your VPN provider's dashboard:

| Provider | Where to find it |
|----------|-----------------|
| Surfshark | My Account > VPN > Manual Setup > WireGuard |
| Mullvad | Account page > WireGuard configuration |
| NordVPN | NordVPN dashboard > Manual Setup > WireGuard |

### 4. Run setup

```bash
chmod +x setup.sh
./setup.sh
```

The script will:
- Load the TUN kernel module (required for VPN)
- Create download directories
- Start the VPN and torrent containers
- Verify the VPN connection and show your masked IP

### 5. Access qBittorrent

Open `http://<nas-ip>:8080` in your browser. The temporary password is shown at the end of setup — change it in Settings > Web UI.

## Plex Integration

Point your Plex libraries at the download directories:

| Library | Path |
|---------|------|
| Movies | `/volume1/public-media/Downloads/movies` |
| TV Shows | `/volume1/public-media/Downloads/tv` |

Adjust `DOWNLOAD_DIR` in `.env` if your Plex media lives elsewhere.

In qBittorrent, set your default save paths:
- **Movies:** `/downloads/movies`
- **TV Shows:** `/downloads/tv`
- **Incomplete:** `/downloads/incomplete`

## Configuration

All settings are in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `VPN_PROVIDER` | `surfshark` | VPN provider name ([full list](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)) |
| `WIREGUARD_PRIVATE_KEY` | — | Your WireGuard private key (required) |
| `WIREGUARD_ADDRESSES` | `10.14.0.2/16` | WireGuard interface address |
| `SERVER_CITY` | `San Jose` | VPN server city |
| `TZ` | `America/Los_Angeles` | Timezone |
| `PUID` | `1000` | User ID (run `id` to find yours) |
| `PGID` | `1000` | Group ID |
| `DOWNLOAD_DIR` | `/volume1/public-media/Downloads` | Download directory on NAS |
| `WEBUI_PORT` | `8080` | qBittorrent Web UI port |

## Persist TUN Module Across Reboots

The TUN kernel module does not survive a NAS reboot. To fix this:

1. Open DSM > **Control Panel** > **Task Scheduler**
2. Create > **Triggered Task** > **User-defined script**
3. Event: **Boot-up**
4. User: **root**
5. Script:

```bash
insmod /lib/modules/tun.ko
mkdir -p /dev/net
[ ! -e /dev/net/tun ] && mknod /dev/net/tun c 10 200
chmod 666 /dev/net/tun
```

## Verify VPN is Working

```bash
# Check your VPN IP
docker exec gluetun wget -qO- https://ipinfo.io

# Check Gluetun logs
docker logs gluetun

# Check qBittorrent logs
docker logs qbittorrent
```

## Troubleshooting

**VPN times out / DNS errors:**
- Double-check your WireGuard private key in `.env`
- Try a different `SERVER_CITY`
- Check if your VPN subscription is active

**Permission denied on Docker:**
- Run `sudo chmod 666 /var/run/docker.sock`
- Or add your user to the docker group via DSM

**qBittorrent Web UI not loading:**
- The VPN must be connected first — check `docker logs gluetun`
- Gluetun blocks all traffic until the tunnel is up (this is a feature)

**TUN device not found:**
- Run `sudo insmod /lib/modules/tun.ko`
- Set up the boot task described above

## License

MIT
