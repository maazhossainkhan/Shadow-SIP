# Shadow-SIP

**A simple, quality-focused SIP softphone for Windows and Android.**

Shadow-SIP is a Flutter application with a native SIP/media engine supplied by [Medut-SDK](https://github.com/Ibrahimgamal99/Medut-SDK). Its interface is intentionally small: Dialer, Call history, Contacts and Settings. It is designed for personal use with an existing SIP account/PBX; it does not include telephone service, a phone number or call credit.

> **Build status:** source milestone v0.1.0. The project has not yet been built or tested against a live PBX in this environment. Do not treat a successful source upload as proof of audio quality or production readiness. Use the GitHub Actions build checks and test calls on both platforms before relying on it.

## Features in v0.1.0

### Calling
- SIP registration using UDP, TCP, TLS, WS or WSS.
- Dial extensions, SIP URIs and PBX-routed telephone numbers.
- Incoming call answer / decline and outgoing call hang-up.
- In-call mute, hold / resume, Android speakerphone, DTMF keypad and blind transfer.
- Simple call screen with call timer and current audio-quality metrics (MOS, RTT, packet loss, jitter and negotiated codec).

### Conference calling
- A configurable **PBX conference-room / bridge extension** in Settings.
- One-tap **Join conference room** button on the Dialer.
- Participants who dial the same PBX room join its server-mixed conference.

**Important:** conference audio mixing is provided by the PBX or conference bridge, not mixed locally by the app. Your PBX administrator must provision a conference room/extension and share its dial string. The current milestone does not yet merge two separate one-to-one calls into a local three-way conference.

### Audio quality and network resilience
- Opus is preferred, followed by G.711 µ-law and A-law for interoperability.
- Opus forward-error correction (FEC) and discontinuous transmission (DTX).
- Adaptive Opus bitrate and an adaptive jitter buffer.
- Quality telemetry every 2 seconds and alerts for MOS below 3.5, packet loss above 5%, jitter above 40 ms and inbound media stalls.
- SIP keepalive / registration recovery with retry backoff and network handover support from Medut-SDK.
- Desktop echo suppression, noise suppression and automatic gain control options through the SDK; mobile audio uses the operating system's voice-communication audio path.
- Optional account-level SRTP, ICE, STUN and TURN settings. TURN credentials are stored in the operating-system secure store.
- Windows microphone and output-device selection.

These are implementation choices intended to protect call quality; they cannot guarantee a particular MOS score. Actual quality depends on the PBX, negotiated codec, endpoint devices, bandwidth, packet loss, NAT/firewall and TURN availability. A TURN relay may be required on restrictive carrier-grade NATs.

### Personal tools and privacy
- Manual two-way WAV recording, saved locally under the app documents directory in `Shadow-SIP/Recordings`.
- Local call history and personal contacts.
- SIP and TURN passwords stored using `flutter_secure_storage`; non-secret profile data, contacts and history stored locally.
- No call audio, contacts or call history are uploaded by this app.

Recording should be enabled only where lawful and with the required consent.

## Platform support

| Platform | Included | Notes |
|---|---|---|
| Windows 10/11 x64 | Flutter runner setup script and app source | SIP stack runs while the process remains open. Tray/minimize-to-tray support is a planned follow-up. |
| Android API 24+ | Flutter runner setup script, native Medut startup and Telecom call integration | Remembered SIP accounts can be restored by the native SDK. Reliable wake-up after process termination needs FCM + an RFC 8599-capable PBX/proxy/push gateway; no Firebase project is bundled yet. |

Android background restrictions and battery optimization differ by device vendor. Test incoming calls on the actual phone and network.

## Requirements

- Flutter **3.44 or newer**.
- Dart 3.12 or newer.
- Windows 10/11 for Windows builds.
- Android API 24+ for Android builds.
- Windows: Visual Studio 2022 with **Desktop development with C++**.
- Android: Android Studio / Android SDK, Android NDK and CMake; accept SDK licences.

The Medut Flutter package is pinned to commit `b6354b138a56483611723132922edfef8715219b` and is pulled from GitHub during `flutter pub get`.

## First-time setup on Windows

1. Extract the repository.
2. Open PowerShell in the repository folder.
3. Generate the native Flutter runners and Android startup hook:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\setup_platforms.ps1
```

4. Fetch dependencies and inspect the source:

```powershell
flutter pub get
flutter analyze
flutter test
```

5. Run on Windows:

```powershell
flutter run -d windows
```

6. To run on Android, enable USB debugging, connect the phone and check the device ID:

```powershell
flutter devices
flutter run -d <your-device-id>
```

Release builds:

```powershell
flutter build windows --release
flutter build apk --release
```

The setup script generates platform scaffolding; it does not change the SIP account or create a PBX.

## Configure SIP

Open **Settings** and enter the details supplied by your SIP provider or PBX administrator.

| Field | Example | Notes |
|---|---|---|
| SIP address / AOR | `201@pbx.example.com` | Extension plus SIP domain |
| SIP password | provider-issued password | Saved in the OS secure credential store |
| Transport | UDP / TCP / TLS / WS / WSS | Must match the PBX endpoint |
| WebSocket URL | `wss://pbx.example.com:8089/ws` | Required for WS/WSS |
| Authentication username | `201` | Only when different from the AOR user |
| Caller ID / display name | `Maaz` | Optional |
| Conference room | `600` | PBX-provisioned conference extension / room |
| Media encryption | RTP / SRTP-SDES / SRTP-DTLS | Must match the PBX media profile |
| ICE / STUN / TURN | `stun:stun.example.com:3478` | Configure only when the PBX/network requires it; TURN often helps on restrictive NAT |

WS/WSS uses DTLS-SRTP and ICE. For UDP/TCP/TLS, SRTP is selectable only when the PBX supports the same SRTP profile. Do not enable SRTP or ICE blindly: mismatched media settings can prevent two-way audio even when SIP registration succeeds.

For calls to the public telephone network, your provider/PBX needs an authorized SIP trunk and its own billing arrangement. The app does not bypass carrier billing or restrictions.

## Audio-quality tuning notes

1. Prefer Opus where the PBX and remote endpoint both support it; G.711 remains enabled for PBX/PSTN interoperability.
2. Keep adaptive jitter buffering and adaptive bitrate enabled unless controlled testing shows a reason to tune them.
3. Keep FEC enabled for Opus. The SDK adapts its FEC behaviour based on RTCP-reported loss.
4. Use wired or good Bluetooth headsets where possible; avoid laptop speakers at high volume because acoustic echo can dominate perceived quality.
5. If one-way/no audio occurs, check negotiated codec and SRTP profile, SIP/RTP ports, PBX NAT settings, STUN/TURN reachability and the selected Windows audio devices.
6. Compare MOS, RTT, jitter and packet loss during repeatable test calls on the same network. A high MOS displayed locally is not a guarantee of the other endpoint's perceived quality.

## Incoming calls / background behaviour

- **Windows:** the SIP engine runs while the Shadow-SIP process is open. Closing the app exits it in v0.1.0. Tray mode and startup-at-login are planned follow-ups.
- **Android:** `ShadowSipApplication` starts the native SIP stack and enables the SDK's Telecom integration. The native SDK can restore remembered accounts. True push wake after Android kills the process requires an FCM sender/service and a PBX/proxy push gateway that supports RFC 8599; configuration is not included in this repository milestone.

## Known limitations and roadmap

- One SIP account in the current Settings UI.
- One selected active call in the current call screen; no local merge of two separate calls.
- Conference calling uses a PBX-hosted conference room/bridge.
- Blind transfer is included; attended transfer UI is planned.
- Manual recording only; no automatic recording or cloud storage.
- No Android/Windows system address-book import yet.
- No Windows tray mode, minimize-to-tray, startup-at-login or desktop incoming-call popup yet.
- No Firebase project, FCM push service or server-side RFC 8599 gateway configuration yet.
- No compiled binaries or real-PBX call-quality certification yet.

## Architecture

- Flutter / Dart: simple UI and local data.
- Medut Flutter SDK: common SIP, RTP, codec, SRTP, ICE and call-control API.
- Android: Medut native Kotlin stack + Telecom integration.
- Windows: Medut C core accessed by Dart FFI.
- PBX / SIP provider: registration, SIP routing, PSTN trunk and (for conference calling) conference bridge.

## SDK and licensing

The SIP/media engine is pinned to [Ibrahimgamal99/Medut-SDK](https://github.com/Ibrahimgamal99/Medut-SDK), commit `b6354b138a56483611723132922edfef8715219b`, licensed BSD 3-Clause. The separate [Medut Softphone](https://github.com/Ibrahimgamal99/medut-softphone) application is MPL-2.0; Shadow-SIP uses the SDK API and a separately authored UI rather than copying that app's application source. Preserve the SDK licence and third-party notices when distributing builds.
