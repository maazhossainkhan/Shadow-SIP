# Shadow-SIP

Shadow-SIP is a Windows and Android SIP softphone based on the Medut Softphone call engine, with Shadow-SIP branding and a device-local 3-way call feature.

## Setup

Clone both pinned source submodules:

```powershell
git clone --recurse-submodules https://github.com/maazhossainkhan/Shadow-SIP.git
cd Shadow-SIP
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\prepare-shadow.ps1
python .\scripts\apply-local-conference.py
cd upstream\medut-softphone
flutter pub get
flutter analyze
flutter test
```

For Android native libraries, install Android NDK 28.2.13676358, CMake and Ninja, set `ANDROID_NDK`, then run:

```bash
bash sdk/Medut-SDK/scripts/build-android.sh
```

Build Windows: `flutter build windows --release --dart-define=SHADOW_SIP_VERSION=0.2.0`

Build Android: `flutter build apk --release`

GitHub Actions builds and uploads both artifacts.

## Calling features

Multiple SIP accounts; connection probing and diagnostics; Add Call, hold/swap and call waiting; blind and attended transfer; incoming REFER handling; call quality metrics; configurable codecs, SRTP, ICE/STUN/TURN and retry policy; contacts and presence; SIP MESSAGE chat; call history and recording controls; Android foreground calling, native incoming-call UI, notifications and optional RFC 8599/FCM push; Windows tray, incoming-call popup, call links, audio-device selection and start-at-login.

## Local 3-way calling

During a call, use **Add Call** to call a second person, then tap **Merge**. Both remote parties and the local user can talk simultaneously. **Unmerge** returns to a normal two-call/hold state. The mix is performed on the device; no PBX conference room or conference extension is used.

Android uses a single VOICE_COMMUNICATION microphone/speaker engine and a native PCM mixer. It requires both calls to have matching negotiated audio formats; if they differ or media is not ready, Merge is rejected and the original call state is restored. Windows uses shared-mode WASAPI capture/render sessions for local device mixing.

The SIP provider must allow at least two simultaneous calls/channels on the account. Sarkar Communication's account policy still needs confirmation. Headphones are recommended on Windows to avoid acoustic echo.

## Licensing

The application source in `upstream/medut-softphone` is licensed under MPL-2.0. The Medut-SDK dependency in `sdk/Medut-SDK` is BSD-3-Clause. The local-conference modifications are applied by `scripts/apply-local-conference.py`; keep the upstream license notices and the patch source when distributing. See [NOTICE.md](NOTICE.md).
