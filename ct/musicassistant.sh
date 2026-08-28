#!/usr/bin/env bash

# When this script is launched directly from GitHub with curl, the Community
# Scripts engine cannot infer which repository supplied it. Pin the scripts root
# to this repository so build_container() fetches our matching install script.
export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/jingato/music-assistant-proxmox/main}"

_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

# Copyright (c) 2026 John Ingato
# Author: John Ingato (jingato)
# License: MIT | https://github.com/jingato/music-assistant-proxmox/raw/main/LICENSE
# Source: https://www.music-assistant.io/ | Github: https://github.com/music-assistant/server

APP="Music Assistant"
var_tags="${var_tags:-music;media;streaming}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-12}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
#var_arm64="${var_arm64:-no}" # Enable only after an arm64 install/update test has passed.

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/musicassistant/app || ! -x /opt/musicassistant/venv/bin/mass ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "musicassistant" "music-assistant/server"; then
    msg_info "Stopping Service"
    systemctl stop musicassistant
    msg_ok "Stopped Service"

    create_backup /opt/musicassistant/data

    UV_PYTHON="3.14" setup_uv
    setup_ffmpeg

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release \
      "musicassistant" \
      "music-assistant/server" \
      "tarball" \
      "latest" \
      "/opt/musicassistant/app"

    restore_backup

    msg_info "Updating Python Environment"
    rm -rf /opt/musicassistant/venv
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
    msg_ok "Updated Python Environment"

    msg_info "Starting Service"
    systemctl start musicassistant
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:8095${CL}"
