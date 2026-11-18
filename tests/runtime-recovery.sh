#!/bin/bash
# Exercise restoration without root, real service changes, or real module loads.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
source "$repo/lib/runtime.sh"
state="$scratch/state"
dropin="$scratch/service/90-steam-frame-mlo.conf"
scan_mask="$scratch/scan-mask"
echo 5 > "$scan_mask"
calls="$scratch/calls"
failure=
systemctl() {
  printf 'systemctl %s\n' "$*" >> "$calls"
  [[ $failure != "systemctl $*" ]]
}
modprobe() {
  printf 'modprobe %s\n' "$*" >> "$calls"
  [[ $failure != "modprobe $*" ]]
}
prepare() {
  mkdir -p "$state" "${dropin%/*}"
  touch "$state/active" "$dropin" "${dropin%/*}/unrelated.conf"
  : > "$calls"
}
assert_line() { grep -Fxq -- "$1" "$calls"; }

prepare
touch "$state/softap-was-active"
restore > "$scratch/output"
[[ ! -d $state && ! -e $dropin && -f ${dropin%/*}/unrelated.conf ]]
assert_line 'systemctl start softapmanager.service'
assert_line 'modprobe ath12k'
assert_line 'modprobe ath12k_wifi7'
echo 'PASS: successful restore removes only its override and restarts the previous soft AP'

prepare
restore > "$scratch/output"
! grep -Fxq 'systemctl start softapmanager.service' "$calls"
echo 'PASS: an initially stopped soft AP stays stopped'

prepare
failure='modprobe -r ath12k'
if restore > "$scratch/output" 2>&1; then
  echo 'FAIL: a failed module unload was reported as a successful restore' >&2
  exit 1
fi
[[ -d $state && ! -e $dropin ]]
assert_line 'systemctl start wpa_supplicant.service NetworkManager.service'
grep -q 'Reboot Frame' "$scratch/output"
! grep -q 'Stock driver and supplicant restored' "$scratch/output"
echo 'PASS: failed driver unload still attempts networking recovery and reports failure'

failure=
restore > "$scratch/output"
[[ ! -d $state ]]
restore > "$scratch/output"
grep -q 'No active setup to restore' "$scratch/output"
echo 'PASS: recovery can be retried and repeated without a needless Wi-Fi interruption'

prepare
if (failed_activation) > "$scratch/output" 2>&1; then
  echo 'FAIL: interrupted activation returned success' >&2
  exit 1
fi
[[ ! -d $state ]]
echo 'PASS: activation error handler restores stock and exits unsuccessfully'

# Run the real switching sequence with a fake device and isolated /run paths.
preflight() { printf 'preflight\n' >> "$calls"; }
systemd-run() { printf 'systemd-run %s\n' "$*" >> "$calls"; }
insmod() { printf 'insmod %s\n' "$*" >> "$calls"; [[ $failure != insmod ]]; }
nmcli() { echo '100 (connected)'; }
sleep() { :; }

: > "$calls"
activate 30 > "$scratch/output"
[[ $(cat "$scan_mask") == 0 ]]
[[ -f $state/active && -f $dropin ]]
awk '
  /^systemd-run / { armed=1 }
  /^systemctl stop softapmanager.service / { if (!armed) exit 1; switched=1 }
  END { if (!switched) exit 1 }
' "$calls"
echo 'PASS: rollback is armed before network services stop'
restore > "$scratch/output"

[[ $(cat "$scan_mask") == 5 ]]
failure=insmod
: > "$calls"
set +e
(set -e; activate 30) > "$scratch/output" 2>&1
result=$?
set -e
[[ $result != 0 && ! -d $state && ! -e $dropin ]]
grep -q 'Activation failed' "$scratch/output"
assert_line 'systemctl start wpa_supplicant.service NetworkManager.service'
echo 'PASS: a module load failure triggers automatic restoration'

failure=
nmcli() { echo '30 (disconnected)'; }
: > "$calls"
set +e
(set -e; activate 30) > "$scratch/output" 2>&1
result=$?
set -e
if [[ -d $state ]]; then cat "$scratch/output" >&2; fi
[[ $result != 0 && ! -d $state && ! -e $dropin ]]
grep -q 'did not reconnect' "$scratch/output"
echo 'PASS: a failed Wi-Fi reconnection triggers automatic restoration'

nmcli() { echo '100 (connected)'; }
: > "$calls"
activate 0 > "$scratch/output"
grep -q '^systemd-run .*--on-active=3min ' "$calls"
assert_line 'systemctl stop steam-frame-mlo-rollback.timer'
[[ -f $state/active ]]
restore > "$scratch/output"
echo 'PASS: an untimed session has a startup watchdog that is removed after reconnection'
