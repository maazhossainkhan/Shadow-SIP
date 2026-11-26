# Shadow-SIP audio quality profile

Shadow-SIP uses the Medut-SDK audio stack with the following first-release preferences:

| Setting | Value | Intent |
|---|---|---|
| Codec order | Opus, PCMU, PCMA | Wideband voice first; G.711 fallbacks for interoperability |
| Opus target | 32 kbit/s | Voice quality / bandwidth compromise |
| Opus FEC | Enabled | Recover some lost speech frames when supported by the negotiated codec path |
| Opus DTX | Enabled | Reduce silence traffic |
| Bitrate adaptation | Enabled | Respond to RTCP loss reports without a media re-INVITE |
| Jitter buffer | Adaptive, 40–400 ms limits | Balance delay and jitter under variable networks |
| Stats interval | 2 seconds | Call-quality diagnostics |
| MOS threshold | 3.5 | Warn on poor estimated listening quality |
| Loss threshold | 5% | Warn on sustained packet loss |
| Jitter threshold | 40 ms | Warn on excessive jitter |
| Media stall warning | 3 seconds | Warn when inbound RTP stops while call remains active |
| SIP keepalive | 30 seconds | Maintain NAT binding / detect registrar reachability |

## Platform audio

On Android the SDK uses the platform voice-communication audio path and Telecom integration. Android's own audio processing is responsible for voice-path echo handling; SDK noise suppression and AGC are not stacked on top of that path. On Windows the SDK-owned device is the default and the app exposes microphone/output device selection. Software suppression, noise suppression and AGC are enabled in the desktop stack configuration.

## Interoperability

No single media profile works for every PBX. RTP, SDES-SRTP and DTLS-SRTP must match the server. WS/WSS is configured for DTLS-SRTP + ICE. For SIP UDP/TCP/TLS, the user selects SRTP only if their PBX supports it. ICE/STUN/TURN is optional and must be provisioned to match the network and PBX.

## Measurement checklist

Before claiming good call quality, test at least:

- Windows-to-PBX-to-Windows calls on wired and Wi-Fi networks.
- Android-to-PBX-to-Android calls on Wi-Fi and mobile data.
- Android Wi-Fi to mobile-data handover during an established call.
- Calls behind restrictive NAT with a working TURN relay.
- Calls using Opus and fallback G.711.
- A PBX-hosted conference room with 3+ participants.
- MOS, RTT, jitter, loss and one-way audio checks at both endpoints.

The configured values are conservative starting points, not a guaranteed MOS result. PBX configuration, device hardware, network congestion and routing determine the final result.
