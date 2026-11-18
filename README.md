# Steam Frame MLO

Experimental 5 GHz + 6 GHz multi-link operation with a Wi-Fi 7 access
point. Intended for using Frame directly with an AP, with the streaming dongle
disconnected.

> [!WARNING]
> **Risk of bricking your Frame.** Activation loads an experimental kernel driver
> as root. A failure could crash the headset, cut off Wi-Fi and SSH, or leave it
> unusable until you recover SteamOS. Back up important data and make sure you
> can access local recovery before trying this. A timer cannot recover a hung kernel.
>
> **This can interfere with or break Steam Frame wireless dongle streaming while
> enabled.** Dongle coexistence has not been validated. Keep the dongle
> disconnected, and run `./frame-mlo off` or reboot before using it again.
>
> **A compatible Wi-Fi 7 access point is required**, with working **5 GHz + 6 GHz
> MLO enabled on the network you join**. Having two bands or a Wi-Fi 7 label alone
> does not establish compatibility. This project has been tested with UniFi
> Express 7; other APs remain unverified. See [AP compatibility](docs/access-points.md).

This is an early experiment for the specific system below. It combines driver
patches with upstream supplicant 2.12. Long-term stability, dongle coexistence
and performance benefits have not been established. See the short
[validation status](docs/validation.md).

## Supported system

This initial version deliberately accepts one tested kernel. It refuses other
kernels before making network changes.

| Component | Tested version |
| --- | --- |
| Device | Steam Frame, WCN7850 / FastConnect 7800 |
| SteamOS | 0.5.9, build 20261113.6134720 |
| Kernel | `7.2.0-g344f27110f05`, aarch64 |
| Firmware | `WLAN.IOE_HMT.1.1-00018-QCAHMTSWPL_V1.0_V2.0_SILICONZ-1` |
| NetworkManager | 1.52.1-1.5 |
| Installed supplicant | 2:2.10-9.3 |
| Experimental supplicant | Unmodified upstream 2.12 |
| AP used for testing | UniFi Express 7, MLO enabled on the 5/6 GHz network |

An OS update requires a matching source/header profile and fresh testing. Do not
change the kernel string just to bypass the check. Other APs and firmware
versions have not been validated.

## Setup

1. Enable MLO for your AP's 5 GHz + 6 GHz Wi-Fi network, and connect Frame to it
   normally. Check the [AP requirements](docs/access-points.md) first. Keep the
   dongle disconnected. If you have several APs, keep Frame on the same AP during
   testing.
2. On Frame, open a terminal as `steamos`. Have a working local sudo password and
   keep the device awake. SSH is useful for setup, but run activation from Frame's
   console so a Wi-Fi interruption does not strand you.
3. Clone this repository and build:

   ```sh
   git clone https://github.com/pi0code/steam-frame-mlo.git
   cd steam-frame-mlo
   ./frame-mlo setup
   ```

Setup downloads pinned source and packages, verifies archive hashes, and builds
locally. It does not install system packages, disable SteamOS read-only mode, or
activate MLO. It requires an existing compiler and development libraries, plus
access to Frame's configured package repositories. These prerequisites were
already installed on the test device; a factory-reset device has not been
tested. Setup checks for missing tools and stops rather than installing them.
See [build prerequisites and downloads](docs/building.md).

If the exact packages are no longer available, setup stops. Private repository
URLs are never part of this repository or normal setup output.

Builds and downloaded archives live in `~/.local/share/steam-frame-mlo`. A short
helper is installed at `~/frame-mlo`. Keep that data directory until you have
turned the experiment off.

## Turn it on or off

From Frame's home directory:

```sh
./frame-mlo on       # restores stock automatically after 30 minutes
./frame-mlo status
./frame-mlo off      # restore stock now
```

Each switch briefly interrupts Wi-Fi. The helper uses a detached system service
so the switch can finish after SSH disconnects. Starting the service is not proof
that activation succeeded: reconnect and check `status`.

Use `./frame-mlo on 10` for a ten-minute trial. Once you have checked recovery,
`./frame-mlo on 0` disables the session timer; a startup watchdog still protects
the initial switch. Turn it off before starting a new session. Existing MLO
experiments or supplicant service overrides must be removed by their own helper
first.

The helper loads a module from your home directory and temporarily selects the
built supplicant using a service override under `/run`. Installed OS files remain in
place. A normal reboot loads the installed stock software. There is no automatic activation
at boot.

## Check the result

`./frame-mlo status` prints the supplicant version selected by the service,
whether the kernel advertises MLO, and the number of links listed by the kernel.
Its output omits SSID, MAC and IP addresses. During activation the helper saves the SteamOS scan-block setting and clears it
so Frame can discover both bands. Turning MLO off restores the saved setting.
Two associated links alone do not prove that both
carry data. Use AP per-link data packet counters during traffic to verify that.

For a failed switch, run `./frame-mlo off`; if restoration reports an error,
reboot. Local service logs can help:

```sh
sudo journalctl -b -u steam-frame-mlo-apply -u steam-frame-mlo-off -u steam-frame-mlo-rollback
```

System logs may contain network identifiers. Review them before sharing. To
remove this setup, restore stock first, then remove `~/frame-mlo` and
`~/.local/share/steam-frame-mlo`.

## What changes

Two small ath12k patches expose MLO behind an opt-in module parameter and fix
parsing of the firmware's dual-radio capability record. The setup also builds
upstream supplicant 2.12. See
[the implementation notes](docs/implementation.md) and the
[validation status](docs/validation.md).

Scripts and documentation are MIT licensed. The patches use the licenses of the
upstream files they modify. Downloaded kernel and supplicant source retain their
own licenses; this repository does not distribute firmware, OS packages, or
prebuilt modules.
