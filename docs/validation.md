# Validation status

This is an early experiment on one Steam Frame and one AP model, with existing
development tools. It is not a general compatibility or performance claim.

Initial checks covered building from source, association on 5 GHz and 6 GHz,
basic connectivity, and automatic return to stock software. In this configuration,
both the driver changes and upstream supplicant 2.12 were needed. A factory-reset
device without the build prerequisites has not been tested.

On SteamOS 0.5.10, two v3 loads reported a 5900 MHz cutoff. After each
return to stock, the installed driver reported 5 MHz on the same firmware
and Wi-Fi reconnected. The loaded v3 module's build ID matched the test
artifact. During a 12-second LAN download, Frame's receive counters rose
on both 5260 MHz and 6295 MHz links of the same AP.

On SteamOS 0.5.9, v3 was built against the matching headers and passed
the parser tests. Live dual-band traffic on that OS was tested with v2.

Still unvalidated:

- Safe coexistence with the Steam Frame streaming dongle.
- Sustained VR streaming, latency under load, and long-term reconnect reliability.
- Repeatable performance benefits over single-link Wi-Fi.
- Other AP models, firmware versions, kernels, and SteamOS builds.

Use the automatic rollback and keep a local way to restore stock. Benchmark
claims will wait for controlled, repeatable testing. See [AP requirements and
the dongle warning](access-points.md) before enabling MLO.
