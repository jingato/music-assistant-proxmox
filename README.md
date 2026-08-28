# Music Assistant for Proxmox VE

A Community Scripts-style helper for creating a Debian LXC on Proxmox VE and installing [Music Assistant](https://www.music-assistant.io/) directly inside it.

> [!WARNING]
> Music Assistant officially supports the Home Assistant app and its Docker image. A native Linux/Python server deployment is not an officially supported Music Assistant installation method. This project installs Music Assistant natively because the Community Scripts contribution rules require applications to be installed directly inside the LXC rather than with Docker. Treat this project as experimental until it has been tested across the providers and players you use.

## Quick install

Run this command **as root in the Proxmox VE host shell**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jingato/music-assistant-proxmox/main/ct/musicassistant.sh)"
```

No cloning or manual download is required. The launcher uses the current `community-scripts/core` build engine and automatically fetches the matching installer from this repository.

After the script completes, open:

```text
http://LXC_IP:8095
```

The installer prints the assigned IP address when it finishes.

## Default LXC configuration

| Setting | Default |
| --- | --- |
| OS | Debian 13 |
| Container | Unprivileged LXC |
| CPU | 2 vCPU |
| RAM | 4096 MB |
| Disk | 12 GB |
| Music Assistant port | 8095 |
| Music Assistant data | `/opt/musicassistant/data` |
| Optional local music mount | `/mnt/music` |

The Community Scripts advanced configuration menu can be used during creation if you want to change the normal LXC settings.

## What the script installs

The installer currently:

- creates an unprivileged Debian 13 LXC using the Community Scripts build engine;
- installs Python 3.14 with the Community Scripts `setup_uv` helper;
- installs FFmpeg with `setup_ffmpeg`;
- installs the current stable Music Assistant server release and its provider requirements;
- uses Music Assistant's CPU-only PyTorch package source from `requirements_all.txt`;
- installs the matching official Music Assistant wheel for the selected release;
- attempts to install Music Assistant's checked AirPlay CLI helper;
- creates a persistent data directory at `/opt/musicassistant/data`;
- creates `/mnt/music` as a convenient mount point for local music;
- creates and enables `musicassistant.service`;
- supports the Community Scripts update path.

## Local music library

If your music is stored on the Proxmox host or storage mounted by the host, you can bind-mount it into the LXC.

From the **Proxmox host**:

```bash
pct stop <CTID>
pct set <CTID> -mp0 /path/on/proxmox/music,mp=/mnt/music,ro=1
pct start <CTID>
```

Then configure `/mnt/music` as the local filesystem location in Music Assistant.

For an unprivileged LXC, host filesystem permissions still need to allow the mapped container user to read the files.

## Player discovery / networking

Music Assistant relies heavily on local-network discovery. For the best results:

- place the LXC on the same LAN/VLAN as your speakers and players;
- allow mDNS/multicast between Music Assistant and the player network;
- avoid NAT between Music Assistant and devices when possible;
- make sure Proxmox or guest firewall rules are not blocking discovery traffic.

If devices are on different VLANs, you may need an mDNS reflector/repeater and appropriate inter-VLAN firewall rules.

## Updating Music Assistant

The script includes the standard Community Scripts `update_script()` path. To manually invoke it, run the same launcher **inside the Music Assistant LXC**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jingato/music-assistant-proxmox/main/ct/musicassistant.sh)"
```

When a newer stable Music Assistant GitHub release exists, the updater stops the service, backs up the data directory, refreshes the application/venv, restores the data, and restarts Music Assistant.

## Troubleshooting

Inside the LXC:

```bash
systemctl status musicassistant --no-pager
journalctl -u musicassistant -n 200 --no-pager
```

Follow the log live:

```bash
journalctl -u musicassistant -f
```

Check the installed runtime:

```bash
/opt/musicassistant/venv/bin/python --version
/opt/musicassistant/venv/bin/mass --help
ffmpeg -version
```

For a more verbose container-creation test from the Proxmox host:

```bash
dev_mode="trace,keep,logs,net" bash -c "$(curl -fsSL https://raw.githubusercontent.com/jingato/music-assistant-proxmox/main/ct/musicassistant.sh)"
```

`keep` is useful while developing because a failed installation leaves the LXC in place for inspection.

## Known limitations

The official Music Assistant container includes more than the Python package set. Some providers/features can depend on extra binaries, custom multimedia components, or other container-specific setup. Examples can include certain Snapcast, Spotify Connect, Widevine/DRM, AirPlay, or audio-output paths.

The native installer deliberately does not claim full parity with the official Docker image yet. If a provider fails, please capture the Music Assistant journal output and open an issue with the provider/player being used.

## Project layout

```text
ct/musicassistant.sh
install/musicassistant-install.sh
json/musicassistant.json
```

The layout intentionally mirrors the current Community Scripts / ProxmoxVED structure to make a future upstream contribution easier.

## Community Scripts contribution note

This project is designed around the current `community-scripts/core` split-repository build engine. The CT script explicitly sets `COMMUNITY_SCRIPTS_URL` to this repository when launched via `curl`, because the core engine cannot otherwise infer where an individually downloaded CT script came from.

If this script is eventually merged into `community-scripts/ProxmoxVED`, that repository override should be removed and the normal upstream metadata/license header should be used.

## Why the older MusicAssistantProxmoxVEHelperScript fails on Proxmox 9

The older helper based on the archived tteck scripts checks Proxmox with a regex that effectively matches only the Proxmox 8.1 through 8.3 version families. It is not a true semantic `>= 8.1` version check, so Proxmox 9.x is incorrectly rejected.

Simply changing that check is not sufficient because the older application installer also follows an outdated Music Assistant Python/pip deployment path.

## Credits

- [Music Assistant](https://github.com/music-assistant/server)
- [Community Scripts](https://community-scripts.org/)
- [community-scripts/core](https://github.com/community-scripts/core)

## License

MIT. See [LICENSE](LICENSE).
