#!/bin/bash
set -Eeuo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$base/lib/profile.sh"
state=/run/steam-frame-mlo
scan_mask=/sys/module/cfg80211/parameters/cfg80211_block_scans
lockfile=/run/steam-frame-mlo.lock
dropin=/run/systemd/system/wpa_supplicant.service.d/90-steam-frame-mlo.conf
die() { echo "$*" >&2; exit 1; }

restore() {
  local failed=0
  systemctl stop steam-frame-mlo-rollback.timer 2>/dev/null || true
  [[ -d $state ]] || { echo 'No active setup to restore.'; return 0; }
  echo 'Restoring stock Wi-Fi.'
  systemctl stop softapmanager.service NetworkManager.service wpa_supplicant.service || failed=1
  rm -f -- "$dropin" || failed=1
  systemctl daemon-reload || failed=1
  modprobe -r ath12k_wifi7 || failed=1
  modprobe -r ath12k || failed=1
  modprobe ath12k || failed=1
  modprobe ath12k_wifi7 || failed=1
  [[ ! -e /sys/module/ath12k/parameters/experimental_mlo ]] || failed=1
  if [[ -f $state/scan-mask ]]; then
    cat "$state/scan-mask" > "$scan_mask" || failed=1
  fi
  systemctl start wpa_supplicant.service NetworkManager.service || failed=1
  if [[ -f $state/softap-was-active ]]; then
    systemctl start softapmanager.service || failed=1
  fi
  if (( failed )); then
    echo 'Stock restoration encountered an error. Reboot Frame to restore its installed software.' >&2
    return 1
  fi
  rm -rf -- "$state"
  echo 'Stock driver and supplicant restored; NetworkManager is reconnecting.'
}

failed_activation() {
  trap - ERR INT TERM
  echo 'Activation failed or was interrupted; restoring stock Wi-Fi.' >&2
  restore || true
  exit 1
}

preflight() {
  local dropins
  [[ $(uname -r) == "$expected_kernel" && $(uname -m) == aarch64 ]] ||
    die 'This build does not support the running kernel.'
  [[ ! -d $state && ! -e /sys/module/ath12k/parameters/experimental_mlo ]] ||
    die 'An MLO experiment is already loaded. Turn it off before starting this one.'
  [[ -d /sys/module/ath12k_wifi7 ]] || die 'The expected Frame Wi-Fi driver is not loaded.'
  (cd "$base" && sha256sum --status -c artifacts.sha256) || die 'Built artifacts failed verification; rerun setup.'
  dropins=$(systemctl show -p DropInPaths --value wpa_supplicant.service)
  [[ -z $dropins ]] || die 'A supplicant service override is already present. Restore the earlier setup first.'
  systemctl is-active --quiet wpa_supplicant.service || die 'Stock supplicant is not running.'
  systemctl is-active --quiet NetworkManager.service || die 'NetworkManager is not running.'
  nmcli -g GENERAL.STATE device show wlan0 | grep -q '^100' || die 'Connect wlan0 to the access point first.'
}

activate() {
  local duration=${1:-30} connected=no
  [[ $duration =~ ^[0-9]{1,4}$ ]] || die 'Invalid rollback duration.'
  duration=$((10#$duration))
  preflight
  mkdir -m755 "$state"
  if systemctl is-active --quiet softapmanager.service; then touch "$state/softap-was-active"; fi
  trap failed_activation ERR INT TERM
  # Even an untimed session gets a startup watchdog until reconnection succeeds.
  local watchdog=$duration
  (( watchdog > 0 )) || watchdog=3
  systemd-run --unit=steam-frame-mlo-rollback --collect --on-active="${watchdog}min" \
    --timer-property=AccuracySec=1s /bin/bash "$base/lib/runtime.sh" off
  cat "$scan_mask" > "$state/scan-mask.tmp"
  mv "$state/scan-mask.tmp" "$state/scan-mask"
  systemctl stop softapmanager.service NetworkManager.service wpa_supplicant.service
  modprobe -r ath12k_wifi7
  modprobe -r ath12k
  insmod "$base/bin/ath12k.ko" experimental_mlo=1
  modprobe ath12k_wifi7
  echo 0 > "$scan_mask"
  if [[ $use_new_supplicant == yes ]]; then
    mkdir -p "${dropin%/*}"
    cat > "$dropin" <<UNIT
[Service]
ExecStart=
ExecStart=$base/bin/wpa_supplicant -u -s -O /run/wpa_supplicant
UNIT
    systemctl daemon-reload
  fi
  systemctl start wpa_supplicant.service NetworkManager.service
  for ((attempt=0; attempt<60; attempt++)); do
    if nmcli -g GENERAL.STATE device show wlan0 2>/dev/null | grep -q '^100'; then
      connected=yes
      break
    fi
    sleep 1
  done
  if [[ $connected != yes ]]; then
    echo 'Wi-Fi did not reconnect within 60 seconds.' >&2
    failed_activation
  fi
  touch "$state/active"
  if (( duration == 0 )); then
    systemctl stop steam-frame-mlo-rollback.timer
    echo 'Reconnected. No timed rollback; use ./frame-mlo off or reboot to restore stock.'
  else
    echo "Reconnected. Automatic stock restoration is armed for $duration minutes from activation."
  fi
  trap - ERR INT TERM
}

main() {
  (( EUID == 0 )) || die 'Run this through ./frame-mlo on or ./frame-mlo off.'
  case ${1:-} in
    on|off) ;;
    *) die 'Expected on or off.' ;;
  esac
  if [[ $1 == off ]]; then
    # Finish/interrupt an in-progress activation before taking its lock.
    systemctl stop steam-frame-mlo-apply.service 2>/dev/null || true
  fi
  exec 9>"$lockfile"
  flock -w 30 9 || die 'Another Wi-Fi change is still in progress.'
  if [[ $1 == on ]]; then activate "${2:-30}"; else restore; fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
