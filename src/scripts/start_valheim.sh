#!/usr/bin/env bash

cd /home/steam/valheim || exit 1
STEAM_UID=${PUID:=1000}
STEAM_GID=${PGID:=1000}
source /env.sh

log() {
  PREFIX="[Valheim][steam]"
  printf "%-16s: %s\n" "${PREFIX}" "$1"
}

deprecation_notice() {
  log "-------------------------------------------------------------------------"
  log "-------------------------------------------------------------------------"
  log "-------------------------------------------------------------------------"
  log "-------------------------------------------------------------------------"
  log "WARNING: ${1}"
  log "-------------------------------------------------------------------------"
  log "-------------------------------------------------------------------------"
  log "-------------------------------------------------------------------------"
  log "-------------------------------------------------------------------------"
}

line() {
  log "###########################################################################"
}

initialize() {
  line
  log "Valheim Server - $(date)"
  log "STEAM_UID ${STEAM_UID} - STEAM_GUID ${STEAM_GID}"
  log "$1"
  line
}

cleanup() {
  log "Halting server! Received interrupt!"
  odin stop
  if [ "${AUTO_BACKUP_ON_SHUTDOWN:=0}" -eq 1 ]; then
    log "Backup on shutdown triggered! Running backup tool..."
    /bin/bash /home/steam/scripts/auto_backup.sh "shutdown"
  fi
  if [[ -n $TAIL_PID ]]; then
    kill "$TAIL_PID"
  fi
  if [[ -n $ODIN_HTTP_SERVER_PID ]]; then
    kill "$ODIN_HTTP_SERVER_PID"
  fi
}

install_valheim_plus() {
  deprecation_notice "ValheimPlus has been deprecated!!!!!! Please use BepInEx instead!"
#    log "Installing ValheimPlus"
#    VALHEIM_PLUS_DOWNLOAD_URL="${VALHEIM_PLUS_DOWNLOAD_URL:-""}"
#    if [ -z "${VALHEIM_PLUS_DOWNLOAD_URL}" ]; then
#      VALHEIM_PLUS_DOWNLOAD_URL="$(curl -L "${VALHEIM_PLUS_RELEASES_URL}" | jq -r '.assets[] | select(.name=="UnixServer.zip") | .browser_download_url')"
#    fi
#    log "Pulling ValheimPlus from ${VALHEIM_PLUS_DOWNLOAD_URL}"
#    odin mod:install "${VALHEIM_PLUS_DOWNLOAD_URL}"
}

install_bepinex() {
    log "Installing BepInEx"
    BEPINEX_DOWNLOAD_URL="${BEPINEX_DOWNLOAD_URL:-""}"
    if [ -z "${BEPINEX_DOWNLOAD_URL}" ]; then
      echo "Calling: curl -L ${BEPINEX_RELEASES_URL} | jq -r '.latest.download_url'"
      BEPINEX_DOWNLOAD_URL="$(curl -L "${BEPINEX_RELEASES_URL}" | jq -r '.latest.download_url')"
    fi
    log "Pulling BepInEx from ${BEPINEX_DOWNLOAD_URL}"
    odin mod:install "${BEPINEX_DOWNLOAD_URL}"
}

install_bepinex_full() {
    deprecation_notice "BepInExFull has been deprecated!!!!!! Please use BepInEx instead!"
#    log "Installing BepInEx Full"
#    BEPINEX_FULL_DOWNLOAD_URL="${BEPINEX_FULL_DOWNLOAD_URL:-""}"
#    if [ -z "${BEPINEX_FULL_DOWNLOAD_URL}" ]; then
#      BEPINEX_FULL_DOWNLOAD_URL="$(curl -L "${BEPINEX_FULL_RELEASES_URL}" | jq -r '.latest.download_url')"
#    fi
#    log "Pulling BepInEx Full from ${BEPINEX_FULL_DOWNLOAD_URL}"
#    odin mod:install "${BEPINEX_FULL_DOWNLOAD_URL}"
}

initialize "Installing Valheim via $(odin --version)..."
log "Variables loaded....."
log "Port: ${PORT}"
log "Name: ${NAME}"
log "World: ${WORLD}"
log "Public: ${PUBLIC}"
log "With Crossplay: ${ENABLE_CROSSPLAY}"
log "Password: (REDACTED)"

export SteamAppId=${APPID:-892970}

# Setting up server
log "Running Install..."
if [ ! -f "./valheim_server.x86_64" ] ||
  [ "${FORCE_INSTALL:-0}" -eq 1 ]; then
  odin install || exit 1
elif [ "${UPDATE_ON_STARTUP:-1}" -eq 1 ]; then
  log "Attempting to update before launching the server!"
  if [ "${AUTO_BACKUP_ON_UPDATE:=0}" -eq 1 ]; then
    /bin/bash /home/steam/scripts/auto_backup.sh "pre-update-backup"
  fi

  log "Installing Updates..."
  odin install || exit 1
else
  log "Skipping install process, looks like valheim_server is already installed :)"
fi

if [ -f "/home/steam/steamcmd/linux64/steamclient.so" ]; then 
  cp /home/steam/steamcmd/linux64/steamclient.so /home/steam/valheim/linux64/
fi

# Setting up server
log "Initializing Variables...."
odin configure || exit 1

log "Checking for TYPE flag"
export TYPE="${TYPE:="vanilla"}"
log "Found Type ${TYPE}"
log "Running with ${TYPE} Valheim <3"
export TYPE="${TYPE,,}"
export GAME_LOCATION="${GAME_LOCATION:="/home/steam/valheim"}"

if [ "${TYPE}" = "vanilla" ] && [ -n "${MODS:=""}" ]; then
  log "Mods supplied but you are running with Vanilla!!!"
  log "Mods will NOT be installed!."
elif
  # ValheimPlus not yet installed
  { [ "${TYPE}" = "valheimplus" ] && [ ! -d "${GAME_LOCATION}/BepInEx" ] && [ ! -f "${GAME_LOCATION}/BepInEx/plugins/ValheimPlus.dll" ]; } ||
    # ValheimPlus with update on startup or force install
    { [ "${TYPE}" = "valheimplus" ] && { [ "${UPDATE_ON_STARTUP:-0}" -eq 1 ] || [ "${FORCE_INSTALL:-0}" -eq 1 ]; }; }
then
  install_valheim_plus
elif
  # BepInEx not yet installed
  { [ "${TYPE}" = "bepinex" ] && [ ! -d "${GAME_LOCATION}/BepInEx" ] && [ ! -f "${GAME_LOCATION}/BepInEx/core/BepInEx.dll" ]; } ||
    # BepInEx with update on startup or force install
    { [ "${TYPE}" = "bepinex" ] && { [ "${UPDATE_ON_STARTUP:-0}" -eq 1 ] || [ "${FORCE_INSTALL:-0}" -eq 1 ]; }; }
then
  install_bepinex
elif
  # BepInEx not yet installed
  { [ "${TYPE}" = "bepinexfull" ] && [ ! -d "${GAME_LOCATION}/BepInEx" ] && [ ! -f "${GAME_LOCATION}/BepInEx/core/BepInEx.dll" ]; } ||
    # BepInEx with update on startup or force install
    { [ "${TYPE}" = "bepinexfull" ] && { [ "${UPDATE_ON_STARTUP:-0}" -eq 1 ] || [ "${FORCE_INSTALL:-0}" -eq 1 ]; }; }
then
  install_bepinex_full
fi

if [ ! "${TYPE}" = "vanilla" ]; then
  SAVE_IFS=$IFS      # Save current IFS
  IFS=$',\n'         # Change IFS to new line
  # shellcheck disable=SC2206
  MODS=(${MODS:=""}) # split to array $names
  IFS=$SAVE_IFS      # Restore IFS

  for mod in "${MODS[@]}"; do
    log "Installing Mod ${mod}"
    odin mod:install "${mod}"
  done
fi

if [ -d "/valheim-post-install.d/" ]; then
  log "Executing post-install scripts"
  find /valheim-post-install.d/ -type f -executable -exec {} \;
fi

if [ -n "${HTTP_PORT}" ]; then
  huginn &
  export ODIN_HTTP_SERVER_PID=$!
fi

# Setting up script traps
trap 'cleanup' INT TERM

# Starting server
log "Starting server..."
odin start || exit 1

sleep 2

# Initializing all logs
log "Herding Graydwarfs..."
log_names=("valheim_server.log" "valheim_server.err" "output.log" "auto-update.out" "auto-backup.out")
log_files=("${log_names[@]/#/\/home\/steam\/valheim\/logs/}")
touch "${log_files[@]}" # Destroy logs on start up, this can be changed later to roll logs or archive them.

# shellcheck disable=SC2086
tail -F "${log_files[@]}" &
export TAIL_PID=$!

# Waiting for logs.
wait $TAIL_PID
