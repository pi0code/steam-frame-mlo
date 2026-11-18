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
if [[ $pid != 0 ]] && executable=$(readlink -f "/proc/$pid/exe"); then
  "$executable" -v
else
  echo 'Supplicant is not running or is not readable.'
fi
printf 'NetworkManager state: '
nmcli -g GENERAL.STATE device show wlan0 2>/dev/null || true
"$base/bin/query-mlo" || true
# Deliberately omit SSIDs, MAC addresses and IP addresses from shareable status.
iw dev wlan0 link 2>/dev/null | awk '
  /link ID/ { links++ }
  /^[[:space:]]*freq:/ { print "Associated frequency: " $2 " MHz" }
  END { print "MLO links listed by kernel: " links+0 }
'
if systemctl is-active --quiet steam-frame-mlo-rollback.timer; then
  echo 'Automatic rollback: armed'
else
  echo 'Automatic rollback: not armed'
fi
echo 'Listed links confirm association; AP per-link traffic counters are needed to check data use.'
