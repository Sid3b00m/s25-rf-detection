# RF Sentinel on the Galaxy S25

A verified mirror of RF Sentinel, a no-root Android counter-surveillance scanner, plus a script
that installs it over adb and applies the permissions and battery settings it needs.

Nothing here is original work. The APK is the unmodified official release build —
see [Sources and licences](#sources-and-licences).

> **Install one app, not two.** This repo originally mirrored OVERWATCH alongside RF Sentinel.
> That was redundant: every OVERWATCH data source is already in RF Sentinel, usually in a fuller
> implementation. See [Why only one app](#why-only-one-app). The OVERWATCH APK is still in the
> release for anyone who wants it, but you do not need it.

## Download to the phone

Open this page in the phone's browser and tap the link:

| App | Download | Size |
|---|---|---|
| RF Sentinel 2.24.0 | [RFSentinel-v2.24.0-release.apk](../../releases/download/v1/RFSentinel-v2.24.0-release.apk) | 48 MB |

Byte-identical to the upstream release:

```
542a3d256f390657bbd5e01a62e0775852bc4df428415ba3fdc2d59d66be086c  RFSentinel-v2.24.0-release.apk
```

## Before you install: turn off Auto Blocker

One UI ships **Auto Blocker** enabled, and it refuses every install that did not come from
Galaxy Store or Play Store. The failure is a generic "app not installed" with no reason given,
so it is worth doing first.

**Settings → Security and privacy → Auto Blocker → off**

Then open the downloaded APK from the notification or **Files → Downloads**, and allow
installing from that source when prompted. You can switch Auto Blocker back on afterwards — it
gates installs, not apps that are already installed.

## After installing

Grant these under **Settings → Apps → RF Sentinel → Permissions**:

- **Nearby devices** — the Bluetooth LE scan, this is the important one
- **Location** — set to **Precise**

RF Sentinel never asks for "Allow all the time" background location. It runs a
`FOREGROUND_SERVICE_LOCATION` service instead, so **While using the app** is enough to keep
scanning with the screen off, as long as you do the next step.

- **Notifications** — allow, the foreground service and alerts need it

Then set **Battery → Unrestricted**. Without this One UI suspends the scan service in the
background; RF Sentinel's own settings screen has a shortcut to it.

RF Sentinel's floating threat bubble and mini map additionally need
**Appear on top** / **Display over other apps**.

## Setting the apps up

RF Sentinel opens a setup wizard on first launch — theme, region, alerts and voice, floating
bubble, car auto-start, camera warnings, cell alerts, camera radius, permissions. Then tap
**Start**.

Several detection categories ship **off by default** — the online feeds because they talk to the
network, which is a privacy tradeoff the app makes you opt into. Turn on the ones you want in
Settings:

- Police aircraft (ADS-B), matched against a bundled 93 KB registry of known LE tail numbers
- Waze police reports — either an OpenWeb Ninja API key, or *Waze direct*, which is free and
  needs no key but sends Waze your IP address
- Hacking tools (Flipper Zero, Pineapple, deauth attacks, evil twins)
- Action and hidden cameras (GoPro, Insta360, WiFi spy cams in setup mode)
- Network cameras (Ring, Arlo, Wyze, Verkada, Axis)

Two more worth knowing about:

- **Cell tower change alert** (Settings) — tells you each time the phone moves to a different
  serving tower. A change while you are parked is a classic fake-tower sign.
- **Offline camera prefetch** — downloads mapped ALPR, speed and red-light cameras for a radius
  you pick (10–200 km), or every mapped Flock camera in the US and Canada. Worth doing once on
  WiFi so camera warnings work without a data connection.

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

**Watcher RF has these compiled in since `2.25.1-w2` — skip this section if you are running it.**
This is for the official RF Sentinel build.

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

### If Motorola never shows up at all

Three separate things keep it quiet, and fixing only one will not help:

- **The bundled presets contain no `vendor:` rules.** Not one, in any of the nine region files,
  and nothing anywhere references Bluetooth company `0x04EC`. Motorola BLE is therefore *named*
  correctly in the UI — `bt_company.tsv` does map `04EC` — but never scored. Only a `vendor:`
  rule, imported or baked in, changes that.
- **The MAC rules score 45, under the default alert threshold of 50.** They are matching; they
  are just not loud enough to surface.
- **Watchlists do not cross package IDs.** Watcher RF is `com.rfsentinel.app.watcher`, so
  anything you imported into the official app lives in different storage and does not carry over.

## Watcher RF — the rebranded build

[**WatcherRF-v2.25.1-w3-foss-release.apk**](../../releases/download/watcher-v2.25.1-w3/WatcherRF-v2.25.1-w3-foss-release.apk)
is RF Sentinel 2.25.1 rebuilt from source with the branding and the Motorola/Cradlepoint rules
compiled in, so there is no theme and no watchlist to import, and nothing to configure.

```
b619006afd5c2980240f541b4a80ec850e892d42001b3f445fad8226c7117910  WatcherRF-v2.25.1-w3-foss-release.apk
```

**It installs alongside the official app.** The package ID is `com.rfsentinel.app.watcher`
rather than `com.rfsentinel.app`, so the two coexist and the official build stays updatable from
upstream. You do not have to uninstall anything.

| Baked in | |
|---|---|
| App name | Watcher RF |
| Launcher icon | New adaptive icon, phosphor green on near-black |
| Default theme | Watcher RF — `#00E676` on `#040604`, Share Tech Mono |
| Header | Code-rain art bundled as a drawable, wordmark `WATCHER_RF` |
| Watchlist | `vendor:Motorola Solutions` at 55 and `vendor:Cradlepoint` at 45, added to the `global` preset |
| Base version | Upstream 2.25.1, including the issue #3 patrol-grouping fix |

### Which devices it runs on

One universal APK, nothing to pick:

| | |
|---|---|
| Android | 8.0 (API 26) through 16 (API 36) |
| CPU | `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64` |
| Screens | densities 120–640, small through xlarge |
| Google services | none — the FOSS flavour, no Play Services, no Mapbox |

Upstream release builds are ARM-only; this one keeps the x86 libraries as well, so the same file
installs in an emulator or on an x86 Chromebook. That is what makes it 43 MB rather than 27 MB —
MapLibre's renderer is roughly 10–13 MB per CPU type. Every hardware feature except plain
Bluetooth is declared `not-required`, so a device without WiFi scanning, GPS, telephony or USB
host is not blocked from installing.

The two vendor rules are the same ones described under
[Optional: boost Motorola and Cradlepoint](#optional-boost-motorola-and-cradlepoint), including
the false-positive warning — Motorola at 55 will alert, and in the field capture behind the
stock scores, 27 of 27 hits on those WiFi prefixes were not body cams. To tone it down, edit or
delete the entry in **Watchlist & rules**; the baked-in rules are ordinary preset entries.

It is also **newer than the official APK above**, which is still 2.24.0. The 2.25.1 release is
the one that fixes the printer false positive described in
[Printers](LEO-RF-CATALOG.md#printers-removed-from-the-alerting-tiers).

### Source

RF Sentinel is GPL-3.0, so redistributing a modified binary obliges me to publish the matching
source. The complete tree is attached to the release as `WatcherRF-v2.25.1-w3-source.zip`, and
[`watcher-rf.patch`](watcher-rf.patch) is the diff against upstream commit `d317888`. Eight
files are modified and six are added (the header art and five icon densities); everything else
is untouched.

Build it with `./gradlew assembleFossRelease`. You will need your own `keystore.properties` —
mine is not in the archive, and the APK above is signed with a key that exists only on my
machine. That also means it can never receive an update from upstream: a new Watcher RF build
has to come from here.

## Custom theme

[rf-sentinel-theme-fsociety.json](../../releases/download/v1/rf-sentinel-theme-fsociety.json) is
a ready-made theme with the code-rain banner already embedded — download it on the phone, then
**Theme maker → Import**, and tick the parts you want.

| Setting | Value |
|---|---|
| Accent | `#00E676` phosphor green |
| Scheme / mode | Vivid, pure black (OLED) |
| Font | Share Tech Mono (the DedSec look) |
| Header | fsociety |
| Banner | `banner-glitch.jpg`, embedded in the file |

### Two things the theme system cannot do

**You can't remove or rename the header wordmark.** On the Glitch and fsociety headers the
wordmark is a hardcoded `RF_SENTINEL` bitmap, and those two styles ignore the theme's `title`
field completely. The other seven styles do honour `title` — but they don't draw the banner at
all. So a banner and a custom title are mutually exclusive, whichever way you go.

**The Glitch and fsociety header art is a fixed palette, not your accent.** fsociety draws in red
(`#C8221A`) with *"HELLO, FRIEND"* and a `fsociety.dat` terminal; Glitch draws in DedSec blue
(`#0070F0`) with *"WE ARE DEDSEC"* and `rf_sentinel.exe`. Your accent colour drives the rest of
the app — buttons, highlights, list accents, the palette the whole UI derives from — but it does
not recolour those two headers.

### Rolling your own

The file is plain JSON, so you can hand-edit it. The app validates on import and silently falls
back to defaults for anything it doesn't recognise, so the allowed values matter:

| Field | Allowed |
|---|---|
| `accent` | Signed 32-bit ARGB int, alpha forced opaque |
| `scheme` | `tonal` `vibrant` `neutral` `expressive` `content` `fidelity` `monochrome` `rainbow` `fruit` |
| `mode` | `system` `light` `dark` `black` |
| `font` | `default` `medium` `light` `condensed` `serif` `mono` `serif-mono` `casual` `cursive` `tech` `file` |
| `header` | `GLITCH` `FSOCIETY` `HUD` `NIGHT_VISION` `CRT` `SUNSET` `STENCIL` `BLUEPRINT` `MASTHEAD` |
| `title` | ≤ 40 chars, ignored by `GLITCH`/`FSOCIETY` |
| `markerStyle` | `navigation` `dot` `arrow` `chevron` `sedan` `hatchback` `wagon` `suv` `pickup` `sports` `racer` `convertible` `mini` `van` `truck` `taxi` `motorcycle` |
| `markerColor` | `red` `orange` `yellow` `gold` `lime` `green` `teal` `cyan` `blue` `navy` `purple` `pink` `white` |
| `markerSize` | 0.6 to 2.0 |

The wrapper must be exactly `{"app":"RF Sentinel","type":"theme","format":1,...}` or the import
is rejected. `assets.banner` is the image base64-encoded, capped at 4 MB decoded; the whole file
is capped around 14 MB.

## Theme banners

Open on the phone and tap one, then in RF Sentinel go to **Theme maker**, set the header style
to **Glitch** or **fsociety**, and add it as the banner picture.

| Banner | Style |
|---|---|
| [banner-spectrum.jpg](../../releases/download/v1/banner-spectrum.jpg) | Cyan RF waveform with radar arcs |
| [banner-cameras.jpg](../../releases/download/v1/banner-cameras.jpg) | Amber-to-red surveillance cameras |
| [banner-glitch.jpg](../../releases/download/v1/banner-glitch.jpg) | Green code rain, CRT tears |

**The header style matters.** The banner is only drawn by the `Glitch` and `fsociety` headers —
the other seven (HUD, Night vision, CRT, Sunset, Stencil, Blueprint, Masthead) ignore it, so the
picture silently will not appear. The header growing from 125dp to 190dp tall is how you know it
took.

If you make your own: keep it under **4 MB**, which is a hard limit rather than a resize
threshold, and make it wide — it is centre-cropped to roughly 1080x570 on an S25, not squashed.
Keep the subject in the **top third**, because a gradient fades the lower part to black so the
wordmark and terminal text stay readable. High-contrast graphics beat photos, since those two
headers slice and offset the banner during the glitch animation.

## Export to WiGLE

RF Sentinel has no native WiGLE export, so [`csv-to-wigle.ps1`](csv-to-wigle.ps1) converts its
CSV into the `WigleWifi-1.4` upload format.

```powershell
.\csv-to-wigle.ps1 .\rfsentinel_session.csv
.\csv-to-wigle.ps1 .\rfsentinel_session.csv -Radio WiFi -OutFile wigle_upload.csv
```

Export from **Settings → Lists, tools & about**. Three scopes carry coordinates and convert;
one does not:

| Export scope | Converts? |
|---|---|
| All nearby devices — this scan | yes |
| Match log only | yes |
| Trip devices | yes |
| All devices ever seen — history | **no — this CSV has no lat/lon at all** |

The script auto-detects which one you handed it and refuses the history export with an
explanation rather than writing a file full of blank coordinates.

Two defaults worth knowing:

**Randomized addresses are dropped.** A rotating MAC will never be seen again, so it is noise in
a database keyed on MAC. Pass `-KeepRandomAddresses` to include them anyway.

How a randomized address is identified depends on the export. The session CSV carries an
`address_type` column — RF Sentinel's own classification — and that is used directly. The match
log and trip exports have no such column, so the address is classified from its own bits:

- **The locally-administered bit** (bit 1 of the first octet) is set. No IEEE assignment ever
  sets it, so this is proof the address was generated rather than issued. In practice it means
  the second hex digit is `2`, `6`, `A` or `E`.
- **For BLE only**, the top two bits of the first octet give the random subtype — `11` static,
  `01` resolvable private, `00` non-resolvable private, `10` reserved. But a *public* BLE address
  can hold any value there, so this test only decides the question when the OUI is also absent
  from the IEEE registry.

That second test needs a registry, so the script loads `ieee\manuf` if it sits next to the
script, or whatever you pass to `-OuiFile`. Without one it says so and falls back to the
locally-administered bit alone, which will let through a BLE random address that happens to
leave that bit clear. Same file [`verify-ouis.ps1`](verify-ouis.ps1) uses:

```powershell
iwr https://www.wireshark.org/download/automated/data/manuf -OutFile ieee\manuf
```

**Missing columns are left empty, not invented.** RF Sentinel does not record AuthMode, channel
or altitude, so those stay blank — WiGLE accepts the rows but ranks sparse ones lower. The
`distance_m` column is deliberately *not* mapped to `AccuracyMeters`: it is the estimated
distance to the device, not GPS accuracy. If you know your accuracy, set it explicitly with
`-AssumeAccuracyMeters 12`.

A device heard on two radios is written as two observations, `W` for WiFi and `E` for BLE.

**The camera pins are not yours to upload.** Those come from DeFlock's OpenStreetMap snapshot
that the app downloaded — they are not RF observations, and the app cannot tell you that you
personally saw any of them. Pushing them into WiGLE copies one database into another. If you
spot a camera in the field, contribute it to [DeFlock](https://deflock.org) or OpenStreetMap,
which is where RF Sentinel reads cameras from in the first place.

## Install over USB instead

With USB debugging on and the phone plugged in, `install-to-s25.ps1` does all of the above
automatically — grants the six runtime permissions, adds the app to the doze whitelist, pins the
standby bucket to active, and allows the overlay. It still installs both APKs if both are
present in the folder; delete `OVERWATCH-v0.5.19.apk` to skip it.

```powershell
powershell -ExecutionPolicy Bypass -File .\install-to-s25.ps1
```

It still cannot turn off Auto Blocker for you — do that on the phone first.

## Why only one app

RF Sentinel is a strict superset of OVERWATCH. Both scan BLE and WiFi against vendor signature
lists, and OVERWATCH's three external data sources all exist in RF Sentinel in a fuller form:

| Data source | OVERWATCH | RF Sentinel |
|---|---|---|
| Waze police reports | `WazeClient`, single-file `wazert` | `WazePolice` + `WazeWatch` + `WazeMotion`, 11-file `wazert`, protobuf codec, dedicated UI, 7 test files |
| DeFlock ALPR map | `DeflockClient` | `DeflockBulk`, plus OpenStreetMap cameras and offline prefetch |
| LE aircraft | `AircraftClient` | `PoliceAircraft` + `AdsbTracker`, with a bundled registry of known LE tail numbers |

On top of that, RF Sentinel has no OVERWATCH counterpart for IMSI-catcher and fake-cell-tower
heuristics, Remote ID drone decoding, AirTag / SmartTag / Tile follow detection, card skimmers,
Android Auto, USB WiFi adapter and ESP32 support, or CSV / KML / GPX export. It is 351 Kotlin
source files against OVERWATCH's 37.

So there is no capability you give up by running RF Sentinel alone, and running both costs you a
second BLE scan client and a second WiFi scan loop. The Android 11+ WiFi scan throttle is per-app
so they would not starve each other, but battery drain roughly doubles for no added coverage.

> An earlier version of this README claimed OVERWATCH uniquely offered a Citizen incident feed.
> That was wrong — OVERWATCH has no Citizen integration.

RF Sentinel is receive-only. It decodes advertisements that devices already broadcast publicly,
and never transmits, connects, pairs, or jams.

## Sources and licences

| App | Upstream | Licence |
|---|---|---|
| RF Sentinel | [CIS-C0/RFSentinel](https://github.com/CIS-C0/RFSentinel) @ [v2.24.0](https://github.com/CIS-C0/RFSentinel/releases/tag/v2.24.0) | GPL-3.0 |
| OVERWATCH *(archived in the release, not needed)* | [KaraZajac/OVERWATCH](https://github.com/KaraZajac/OVERWATCH) @ [v0.5.19](https://github.com/KaraZajac/OVERWATCH/releases/tag/v0.5.19) | BSD-3-Clause |

RF Sentinel is licensed under the GNU General Public License v3.0. The complete corresponding
source for the binary mirrored here is the upstream repository at tag `v2.24.0`, linked above.

The archived OVERWATCH build is `0a4e706d6318d4a3120f838f402f461595f407d00d80c1f63b710a34439783c3`,
also byte-identical to upstream.

To get updates straight from the author rather than from this mirror, use
[Obtainium](https://obtainium.imranr.dev/) pointed at the upstream repository, or RF Sentinel's
built-in **Check for updates**, which verifies new releases against the author's signing key.
