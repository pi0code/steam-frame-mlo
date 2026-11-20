# Implementation

Setup selects the pinned Valve source and headers for the running kernel.
Both profiles use the same two patches. See [kernel profiles](../lib/profile.sh).

## Driver policy

The stock driver deliberately hides MLO capabilities from mac80211. Patch 1
replaces that unconditional exclusion with a read-only `experimental_mlo` module
parameter, defaulting to false. The runtime helper explicitly loads the locally
built module with `experimental_mlo=1`.

This opt-in is specific to the experiment. It does not establish that MLO is safe
for Valve's dongle/dual-interface usage.

## Firmware capability parser

The SBS capability arrives as an array containing nested WMI TLVs. The existing
parser treats the start of that array as the capability payload, so it reads the
wrong word as the band boundary. On the tested firmware this produced 5 rather
than 5900 MHz. That causes the driver's radio mapping to treat the 5 GHz and
6 GHz links as sharing a radio, leading to partner-link deactivation.

The firmware describes one DBS/SBS capability inside the array. Patch 2 clears
the cached cutoff and uses the WMI iterator to reach that capability's payload.
The callback checks the tag and minimum length, then reads the little-endian
cutoff. An empty array leaves the cutoff at zero. A malformed record returns
an error before the driver updates the radio mapping.

## Supplicant

The working research setup uses upstream
[wpa_supplicant 2.12](https://w1.fi/releases/) with its supplied `defconfig`, which
enables nl80211, SAE, IEEE 802.11be, and the DBus control interface needed by
NetworkManager. The supported setup uses this upgrade together with both driver
patches. No custom supplicant patch is needed. See the
[validation status](validation.md) for the remaining work.

## Reversal

Activation verifies the supported kernel and artifact checksums before stopping
network services. It remembers whether `softapmanager` was active, arms a rollback
timer, loads the experimental core driver and the installed Wi-Fi 7 bus module,
and restarts NetworkManager. Failure to reconnect within 60 seconds triggers
restoration.

Restoration removes only this helper's runtime override, reloads installed
modules, and restarts the previously active services. A failed module unload is
reported as failure even if NetworkManager starts again. Both the kernel module
choice and `/run` override disappear on reboot.

The [systemd-run service](https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html)
is detached from the terminal. This is needed because reloading the driver
interrupts the connection carrying SSH. The setup does not grant passwordless
sudo or create persistent system services.
