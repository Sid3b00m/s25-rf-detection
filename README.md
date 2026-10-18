# RF detection apps for the Galaxy S25

Verified mirrors of two no-root Android counter-surveillance apps, plus a script that
installs both over adb and applies the permissions and battery settings they need.

Nothing here is original work. Both APKs are the unmodified official release builds —
see [Sources and licences](#sources-and-licences).

## Download to the phone

Open this page in the phone's browser and tap a link:

| App | Download | Size |
|---|---|---|
| RF Sentinel 2.24.0 | [RFSentinel-v2.24.0-release.apk](../../releases/download/v1/RFSentinel-v2.24.0-release.apk) | 48 MB |
| OVERWATCH 0.5.19 | [OVERWATCH-v0.5.19.apk](../../releases/download/v1/OVERWATCH-v0.5.19.apk) | 20 MB |

These are byte-identical to the upstream releases:

```
542a3d256f390657bbd5e01a62e0775852bc4df428415ba3fdc2d59d66be086c  RFSentinel-v2.24.0-release.apk
0a4e706d6318d4a3120f838f402f461595f407d00d80c1f63b710a34439783c3  OVERWATCH-v0.5.19.apk
```

## Before you install: turn off Auto Blocker

One UI ships **Auto Blocker** enabled, and it refuses every install that did not come from
Galaxy Store or Play Store. The failure is a generic "app not installed" with no reason given,
so it is worth doing first.

**Settings → Security and privacy → Auto Blocker → off**

Then open each downloaded APK from the notification or **Files → Downloads**, and allow
installing from that source when prompted.

## After installing

Grant both apps, under **Settings → Apps → _app_ → Permissions**:

- **Nearby devices** — the Bluetooth LE scan, this is the important one
- **Location** — set to **Precise**

Neither app asks for "Allow all the time" background location. Both run a
`FOREGROUND_SERVICE_LOCATION` service instead, so **While using the app** is enough to keep
scanning with the screen off, as long as you do the next step.

- **Notifications** — allow, the foreground service and alerts need it

Then set **Battery → Unrestricted** for both apps. Without this One UI suspends the scan
service in the background; RF Sentinel's own settings screen has a shortcut to it.

RF Sentinel's floating threat bubble and mini map additionally need
**Appear on top** / **Display over other apps**.

## Setting the apps up

RF Sentinel opens a setup wizard on first launch — theme, region, alerts and voice, floating
bubble, car auto-start, camera warnings, cell alerts, camera radius, permissions. Then tap
**Start**.

Several detection categories ship **off by default**. Turn on the ones you want in Settings:

- Police aircraft (ADS-B)
- Waze reports
- Hacking tools (Flipper Zero, Pineapple, deauth attacks, evil twins)
- Action and hidden cameras (GoPro, Insta360, WiFi spy cams in setup mode)
- Network cameras (Ring, Arlo, Wyze, Verkada, Axis)

Two more worth knowing about:

- **Cell tower change alert** (Settings) — tells you each time the phone moves to a different
  serving tower. A change while you are parked is a classic fake-tower sign.
- **Offline camera prefetch** — downloads mapped ALPR, speed and red-light cameras for a radius
  you pick (10–200 km), or every mapped Flock camera in the US and Canada. Worth doing once on
  WiFi so camera warnings work without a data connection.

OVERWATCH needs no setup — open it and press **START**. Its Waze source wants an `X-App-Token`
in Settings; leave it unconfigured and use RF Sentinel's Waze integration instead.

## Reference: what LE gear actually emits

[`LEO-RF-CATALOG.md`](LEO-RF-CATALOG.md) catalogs law-enforcement and government surveillance
equipment that radiates on WiFi and BLE, the identifiers a passive scanner can match, and the
gear that emits nothing at all. Every MAC prefix in it was resolved against the IEEE registry
during compilation; [`verify-ouis.ps1`](verify-ouis.ps1) reproduces the audit.

Headline results: RF Sentinel's own database is **320 for 320 clean**, while the
widely-copied `nite-oui-collection` law-enforcement list is **10 of 15 wrong** — its "Digital
Ally" prefixes are Apple, its "Getac" prefixes are Dell and Xiaomi, and one "WatchGuard" prefix
is Nintendo.

## Optional: boost Motorola and Cradlepoint

[`watchlist-motorola-cradlepoint.json`](watchlist-motorola-cradlepoint.json) raises two vendors
that ship below RF Sentinel's alert threshold. Download it on the phone, then in the app open
**Watchlist & rules → menu → Import entries (JSON)**.

| Rule | Stock | Boosted | Effect |
|---|---|---|---|
| `vendor:Motorola Solutions` | 45 | **55** | Crosses into "probable", so it alerts at the default threshold |
| `vendor:Cradlepoint` | 35 | **45** | Still below 50 — stays amber, only corroborates |

A `vendor:` rule matches the IEEE registrant *or* the Bluetooth company, so the single Motorola
rule covers both the BLE side (company ID `0x04EC`) and all seven WiFi blocks at once. It is
scoped to "Motorola Solutions" on purpose: a bare `vendor:Motorola` would also match Motorola
Mobility and flag every Moto phone near you.

**This will produce false positives.** In the field capture behind RF Sentinel's signatures, all
27 of 27 hits on Motorola WiFi prefixes turned out not to be body cams — in North America those
blocks are mostly radio infrastructure and commercial gear. The stock scores are low on evidence,
not caution.

Note that neither vendor needs boosting for the case that actually matters. Both already feed the
patrol-vehicle grouping engine, where Cradlepoint carries the "vehicle cellular router" role and
Motorola carries "two-way radio". Two different roles whose signal strength rises and falls
together score 24 + 12x2 + 10 = **58**, which alerts today with no changes. What stays silent is a
lone router or a lone radio, which is usually a bus or a store.

To undo, delete the two entries in **Watchlist & rules**.

## Install over USB instead

With USB debugging on and the phone plugged in, `install-to-s25.ps1` does all of the above
automatically — installs both APKs, grants the six runtime permissions, adds both to the doze
whitelist, pins the standby bucket to active, and allows RF Sentinel's overlay.

```powershell
powershell -ExecutionPolicy Bypass -File .\install-to-s25.ps1
```

It still cannot turn off Auto Blocker for you — do that on the phone first.

## What each app covers

Both scan BLE and WiFi against vendor signature lists, and both read the DeFlock /
OpenStreetMap ALPR camera map, Waze police reports, and ADS-B aircraft. Where they differ:

**Only RF Sentinel:** IMSI-catcher / fake cell tower heuristics, Remote ID drone decoding,
AirTag / SmartTag / Tile follow detection, card skimmers, Android Auto, USB WiFi adapter and
ESP32 support, offline camera prefetch, CSV / KML / GPX export.

**Only OVERWATCH:** the Citizen real-time public-safety incident feed.

RF Sentinel is the one to run day to day. OVERWATCH is worth keeping for Citizen coverage.

Running both at once means two independent BLE scan clients and two WiFi scan loops. The
Android 11+ WiFi scan throttle is per-app so they do not starve each other, but battery drain
roughly doubles against running one alone.

Both apps are receive-only. They decode advertisements that devices already broadcast
publicly, and never transmit, connect, pair, or jam.

## Sources and licences

| App | Upstream | Licence |
|---|---|---|
| RF Sentinel | [CIS-C0/RFSentinel](https://github.com/CIS-C0/RFSentinel) @ [v2.24.0](https://github.com/CIS-C0/RFSentinel/releases/tag/v2.24.0) | GPL-3.0 |
| OVERWATCH | [KaraZajac/OVERWATCH](https://github.com/KaraZajac/OVERWATCH) @ [v0.5.19](https://github.com/KaraZajac/OVERWATCH/releases/tag/v0.5.19) | BSD-3-Clause |

RF Sentinel is licensed under the GNU General Public License v3.0. The complete corresponding
source for the binary mirrored here is the upstream repository at tag `v2.24.0`, linked above.

To get updates straight from the authors rather than from this mirror, use
[Obtainium](https://obtainium.imranr.dev/) pointed at the two upstream repositories, or
RF Sentinel's built-in **Check for updates**, which verifies new releases against the author's
signing key.
