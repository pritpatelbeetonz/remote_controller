# Universal TV Remote App — Project Brief for Claude Code

## 1. Goal

Build a cross-platform mobile app (Flutter) that acts as a universal remote control for smart TVs over the local WiFi network — no IR blaster required. Reference/inspiration: "Remote Control for All TV" on the App Store, but this will be built from scratch against each TV platform's own published local-network protocol, not by copying that app.

## 2. Platform

**Flutter** (Dart), targeting iOS and Android from one codebase.

- iOS build/signing still requires Xcode and an Apple Developer account for TestFlight/App Store distribution — Claude Code can write and build the app but cannot handle Apple account enrollment or App Store review.
- Android sideloading/testing has no such gate and can happen immediately via `flutter run` / APK.

## 3. TV platforms to support (all four, phased)

Each platform has a different local-network control protocol. There is no single "universal" protocol — the app needs one adapter per platform behind a shared interface.

### 3.1 Roku — easiest, build first
- **Protocol:** External Control Protocol (ECP), plain HTTP REST on port `8060`, no authentication.
- **Discovery:** SSDP (Roku responds to `M-SEARCH` for `roku:ecp`).
- **Key actions:** `POST /keypress/<KeyName>` (Home, Up, Down, Left, Right, Select, Back, Play, Rev, Fwd, InstantReplay, Info, Backspace, Search, Enter), `POST /launch/<channelId>` to open an app, `GET /query/apps` to list installed apps/channels for the app-launcher feature.
- Reference: [Roku ECP Developer Docs](https://developer.roku.com/dev/docs/external-control-api)

### 3.2 Android TV / Google TV — second
- **Two separate protocols, both needed for full functionality:**
  - **Remote input (power, volume, nav, D-pad):** Android TV Remote v2 protocol over TLS. Port `6467` for one-time pairing (TV displays a 6-digit code, client does a certificate/SHA-256 checksum handshake), port `6466` for the ongoing remote session. Messages are protobuf-framed. No official SDK — reference open-source reimplementations: [louis49/androidtv-remote](https://github.com/louis49/androidtv-remote) (Node.js, used by Home Assistant) and [kud/androidtv-remote](https://github.com/kud/androidtv-remote) (TypeScript) as protocol references to port to Dart.
  - **Media casting (optional, separate feature):** Google Cast SDK for "cast this video/audio to the TV" style control — not the same as button-press remote control. Flutter package: [`flutter_chrome_cast`](https://pub.dev/packages/flutter_chrome_cast) on pub.dev. Treat as a stretch feature, not core remote functionality.
- **Discovery:** mDNS/Bonjour (`_androidtvremote2._tcp` service).

### 3.3 Samsung Tizen — third
- **Protocol:** WebSocket (`wss://`) local API, typically port `8002`. Pairing generates a token on first connect that must be stored and reused.
- **Discovery:** SSDP.
- Reference implementation to study: [Smart-TV-Remote-Control (Flutter, open source)](https://github.com/mazen-salah/Smart-TV-Remote-Control) — implements Samsung Tizen WebSocket v2 control directly, useful as a protocol reference even if not reused as a dependency.

### 3.4 LG webOS — fourth
- **Protocol:** SSAP (Second Screen Application Protocol) over WebSocket, local pairing with an on-screen prompt similar to Samsung's.
- **Important:** LG's own Flutter SDK for building *webOS TV apps* is not what we need and isn't fully released yet — that's for apps that run on the TV itself. We need a **client-side SSAP WebSocket implementation** in the phone app, not LG's SDK. Build this as a raw WebSocket/JSON-RPC client against the documented SSAP command set.
- **Discovery:** SSDP.

## 4. Core features

### Must-have (all phases)
- Power on/off, volume up/down/mute, D-pad navigation (up/down/left/right/select/back/home), play/pause/rev/fwd.
- Local network device discovery + manual IP entry fallback.
- Per-TV pairing/token storage (Samsung, LG, Android TV all require a one-time pairing step; store credentials securely, e.g. `flutter_secure_storage`).
- Multi-TV support: save multiple paired TVs, switch between them.

### App launching
- List installed apps/channels on the TV and launch one with a tap.
- Roku: trivial via `/query/apps` + `/launch/<id>`.
- Android TV / Samsung / LG: each has its own "launch app by ID" command in its respective protocol; app IDs differ per platform and must be looked up per-brand.

### Macros / favorites
- Let the user record a sequence of button presses (or single favorite actions like "Netflix on Living Room TV") and replay with one tap.
- Store locally (e.g. `sqflite` or `hive`) since these are per-user, per-device presets, not something that needs a backend.

## 5. Suggested architecture

- **Protocol adapter pattern:** define a shared Dart interface (e.g. `TvRemoteAdapter`) with methods like `sendKey()`, `launchApp()`, `listApps()`, `pair()`. Implement one adapter per platform (`RokuAdapter`, `AndroidTvAdapter`, `TizenAdapter`, `WebosAdapter`). The UI layer only talks to the interface, never to a specific protocol — this is what makes "universal" actually work.
- **Discovery service:** a combined SSDP + mDNS scanner that fingerprints responses to figure out which adapter to use for a found device.
- **State/storage:** paired devices, tokens, and macros persisted locally; no backend needed for v1.
- **UI:** a single remote screen with a device-switcher, a D-pad, volume/power controls, an app-launcher grid, and a favorites/macros tab.

## 6. Suggested build order (phasing)

1. Flutter project scaffold + shared `TvRemoteAdapter` interface + basic remote UI (D-pad, volume, power).
2. Roku adapter end-to-end (discovery, pairing-free control, app launch) — validates the whole architecture with the simplest protocol.
3. Android TV adapter (pairing flow is the hard part here — get the TLS handshake and protobuf framing working).
4. Samsung Tizen adapter.
5. LG webOS adapter.
6. App-launcher UI wired to all four adapters.
7. Macros/favorites feature.
8. (Stretch) Google Cast media-casting support.

## 7. Known risks / open questions

- Android TV pairing (TLS + protobuf + cert checksum) is the most technically involved piece — budget the most time here.
- Samsung and LG both require the user to accept a pairing prompt on the TV itself the first time; UI needs to guide the user through this.
- No official public SDKs exist for Samsung Tizen or LG webOS *client-side* remote control — implementations are protocol reverse-engineering by the open-source community. Behavior could vary by TV firmware version; test against real hardware per brand, not just docs.
- Decide early whether iOS local network permission prompts (`NSLocalNetworkUsageDescription`, Bonjour service declarations in `Info.plist`) are scoped correctly for every protocol's discovery mechanism, or App Store review may flag it.
- Not building IR blaster support — not present on modern phone hardware, and out of scope.

## 8. What to hand Claude Code first

Start with a prompt like: *"Scaffold a Flutter app with the `TvRemoteAdapter` interface described in this doc, implement the Roku adapter first (SSDP discovery + ECP keypress/launch), and build a basic remote UI (D-pad, volume, power, app grid) that talks to it."* Then iterate adapter by adapter per the phasing above.
