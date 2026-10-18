# Law-enforcement equipment that emits WiFi and BLE

A catalog of police and government surveillance gear that radiates on the bands a phone can
actually hear, with the identifiers a passive scanner can match, and — just as important — a
record of what emits **nothing**.

Every MAC prefix below was resolved against the IEEE registry during compilation. Results of
that audit are in [Verification](#verification). Nothing here is taken on trust from a
community list; several widely-copied lists turned out to be badly wrong, and those are called
out in [Poisoned identifiers](#poisoned-identifiers-do-not-use).

---

## Read this first: most LE gear is invisible

A phone receives 2.4/5 GHz WiFi and Bluetooth LE. That excludes most police radio outright.

**Land mobile radio is not detectable.** P25 and TETRA operate at 700/800 MHz. When a scanner
flags a "Motorola radio" it is never hearing the radio — only a WiFi or BLE management
interface on the same chassis. Same for LoJack (173 MHz), Wavetronix traffic radar (10.5/24
GHz), Opticom signal preemption (2.4 GHz but proprietary spread-spectrum, not WiFi), and C-V2X
roadside units (5.9 GHz).

**Most ALPR backhauls over cellular and beacons nothing.** Flock is the outlier. Motorola
Vigilant, Leonardo/ELSAG, Neology, Jenoptik, Perceptics, Rekor, Ubicquia and Conduent are
undetectable on 2.4 GHz regardless of how many OUIs you add.

**Tactical mesh is not 802.11.** Persistent Systems Wave Relay, Silvus StreamCaster and
TrellisWare TSM run proprietary MANET waveforms with no SSID. A WiFi scanner never sees them.

**Recording is not transmitting.** A camera storing to local flash emits nothing. Several
vendors only radiate during pairing, docking, or upload.

---

## Tier 1 — Field-validated signatures

These have been captured off hardware that was confirmed by eye. They are the only entries that
justify a confident alert.

| Signature | Value | Vendor | Why it is strong |
|---|---|---|---|
| BLE service-data ASCII tag | **`BWCDEVICE`** (no space) | Axon body cams | Confirmed against cameras verified by eye at ~20 ft, −85/−89 dBm. Lives in the **payload**, so it survives BLE MAC randomization where an OUI match does not. On-wire it is little-endian-reversed as `AXJANUSBWCDEVICE` — match both byte orders. The spaced form `BWC DEVICE` is a display string and will never match real hardware |
| BLE advertised name | **`BodyWorn Remote XXXX`** | Utility Inc. | Captured via nRF Connect, 10 distinct MACs all on `00:09:BC`. Raw advert is Flags + Complete Local Name only |
| BLE service UUIDs | **`0x3100`–`0x3500`** on the SIG base UUID | Flock Raven acoustic sensor | Field-captured, and confirmed **absent from the SIG registry** — vendor-squatted, which is exactly why they are distinctive |
| WiFi SSID | **`Flock-`** + ≥4 hex | Flock Safety | Confirmed in firmware and independently via WiGLE. **Largely dead since the SoftAP was disabled ~Dec 2025** |
| BLE name | **`FS Ext Battery`** | Flock external battery | Strongest standalone Flock BLE name. Mostly off since spring 2026 |
| BLE name | **`FS-`** + ≥4 hex, **`Penguin-`** + 10 digits | Flock battery | The 4-hex-digit floor exists because `FS-100` collided with a consumer gadget |
| WiFi probe behavior | Wildcard probe requests, ~125 ms, ascending channel hop | Flock Falcon | From the Qualcomm LOWI geolocation stack. **This is Flock's current primary surface** since the SoftAP went away. Needs a USB WiFi adapter in monitor mode |
| MAC OUI | `00:25:DF` | Axon Enterprise | 3 of 3 untagged hits owner-confirmed as worn cameras. Axon is migrating to rotating BLE MACs, so this degrades over time — prefer the payload tag |

### Bluetooth SIG company identifiers

A SIG company ID is **better evidence than a MAC OUI**: the SIG issues it to the product vendor,
while an OUI names whoever made the radio module. It also survives MAC randomization.

| ID | Registrant | Gear |
|---|---|---|
| `0x034D` | TASER International | Axon cams, holsters, TASERs, Signal Sidearm |
| `0x04EC` | Motorola Solutions | Radios, cameras, in-car video |
| `0x0A45` | 3SI Security Systems | Covert bait trackers — the best covert-tracker identifier that exists |
| `0x025F` | Yardarm Technologies | Holster Aware sensor (supports beacon mode) |
| `0x04BC` | Draegerwerk | Roadside breath/drug screening |
| `0x01F1` | Zebra Technologies | In-car printers |
| `0x0755` | Brother Industries | In-car printers |
| `0x0D98` | E.F. Johnson | P25 radios |
| `0x088F` | Tait International | Radios |
| `0x0145` | Novatel Wireless | Vehicle routers |

Service UUIDs: `0xFC81` (Axon Enterprise), `0xFE6B`/`0xFE6C` (TASER), `0xFD8E`/`0xFE04`
(Motorola Solutions), `0xFE79`/`0xFD66` (Zebra), `0xFDE1`/`0xFDCA` (Fortin), `0xFCDA` (Draeger),
`0xFDA3`/`0xFDA4` (Inseego).

---

## Tier 2 — Registry-verified vendor blocks

The registrant is confirmed, but an OUI names a **company, not a product**. Treat these as weak.

### Body-worn and in-car video

| Prefix | Registrant | Note |
|---|---|---|
| `00:25:DF` | Axon Enterprise, Inc. | Cams, docks, TASER, Fleet |
| `D8:1F:65` | **`Private`** | Field-attributed to Axon; 9 MACs, 8 carrying `BWCDEVICE`. Registrant is genuinely withheld — 1 of 107 such rows |
| `00:1D:96` | WatchGuard Video | Motorola-owned. 9 field MACs, all probe requests for `CPenPD`/`CP3N` |
| `00:23:BD` | Digital Ally, Inc. | Product names `FirstVu`, `EVO-HD`, `VuLink` |
| `00:09:BC`, `00:16:ED` | Utility, Inc | Prefer the `BodyWorn Remote` name |
| `48:46:8D` | Zepcam B.V. | Dedicated body-cam maker — good specificity |
| `FC:01:9E` | Vievu | Axon-acquired 2018, legacy |
| `00:1B:BE` | ICOP Digital | Defunct vendor |
| `00:1C:3F` | International Police Technologies | VisionHawk in-car |
| `38:73:EA:00/28` | L-3 Communications Mobile-Vision | **One /28 only.** The other 15 blocks under `38:73:EA` include LG and Annapurna Labs |
| `9C:83:BF` | PRO-VISION, Inc. | Also school buses |
| `D4:2D:C5` | i-PRO Co., Ltd. | Capture candidates `BWC4000`, `IPS-BTS` |
| `00:22:AF`, `E4:1E:0A:B0/28` | Safety Vision, LLC | Police + transit |
| `00:24:39` | Digital Barriers | Covert COFDM video |
| `64:69:BC`, `9C:06:6E` | Hytera | Mostly commercial DMR |

### ALPR and enforcement cameras

`00:BF:15` / `0C:BF:15` / `00:50:C2:BE:70/36` Genetec · `00:50:C2:10:F0/36` + `70:B3:D5:88:A0/36`
Perceptics · 11 × /36 Quercus · Tattile (10 × /24 + ~20 × /36) · `00:1D:4D` Adaptive Recognition ·
`00:17:3D` Neology · `00:12:8E` Q-Free ASA · `00:40:DE` Elsag Datamat · `00:04:4C` + `48:E3:C3`
Jenoptik · `98:6D:35:60/28` Vitronic · `00:18:29` Gatsometer · `00:30:7E` Redflex · `00:22:9F`
Sensys Traffic · `00:24:AE` Idemia · `70:1A:D5` Avigilon Alta · `04:C3:E6:90/28` Ekin ·
`00:E0:6A` Kapsch · `94:7B:BE` Ubicquia · `B4:1E:52` **Flock Safety — the only block registered
to Flock**.

No IEEE registration exists for Rekor, PlateSmart, RedSpeed, Conduent, Survision or Vysionics.
None of these vendors holds a Bluetooth SIG company ID.

### Radios, vehicle gear, forensics

`00:08:B8` E.F. Johnson · `00:0D:4F` Kenwood · `E0:DA:DC` JVC KENWOOD · `00:0D:CA` Tait
Electronics · `8C:1F:64:A7:80/36` TAIT Global · `00:1E:96` Sepura · `C4:7C:8D:90/28` Airbus
DS-SLC · `28:FD:80:C0/28` Airbus DS Oy · `00:23:B9` Airbus DS Deutschland · `00:04:18` Teltronic
S.A.U. · `00:0F:E3` Damm · `00:26:B3` Thales Communications · `00:12:E0` Codan · `00:14:91`
Daniels/Codan · `00:E1:F8` BK Technologies · `00:30:44` + `00:E0:1C` CradlePoint · Peplink ×4 ·
Sierra Wireless ×6 · Inseego ×5 · `00:1F:9C` Havis · `68:DA:73:B0/28` Gamber-Johnson ·
`08:3C:03:00/28` Federal Signal SSG · `CC:69:B0` Global Traffic Technologies · `58:E8:76:C0/28`
Kustom Signals · `1C:82:59:D0/28` Applied Concepts · `6C:18:11` Decatur Electronics · `00:16:00`
Cellebrite · `70:B3:D5:71:F0/36` Grayshift · `00:50:C2:36:00/36` Digital Receiver Technology ·
`00:50:C2:2A:50/36` Septier · `00:0D:1C` Amesys · `00:18:A6` Persistent Systems · `C4:7C:8D:A0/28`
Silvus · `00:1E:3F` TrellisWare · `98:49:9F` Domo Tactical · `D4:11:D6` ShotSpotter ·
`7C:83:34:40/28` + `84:B3:86:50/28` Fusus · `F8:B5:68:C0/28` 3SI · `00:14:7B` Iteris ·
`00:0E:A5` BLIP Systems · `00:10:5D` + `00:30:E6` Draeger · `70:B3:D5:4E:F0/36` +
`8C:1F:64:5A:20/36` CMI Inc (Intoxilyzer).

### Default SSID patterns worth matching

| Pattern | Vendor | Note |
|---|---|---|
| `<MODEL>-xxx` e.g. `IBR1100-fc1`, `AER2200-450` | Cradlepoint | Last 3 hex of MAC. **AP is on by default and beacons continuously** |
| `PEPWAVE_XXXX` / `PEPLINK_XXXX` | Peplink | Last 4 of serial, not MAC |
| `ARLO_VMB_` / `NTGR_VMB_` | Arlo base station | An SSID is a vendor self-attestation — it beats an OUI because it names the vendor *and* says what the box is |
| `DPB70_XXXXXX`, `DriveProBody20/52` | Transcend body cam | AP is user-activated only |

---

## Verified negatives

Measured absences, not assumptions. These are as operationally useful as the positives.

| Equipment | Finding |
|---|---|
| **LiveView Technologies surveillance trailers** | Two units approached at 2 m across a 50-minute, 105,932-line capture produced **zero** BLE adverts and zero WiFi frames, against a calibration where a 2 m transmitter reads −30 dBm. Cellular + satellite uplink. Caveat: 2.4 GHz only, a 5 GHz-only service AP would have been missed |
| **Whelen / SoundOff Signal lightbars** | Bluetooth exists only in the detachable installer programmer (Whelen Scan-Lock+, SoundOff ConfigureIT). The installed lightbar uses a wired bus and emits nothing |
| **Viridian FACT Duty** | No Bluetooth at all. Holster activation is magnetic; offload is USB |
| **Opticom / GTT** | 2.4 GHz but proprietary spread-spectrum, not WiFi or BLE |
| **BlueTOAD / BlipTrack** | **Receivers, not beacons.** They harvest passing devices' Bluetooth MACs and emit BT Classic *inquiry*. A BLE-only scanner will never see one |
| **Dräger Alcotest 6810/6820/7510, DrugTest 5000** | No Bluetooth; optical/IR link to the printer |
| **Consumer cellular GPS trackers** | LandAirSea, Tracki, Spytec, Optimus, Vyncs, Bouncie hold **no IEEE registration whatsoever**. Any BLE carries a Nordic/TI/SIMCom module prefix. Detectable only by advertised name or service UUID, if at all |
| **Code 3, Feniex, Laser Technology, MPH Industries, Magnet Forensics, Getac, Wolfcom, Reveal Media, Coban (US), Panasonic Arbitrator** | No IEEE block matching the vendor name exists |

---

## Poisoned identifiers (do not use)

Every row below was resolved against the IEEE registry during compilation. These circulate
widely in community lists and are **wrong**.

### Misattributed in `nite-oui-collection` and derivatives

The widely-copied law-enforcement OUI list is **10 of 15 wrong**.

| Prefix | Claimed | Actually registered to |
|---|---|---|
| `00:11:24`, `00:1B:63` | Digital Ally | **Apple, Inc.** |
| `00:1C:23` | Getac | **Dell Inc.** |
| `50:EC:50` | Getac | **Beijing Xiaomi** |
| `00:1F:55` | Axon / TASER | **Honeywell Security China** |
| `00:0F:13` | Axon / TASER | **Nisca Corporation** |
| `00:1A:E9` | WatchGuard | **Nintendo Co., Ltd.** |
| `00:19:86` | WatchGuard | **Cheng Hongjian** |
| `3C:BB:FD` | Panasonic i-PRO | **Samsung Electronics** |
| `E0:13:33` | Panasonic i-PRO | **General Motors** |
| `00:40:8C`, `AC:CC:8E` | Flock Safety | **Axis Communications AB** |

Shipping these flags every nearby iPhone, Dell laptop, Samsung phone, Nintendo Switch and GM
vehicle as police equipment.

### Name collisions

| Prefix | Registrant | Not to be confused with |
|---|---|---|
| `00:58:28`, `00:C0:D4` | Axon Networks Inc. | Axon Enterprise — unrelated legacy networking company |
| `00:01:21`, `00:90:7F` | WatchGuard Technologies | WatchGuard **Video** — the first makes firewalls |
| `00:21:66`, `00:60:D6` | NovAtel Inc. (GNSS, Calgary) | Novatel **Wireless** / Inseego |
| `00:01:D8` | Teltronics, Inc. (Texas telecom) | Teltronic S.A.U. (Spanish TETRA) |
| `54:02:37` | Teltronic **AG**, Switzerland | Unconfirmed whether same entity as Teltronic S.A.U. — treat as unverified |
| `24:A3:F0:7`, `00:1B:C5:0B4` | COBAN SRL, Italy | Coban Technologies (US in-car video) |
| `0x0D46` | Thales **Simulation & Training** | Thales tactical radio |

### Chipset and module makers

`A4:CF:12` + `3C:71:BF` Espressif · `24:B2:B9` + 22 more Liteon · 9 × Silicon Labs · `08:3A:88`
+ `E0:4F:43` USI · `00:03:7F` Atheros · `F4:60:77` Texas Instruments · Murata `VPY…`. These name
the chip, not the product, and sit in millions of laptops, smart plugs and IoT devices.

`48:27:EA`, circulated as a Flock prefix, is **Samsung Electronics** and will flag phones.
`82:6B:F2` and `B8:35:32` are **not IEEE registrations at all** — `0x82` has the
locally-administered bit set, making it a randomized-address prefix.

### Wrong assignments and retracted claims

- **`0xFE6D`**, labeled "Axon Signal System" in SignalSweep, is registered to the
  **University of Tokyo**.
- **`0x09C8` is XUNTONG**, shared silicon — Flock Safety holds no SIG company ID at all.
- **`-FALCON` / `PROBE-FALCON` / `DATA-FALCON` SSIDs**: retired. The strings were a capture
  tool's own diagnostic labels being re-read as broadcast SSIDs. A data frame carries no SSID
  element, so `DATA-FALCON` could never have come off the air.
- **Axon `AB2-`/`AB3-`/`AB4-`/`AXON-` SSIDs**: cited to "Axon admin docs", but Axon's actual
  documentation describes cameras as WiFi **clients**, and FCC grant X4GS01200 authorizes 5 GHz
  in client mode. Unverified.
- **`V300_` SSIDs**: appear across nine unrelated OUI blocks and never on WatchGuard's
  `00:1D:96`. Model-name coincidence.
- **Bare 10-digit BLE name** (Flock): false-positived on a phone named `0102000000`.
- **`89c3debf` probe fingerprint**: retracted, 10 of 19 hits were phones.
- **`0x087F` + `PCAM_`**: Phillips Connect Technologies, **trailer telematics**, not a camera.
- **Kustom Argus ICV beacon UUID**: provisioned per agency at docking. There is no constant.

### Never truncate a long prefix

`70:B3:D5`, `00:50:C2`, `8C:1F:64`, `C4:7C:8D`, `7C:83:34`, `84:B3:86`, `F8:B5:68`, `98:6D:35`,
`38:73:EA`, `04:C3:E6`, `1C:88:79` are **shared IEEE pools**. Each /24 holds 15–16 unrelated
registrants. Observed during verification:

- `70:B3:D5:71:F0/36` is Grayshift — its neighbours are X-Laser, APG Cash Drawer, Peek Traffic, Riot.
- `00:50:C2:36:00/36` is Digital Receiver Technology — neighbours include Tattile, RISCO, XIMEA.
- `38:73:EA:00/28` is L-3 Mobile-Vision — neighbours include LG Electronics and Annapurna Labs.
- `7C:83:34:40/28` is Fusus — neighbours include a thermal-imaging firm and Balter GmbH.
- `84:B3:86:50/28` is Fusus — neighbours include Cobham and FOTILE kitchenware.
- `C4:7C:8D:90/28` is Airbus DS-SLC and `C4:7C:8D:A0/28` is Silvus — **adjacent**. Truncating
  confuses a French TETRA radio with a US tactical mesh node.

---

## Dual-use vendors that must never alert alone

Cradlepoint (transit buses, retail), Sierra Wireless (utility fleets, kiosks), Peplink (RVs,
marine), Inseego (consumer MiFi), Zebra (warehouses), Brother (offices), Panasonic (projectors,
appliances), Dell (~170 blocks), JVCKENWOOD (car audio), Dräger (hospitals, industrial gas),
Hytera (commercial DMR), Fortin (civilian remote starters), Motorola Solutions (retail and venue
staff radios).

The measured case against matching these alone: in field capture, **27 of 27** hits on Motorola
WiFi prefixes were confirmed **not** to be body cameras.

These are only meaningful as **co-occurring roles in a cluster**, which is precisely how RF
Sentinel uses them — two or more different equipment roles whose signal strength correlates at
Pearson r ≥ 0.6 over at least 8 seconds scores as a patrol vehicle. A lone Cradlepoint is a bus.
A Cradlepoint moving in lockstep with a Motorola radio and a body cam is a patrol car.

---

## Ethical exclusion

Offender-monitoring equipment is deliberately omitted from the alerting tiers above even though
it is detectable: `00:24:DB` is Alcohol Monitoring Systems (SCRAM ankle monitors). These
identify **a person on probation, not police**. RF Sentinel excludes them for the same reason.

---

## Verification

Ground truth: Wireshark's IEEE-derived `manuf` file, 58,526 assignments covering MA-L (/24),
MA-M (/28) and MA-S (/36). `standards-oui.ieee.org` answers scripted requests with **HTTP 418**,
so the mirror is the practical source.

| Check | Result |
|---|---|
| RF Sentinel watchlist presets audited | **320 distinct MAC prefixes** across 9 regional presets |
| Registrant corroborates the preset's own label | **318** |
| Flagged for review | **2**, both benign — `00:18:29` is registered "Gatsometer" (Gatso is the brand) and `D8:1F:65` is genuinely `Private`, exactly as its label claims |
| Prefixes not found in the registry | **0** |
| Prefix lengths | 229 × /24, 16 × /28, 75 × /36 |
| Third-party claims independently re-resolved | ~60 further prefixes, including every "do not use" row above |

RF Sentinel's MAC database is **320 for 320 clean** — every prefix resolves to the vendor its
label names. That is a markedly better result than the community lists it drew from, one of
which is 10/15 wrong.

Reproduce with [`verify-ouis.ps1`](verify-ouis.ps1).

## Sources

[all-cameras-are-beacons](https://github.com/soyboi1312/all-cameras-are-beacons) (the clean-room
reference most of this lineage derives from) ·
[RFSentinel SIGNATURES.md](https://github.com/CIS-C0/RFSentinel/blob/main/docs/SIGNATURES.md) ·
[SignalSweep](https://github.com/B0z0dcl0wn/SignalSweep) ·
[FlipDeFlock](https://github.com/ReconGrunt/FlipDeFlock) ·
[Flock-You](https://github.com/colonelpanichacks/flock-you) ·
[wardrive-go](https://github.com/RocketGod-git/wardrive-go) ·
[Fieldwatch](https://github.com/OffGridPete/Fieldwatch) ·
[DeFlock](https://deflock.me) · IEEE registry · Bluetooth SIG Assigned Numbers
(`company_identifiers.yaml`, `member_uuids.yaml`) · FCC OET equipment authorization filings.

Compiled 2026-10-18. Detection is receive-only: everything here is decoded from advertisements
devices already broadcast publicly.
