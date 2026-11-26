# Changelog

## 0.2.0
- Replaced the limited single-call starter with the Medut call-management base for Windows and Android.
- Added multi-account calling, Add Call, call waiting, hold/swap, blind and attended transfer, SIP messages, presence, diagnostics, native Android calling and Windows tray support.
- Added device-local 3-way call mixing: Android native PCM mix and Windows shared-mode WASAPI mix, with Merge/Unmerge controls.
- Android merge validates that both media legs have matching PCM formats; unsupported combinations fail safely rather than mixing incompatible buffers.
- Removed the incorrect PBX conference-room shortcut.
