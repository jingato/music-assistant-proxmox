#!/usr/bin/env bash
# Copyright (c) 2026 John Ingato
# Author: John Ingato (jingato)
# License: MIT | https://github.com/jingato/music-assistant-proxmox/raw/main/LICENSE
# Source: https://www.music-assistant.io/ | Github: https://github.com/music-assistant/server

# APP is not defined in the install script's environment with the current
# community-scripts/core engine, and the install runs with nounset enabled.
APP="${APP:-Music Assistant}"

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  build-essential \
  ca-certificates \
  cifs-utils \
  cmake \
  g++ \
  gcc \
  git \
  libasound2 \
  libavahi-client3 \
  libavahi-common3 \
  libchromaprint1 \
  libconfuse2 \
  libcurl4 \
  libevent-dev \
  libgcrypt20 \
  libglib2.0-0 \
  libjemalloc2 \
  libjson-c5 \
  libnfs14 \
  libportaudio2 \
  libpopt0 \
  libsndfile1 \
  libsodium23 \
  libssl-dev \
  libuuid1 \
  nfs-common \
  pipewire-alsa \
  pkg-config \
  pulseaudio-utils
msg_ok "Installed Dependencies"

UV_PYTHON="3.14" setup_uv
setup_ffmpeg

fetch_and_deploy_gh_release \
  "musicassistant" \
  "music-assistant/server" \
  "tarball" \
  "latest" \
  "/opt/musicassistant/app"

msg_info "Setting up ${APP}"
mkdir -p /opt/musicassistant/data/.cache /mnt/music
$STD uv venv --python 3.14 /opt/musicassistant/venv
export URLLIB3_NO_OVERRIDE=1
$STD uv pip install \
  --python /opt/musicassistant/venv/bin/python \
  --index-strategy unsafe-best-match \
  --no-binary urllib3-future \
  -r /opt/musicassistant/app/requirements_all.txt
release="$(cat ~/.musicassistant)"
$STD uv pip install \
  --python /opt/musicassistant/venv/bin/python \
  --no-deps \
  "music-assistant@https://github.com/music-assistant/server/releases/download/${release}/music_assistant-${release}-py3-none-any.whl"
cd /opt/musicassistant/app
$STD /opt/musicassistant/venv/bin/python -m scripts.fetch_airplay_cli || \
  msg_warn "AirPlay helper binary could not be installed; Music Assistant can still start without it."
msg_ok "Set up ${APP}"

msg_info "Creating Service"
cat <<'EOF_SERVICE' >/etc/systemd/system/musicassistant.service
[Unit]
Description=Music Assistant Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/musicassistant/app
Environment=URLLIB3_NO_OVERRIDE=1
Environment=PYTHONUNBUFFERED=1
ExecStart=/opt/musicassistant/venv/bin/mass --data-dir /opt/musicassistant/data --cache-dir /opt/musicassistant/data/.cache
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF_SERVICE
systemctl enable -q --now musicassistant
msg_ok "Created Service"

if ! systemctl is-active --quiet musicassistant; then
  msg_error "${APP} failed to start. Run: journalctl -u musicassistant -n 200 --no-pager"
  exit 1
fi

motd_ssh
customize
cleanup_lxc
