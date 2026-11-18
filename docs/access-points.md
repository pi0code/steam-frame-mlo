# Access point compatibility

This experiment needs an AP whose hardware, firmware and Wi-Fi configuration
support client MLO across **5 GHz and 6 GHz**. Both links must belong to the same
AP's MLO network. It does not combine arbitrary SSIDs, two unrelated APs, or the
Steam Frame dongle with your home Wi-Fi.

Keep the streaming dongle disconnected while the experiment is enabled. The
[kernel change disabling MLO](https://github.com/evlaV/deckard-linux-no-oopsies/commit/ccd2d670dc6f524a66ba2650e24c5452cc61a070)
cites bugs and concerns about dual-band streaming. This experiment overrides
that policy; dongle coexistence has not been validated. Streaming through the
dongle may fail or become unstable. Restore stock with `./frame-mlo off` or a
reboot before using the dongle again.

## Tested here

UniFi Express 7 APs with MLO enabled, using 5 GHz and 6 GHz on the same Wi-Fi
network. Other AP models and firmware combinations remain unverified.

## UniFi configuration

[Ubiquiti's MLO guide](https://help.ui.com/hc/en-us/articles/25656226682775-Multi-Link-Operation-MLO-in-UniFi-Network)
requires a compatible Wi-Fi 7 AP or integrated gateway and supporting software.
It lists Network 8.2.93+ and AP firmware 7.1.18+ as minimum versions. Those are
vendor minimums, not versions independently validated by this project.

In **Settings > WiFi**, select the network, enable **Multi-Link Operation**, and
ensure both 5 GHz and 6 GHz are enabled. Follow the vendor's security requirements;
[UniFi's settings reference](https://help.ui.com/hc/en-us/articles/32065480092951-UniFi-WiFi-SSID-and-AP-Settings-Overview)
specifies WPA3 for MLO. A Wi-Fi 6E AP, a Wi-Fi 7 AP without 6 GHz, or an AP whose
firmware does not enable the needed MLO combination cannot provide this setup.

For other brands, check the model's own documentation and firmware release notes.
MLO support on paper does not prove interoperability with this experimental
Frame configuration. Recheck association and per-link traffic after firmware or
SteamOS updates.

## Further reading

The community-suggested
[iFeeltech MLO overview](https://ifeeltech.com/blog/wifi-7-multi-link-operation-mlo-explained)
is useful background and a starting point for finding AP/client models. Its
lists are not this project's compatibility matrix. Confirm a candidate against
the manufacturer's current documentation and distinguish client MLO from MLO
used only for an AP's wireless mesh backhaul.

Two associated links do not prove a performance improvement. See the
[validation status](validation.md) for the remaining work.
