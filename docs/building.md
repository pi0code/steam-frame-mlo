# Building from stock software

This repository supplies source patches and scripts that build on Frame. It does
not supply a prebuilt kernel module or supplicant. `./frame-mlo setup` starts from
the installed Wi-Fi stack and leaves it running until you explicitly turn MLO on.

The validated setup used SteamOS 0.5.9 with kernel `7.2.0-g344f27110f05`. Build
tools were already installed on the test device before the setup test.
Starting with stock Wi-Fi software has been tested; starting with a factory-reset
OS without those tools has not.

## Existing prerequisites

Setup checks for `gcc`, `make`, `git`, `curl`, `tar`, `pkg-config`, `pacman`,
`sha256sum`, `modinfo` and `flock`. The standard shell tools supplied by SteamOS
are also needed. Development headers and libraries must be discoverable through
pkg-config for `openssl`, `libnl-3.0`, `libnl-genl-3.0`, `dbus-1` and `libelf`.

| Package | Version on the test device |
| --- | --- |
| gcc | 15.2.1+r604+g0b99615a8aef-1 |
| make | 4.4.1-2 |
| git | 2.53.0-1 |
| pkgconf | 2.5.1-1 |
| binutils | 2.46-1 |
| glibc | 2.43+r5+g856c426a7534-1 |
| openssl | 3.6.1-1 |
| libnl | 3.12.0-1 |
| dbus | 1.16.2-1 |
| libelf | 0.194-2 |

The table records the tested environment; setup does not install these packages
or claim compatibility with every combination of their versions. If a tool or
development library is missing, setup stops before touching networking. This
release does not provide a toolchain bootstrap procedure.

## What setup downloads

- The exact Valve kernel source commit in `lib/profile.sh`, then applies the two
  patches under `patches/`.
- The matching kernel header package and pahole build tool, from Frame's own
  configured package repositories. Both have pinned versions and archive hashes.
  They are extracted into the build directory, not installed into the OS.
- Upstream wpa_supplicant 2.12 from w1.fi, verified against its pinned archive hash
  and built with the supplied `defconfig`, including IEEE 802.11be and DBus support.

Package locations are queried with pacman's print-only mode; no package install
transaction runs. Private mirror URLs stay on Frame and are omitted from normal
output. Setup neither supplies those URLs nor guarantees that the exact packages
will remain available after an OS update.

Downloaded archives are cached in `~/.local/share/steam-frame-mlo/cache` and
checked again when reused. Each setup run uses a fresh temporary source/build
directory. Successful artifacts and their checksums are kept in that same data
directory; temporary build files are removed. Source versions and inputs are
pinned, but byte-for-byte identical output across build paths and toolchain
versions is not claimed.

## Activation and removal

Setup itself runs without sudo. `~/frame-mlo on` needs local sudo authentication
to load the built module and select the new supplicant temporarily. It checks
the running kernel and artifact hashes before stopping network services.

`~/frame-mlo off` or a reboot restores the installed Wi-Fi stack. After restoring
stock, deleting `~/frame-mlo` and `~/.local/share/steam-frame-mlo` removes the
helper, downloads and build artifacts. The cloned repository can also be removed.
