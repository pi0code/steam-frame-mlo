# Validation record

The driver/supplicant comparison and the new setup's native build, activation,
traffic and automatic rollback checks completed on 2026-11-17. Both components
needed to change for MLO association in the tested configuration. This was one
Frame with existing build prerequisites, not a factory-reset device.

## Driver and supplicant isolation

The test used the same Frame, Wi-Fi profile and traffic direction in every case.
The driver was unloaded and reloaded between cases; the soft AP service was
stopped for all four. Each supplicant ran with the same command line flags.
Loaded module build IDs and actual supplicant executable paths were recorded.

| Case | Driver | Supplicant | Kernel advertises MLO | Association |
| --- | --- | --- | --- | --- |
| A | Stock | Installed 2.10 | No | One 5 GHz link |
| B | Stock | Upstream 2.12 | No | One 6 GHz link |
| C | Opt-in + parser fix | Installed 2.10 | Yes | One 6 GHz link |
| D | Opt-in + parser fix | Upstream 2.12 | Yes | 5 GHz + 6 GHz |

The AP lock was released after the first case because Frame had moved farther
from that AP. Cases B, C and D all used the same nearer AP. Both APs were UniFi
Express 7 devices with MLO enabled and 2.5 GbE uplinks. Case D listed link IDs 1
and 2 at 5745 and 6295 MHz; the kernel reported `valid_links=0x6`,
`active_links=0x6`, and `dormant_links=0x0000`. The other cases reported no MLO
links. All four passed a short TCP connectivity test. The runner then restored
the stock module and service configuration, reconnected Wi-Fi, restarted the
soft AP service, and stopped its rollback timer.

The three cases on the same AP show that neither the patched driver nor the
new supplicant alone enabled MLO. Supplicant 2.12 is unmodified upstream code;
only the driver needs custom patches. This comparison tests the two driver
changes together; it does not independently isolate policy exposure from the
parser correction.

AP per-link traffic counters in this run were unavailable after roaming: the
collector had access only to the original AP. The case D result establishes two
active kernel links, not measured data use on each radio. Earlier tests below
did measure per-link data. The AP/location change and short samples also mean
these runs should not be used to claim a throughput improvement.

## New setup workflow

The test started with the installed driver and supplicant 2.10 running. The
installer's cache and build directory were initially empty. Setup downloaded
and checked the pinned header and pahole packages, kernel source, and supplicant
source; it compiled locally without installing system packages. A second build
also checked the verified-download cache path. Existing development tools and
libraries were reused; the installer does not bootstrap a missing toolchain.

The new driver contained only the opt-in and parser patches, without the research
build's extra diagnostic logging. Its loaded build ID matched the newly compiled
module. With upstream supplicant 2.12 selected, both 5745 and 6295 MHz links
associated. The corrected status helper reported two links.

Two ten-second TCP tests, each limited to 200 Mbit/s, received approximately
199.6 Mbit/s PC-to-Frame and 198.0 Mbit/s Frame-to-PC. They reported two and one
retransmissions respectively. All 50 concurrent ping probes returned; average
RTT was 14.8 ms and maximum RTT was 59.7 ms. These are short connectivity checks,
not measurements of maximum throughput or sustained VR performance.

`./frame-mlo on 3` restored the stock driver and supplicant 2.10 automatically.
Wi-Fi reconnected, the previously active soft AP service restarted, the runtime
override and state directory disappeared, and the rollback timer stopped. The
status helper then reported stock software, no advertised MLO, and zero MLO
links. The tested scripts and patches matched the repository files.

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
installer omits that instrumentation and passed the separate check above.

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
