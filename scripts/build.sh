#!/bin/bash
set -euo pipefail
umask 077
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo/lib/profile.sh"
base=/home/steamos/.local/share/steam-frame-mlo
die() { echo "$*" >&2; exit 1; }

[[ $(id -un) == steamos && $HOME == /home/steamos && $(uname -m) == aarch64 ]] ||
  die 'Run setup as steamos on Steam Frame, without sudo.'
expected_kernel=$(uname -r)
select_kernel_profile "$expected_kernel" || die "Unsupported kernel: $expected_kernel"
[[ ! -e /sys/module/ath12k/parameters/experimental_mlo ]] ||
  die 'Restore stock Wi-Fi before building or updating this experiment.'
[[ ! -d /run/steam-frame-mlo ]] || die 'Run ./frame-mlo off before setup.'
for tool in gcc make git curl tar pkg-config pacman sha256sum modinfo flock; do
  command -v "$tool" >/dev/null || die "Missing build tool: $tool"
done
pkg-config --exists openssl libnl-3.0 libnl-genl-3.0 dbus-1 libelf ||
  die 'Missing development libraries. See the supported SteamOS profile in the README.'
mkdir -p "$base/cache"
exec 9>"$base/build.lock"
flock -n 9 || die 'Another build is running.'
work=$(mktemp -d "$base/build.XXXXXX")
trap 'rm -rf -- "$work"' EXIT

matches() { printf '%s  %s\n' "$2" "$1" | sha256sum --status -c -; }
download() {
  local url=$1 target=$2 digest=$3
  if [[ -f $target ]]; then
    matches "$target" "$digest" || die "Cached archive failed verification: ${target##*/}"
    return
  fi
  # Package mirror URLs may be private. Never print them or enable shell tracing.
  curl --fail --silent --location --proto '=https' --proto-redir '=https' \
    "$url" -o "$target.part" 2>/dev/null || die 'Download failed; retry when connected.'
  matches "$target.part" "$digest" || die 'Download checksum mismatch; stopped before extraction.'
  mv -- "$target.part" "$target"
}
package() {
  local name=$1 version=$2 digest=$3 destination=$4 row found_name found_version url
  local archive="$base/cache/$name-$version.pkg.tar.zst" legacy="$base/cache/$name.pkg.tar.zst"
  # Older releases cached packages by name alone. Reuse a verified match.
  if [[ ! -f $archive && -f $legacy ]] && matches "$legacy" "$digest"; then
    archive=$legacy
  fi
  if [[ ! -f $archive ]]; then
    # This is a URL lookup only. Repeating --nodeps excludes dependency targets.
    row=$(pacman -Sp --print-format '%n %v %l' --nodeps --nodeps "$name" 2>/dev/null) ||
      die "Cannot locate $name in Frame's configured repositories."
    [[ $row != *$'\n'* ]] || die "Ambiguous package result for $name."
    read -r found_name found_version url <<< "$row"
    [[ $found_name == "$name" && $found_version == "$version" && $url == https://* ]] ||
      die "The repository no longer provides the tested $name version ($version)."
    download "$url" "$archive" "$digest"
  else
    matches "$archive" "$digest" || die "Cached $name archive failed verification."
  fi
  mkdir -p "$destination"
  tar --no-same-owner -xf "$archive" -C "$destination"
}

echo 'Fetching and checking the exact kernel headers and build tool.'
package "$headers_package" "$headers_version" "$headers_sha256" "$work/headers"
package pahole "$pahole_version" "$pahole_sha256" "$work/tools"
headers="$work/headers/usr/lib/modules/$expected_kernel/build"
[[ -f $headers/Makefile ]] || die 'The extracted headers do not match the kernel.'

echo 'Fetching the pinned kernel source and applying the two patches.'
git init -q "$work/kernel"
git -C "$work/kernel" remote add origin "$source_url"
git -C "$work/kernel" sparse-checkout set drivers/net/wireless/ath
git -C "$work/kernel" -c protocol.version=2 fetch -q --depth=1 --filter=blob:none origin "$source_commit"
git -C "$work/kernel" checkout -q --detach FETCH_HEAD
[[ $(git -C "$work/kernel" rev-parse HEAD) == "$source_commit" ]] || die 'Unexpected source revision.'
for patch in "$repo"/patches/*.patch; do
  git -C "$work/kernel" apply --check "$patch"
  git -C "$work/kernel" apply "$patch"
done
git -C "$work/kernel" diff --check
echo 'Building the driver. This can take several minutes.'
PATH="$work/tools/usr/bin:$PATH" \
LD_LIBRARY_PATH="$work/tools/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  make -s -C "$headers" M="$work/kernel/drivers/net/wireless/ath/ath12k" -j4 modules
module="$work/kernel/drivers/net/wireless/ath/ath12k/ath12k.ko"
[[ $(modinfo -F vermagic "$module") == "$expected_kernel "* ]] || die 'Module kernel version mismatch.'
mkdir -p "$work/artifacts/bin" "$work/artifacts/lib"
install -m644 "$module" "$work/artifacts/bin/ath12k.ko"

if [[ $use_new_supplicant == yes ]]; then
  echo "Building wpa_supplicant $wpa_version with its upstream default configuration."
  archive="$base/cache/wpa_supplicant-$wpa_version.tar.gz"
  download "https://w1.fi/releases/wpa_supplicant-$wpa_version.tar.gz" "$archive" "$wpa_sha256"
  tar --no-same-owner -xzf "$archive" -C "$work"
  wpa="$work/wpa_supplicant-$wpa_version/wpa_supplicant"
  cp "$wpa/defconfig" "$wpa/.config"
  for option in DRIVER_NL80211 SAE IEEE80211BE CTRL_IFACE_DBUS_NEW CTRL_IFACE_DBUS_INTRO; do
    grep -qx "CONFIG_${option}=y" "$wpa/.config" || die "Missing supplicant option: $option"
  done
  make -s -C "$wpa" -j4 wpa_supplicant wpa_cli
  install -m755 "$wpa/wpa_supplicant" "$wpa/wpa_cli" "$work/artifacts/bin/"
fi
# pkg-config supplies separate compiler arguments here.
# shellcheck disable=SC2046
gcc -Wall -Wextra -o "$work/artifacts/bin/query-mlo" "$repo/scripts/query-mlo.c" \
  $(pkg-config --cflags --libs libnl-3.0 libnl-genl-3.0)
install -m644 "$repo/lib/runtime.sh" "$repo/lib/status.sh" "$work/artifacts/lib/"
# The installed helper must check the kernel this module was built for.
printf 'expected_kernel=%q\nuse_new_supplicant=%q\n' "$expected_kernel" "$use_new_supplicant" \
  > "$work/artifacts/lib/profile.sh"
(
  cd "$work/artifacts"
  sha256sum bin/* lib/* > artifacts.sha256
)
# Nothing under /usr or /etc is replaced. Activation is a separate command.
mkdir -p "$base/bin" "$base/lib"
cp "$work/artifacts/bin/"* "$base/bin/"
cp "$work/artifacts/lib/"* "$base/lib/"
cp "$work/artifacts/artifacts.sha256" "$base/artifacts.sha256"
install -m755 "$repo/frame-mlo" /home/steamos/frame-mlo
echo 'Setup complete. Stock Wi-Fi is still running.'
echo 'From your home directory, run ./frame-mlo on for a 30-minute trial.'
