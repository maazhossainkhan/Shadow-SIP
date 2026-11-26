# Third-party notices

## Medut Softphone
The application source in `upstream/medut-softphone` is derived from
[Ibrahimgamal99/medut-softphone](https://github.com/Ibrahimgamal99/medut-softphone),
pinned at commit `d3e2ef1511bb3c6c5c89b56a5aa4adc44edefea6`. It is licensed
under the Mozilla Public License 2.0 (MPL-2.0). The source remains a submodule
so its original history and license notices stay identifiable.

## Medut-SDK
The SIP/media engine dependency in `sdk/Medut-SDK` is derived from
[Ibrahimgamal99/Medut-SDK](https://github.com/Ibrahimgamal99/Medut-SDK),
pinned at commit `b6354b138a56483611723132922edfef8715219b`, under the BSD
3-Clause license. Shadow-SIP applies its local two-call audio-mixing changes
through `scripts/apply-local-conference.py`; the patch is provided as source.

## Shadow-SIP
The original Shadow-SIP v0.1.0 starter files retained in this repository were
authored separately and remain under the repository's MIT license where retained.
