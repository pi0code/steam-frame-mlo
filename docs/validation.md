# Validation record

Status: **not ready for public release**. The earlier research setup passed the
checks below. The new installer and the driver/supplicant comparison remain
pending.

## Driver and supplicant isolation

The planned test uses the same Frame, AP lock, Wi-Fi profile and traffic direction
in every case. The driver is unloaded and reloaded between cases; the soft AP
service is stopped for all four. Each supplicant is run with the same command
line flags. At the end the installed driver and supplicant are restored.

| Case | Driver | Supplicant | Association | Data per link |
| --- | --- | --- | --- | --- |
| A | Stock | Installed 2.10 | Pending | Pending |
| B | Stock | Upstream 2.12 | Pending | Pending |
| C | Opt-in + parser fix | Installed 2.10 | Pending | Pending |
| D | Opt-in + parser fix | Upstream 2.12 | Pending | Pending |

Read back the loaded module build ID, actual supplicant executable, kernel MLO
advertisement and link list in each case. During traffic, sample the AP vendor's
per-peer data packet counters. Those counters are more useful here than generic
AP byte counters or the MLO badge. A single short throughput test is not a
controlled performance comparison.

## Earlier research build

- The reviewed parser was compiled for the running Frame kernel; the loaded
  module build ID matched that build.
- Both 5 GHz and 6 GHz associated. AP per-link data packet counts increased on
  both links within a two-second sample interval under load.
- A 2.5 GbE-connected PC sent TCP to Frame at approximately 1.93 Gbit/s with four
  streams over 20 seconds. The reverse direction was approximately 0.46 Gbit/s.
  These runs had retransmissions and were not repeatability measurements.
- Frame-initiated tests to the AP reached approximately 0.70 Gbit/s down and
  0.50 Gbit/s up. Two AP CPU cores were almost fully busy; this is not a useful
  measurement of the radios' combined ceiling.
- A 500 Mbit/s UDP downlink trial received approximately 499 Mbit/s with 0.038%
  loss. Separate 200 Mbit/s trials in both directions had zero reported loss.
- Saturated TCP testing also produced latency spikes and packet loss. Sustained
  VR streaming stability has not been established.

These observations demonstrate use of both links over short intervals. They do
not measure simultaneous RF transmissions or prove a benefit over single-link
Wi-Fi. Earlier research builds included additional diagnostic logging; the new
installer omits that instrumentation and requires its own live check.

## Local regression checks

```sh
bash tests/runtime-recovery.sh
python3 tests/validate-parser.py /path/to/patched/kernel/drivers/net/wireless/ath/ath12k/wmi.c
```

The parser harness compiles the actual source functions, enum and wire structs
under ASan/UBSan and checks 15 synthetic firmware events, including malformed
and multi-record input. The stock parser fails the first cutoff test. The runtime
harness uses fake service/module commands to check recovery failures without
changing networking. These checks do not replace testing on Frame.
