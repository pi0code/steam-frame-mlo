#!/bin/bash
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
printf 'Kernel: %s\n' "$(uname -r)"
if [[ -r /sys/module/ath12k/parameters/experimental_mlo ]]; then
  printf 'Experimental driver MLO: %s\n' "$(cat /sys/module/ath12k/parameters/experimental_mlo)"
else
  echo 'Driver: stock'
fi
pid=$(systemctl show -p MainPID --value wpa_supplicant.service)
if [[ $pid != 0 ]]; then
  executable=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
  label='Running supplicant'
  if [[ -z $executable ]]; then
    # /proc hides root process executables from the unprivileged steamos user.
    launch=$(systemctl show -p ExecStart --value wpa_supplicant.service)
    if [[ $launch =~ path=([^\;[:space:]]+) ]]; then executable=${BASH_REMATCH[1]}; fi
    label='Supplicant selected by service'
  fi
  case $executable in
    /usr/bin/wpa_supplicant|"$base/bin/wpa_supplicant")
      printf '%s: ' "$label"
      "$executable" -v | sed -n '1p'
      ;;
    *) echo 'Unrecognized supplicant service executable.' ;;
  esac
else
  echo 'Supplicant is not running.'
fi
printf 'NetworkManager state: '
nmcli -g GENERAL.STATE device show wlan0 2>/dev/null || true
"$base/bin/query-mlo" || true
# Deliberately omit SSIDs, MAC addresses and IP addresses from shareable status.
iw dev wlan0 link 2>/dev/null | awk '
  /^[[:space:]]*Link [0-9]+ BSSID / { links++ }
  /^[[:space:]]*freq:/ { print "Associated frequency: " $2 " MHz" }
  END { print "MLO links listed by kernel: " links+0 }
'
if systemctl is-active --quiet steam-frame-mlo-rollback.timer; then
  echo 'Automatic rollback: armed'
else
  echo 'Automatic rollback: not armed'
fi
echo 'To check traffic on both links, compare AP data counters or Frame receive counters per link during a download.'
