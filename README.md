# Shadow-SIP

Shadow-SIP now uses the mature Windows/Android call-management application architecture from [Medut Softphone](https://github.com/Ibrahimgamal99/medut-softphone), adapted and rebranded for Shadow-SIP.

## Setup

Clone with the source submodule:

```powershell
git clone --recurse-submodules https://github.com/maazhossainkhan/Shadow-SIP.git
cd Shadow-SIP
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\prepare-shadow.ps1
cd upstream\medut-softphone
flutter pub get
flutter analyze
flutter test
```

Build Windows: `flutter build windows --release --dart-define=SHADOW_SIP_VERSION=0.2.0`

Build Android: `flutter build apk --release`

GitHub Actions builds and uploads both artifacts.

## Included features

Multiple SIP accounts; connection probing and diagnostics; Add Call, hold/swap and call waiting; blind and attended transfer; incoming REFER handling; call quality metrics; configurable codecs, SRTP, ICE/STUN/TURN and retry policy; contacts and presence; SIP MESSAGE chat; call history and recording controls; Android foreground calling, native incoming-call UI, notifications and optional RFC 8599/FCM push; Windows tray, incoming-call popup, call links, audio-device selection and start-at-login.

## Three-way merge status

**Local three-way audio mixing (you + two remote callers) is not yet included.** The pinned Medut-SDK explicitly documents conference mixing as out of scope. Add Call and call switching are not the same as merging both remote audio streams. This requires a native SDK/media-engine extension; Shadow-SIP will not show a working Merge control until that engine work is implemented and tested.

A SIP provider may also limit simultaneous calls/channels per account. Confirm that Sarkar Communication allows at least two simultaneous call legs.

## Licensing

The application source in `upstream/medut-softphone` is licensed under MPL-2.0. The Medut-SDK dependency is BSD-3-Clause. Keep their notices and source availability when distributing modified builds. See [NOTICE.md](NOTICE.md).
