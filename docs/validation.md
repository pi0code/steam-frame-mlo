# Validation status

This is an early experiment on one Steam Frame and one AP model, with existing
development tools. It is not a general compatibility or performance claim.

Initial checks covered building from source, association on 5 GHz and 6 GHz,
basic connectivity, and automatic return to stock software. In this configuration,
both the driver changes and upstream supplicant 2.12 were needed. A factory-reset
device without the build prerequisites has not been tested.

Still unvalidated:

- Safe coexistence with the Steam Frame streaming dongle.
- Sustained VR streaming, latency under load, and long-term reconnect reliability.
- Repeatable performance benefits over single-link Wi-Fi.
- Other AP models, firmware versions, kernels, and SteamOS builds.

Use the automatic rollback and keep a local way to restore stock. Benchmark
claims will wait for controlled, repeatable testing. See [AP requirements and
the dongle warning](access-points.md) before enabling MLO.
