import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:medut/medut.dart';

import '../services/profile_store.dart';
import '../services/sip_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final SipController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _uri, _password, _serverUrl, _authUser;
  late final TextEditingController _displayName, _conference, _stun, _turn;
  late final TextEditingController _turnUser, _turnPassword;
  Transport _transport = Transport.udp;
  MediaEncryption _encryption = MediaEncryption.none;
  bool _ice = false;

  @override
  void initState() {
    super.initState();
    final p = widget.controller.savedProfile;
    _uri = TextEditingController(text: p?.uri ?? '');
    _password = TextEditingController(text: p?.password ?? '');
    _serverUrl = TextEditingController(text: p?.serverUrl ?? '');
    _authUser = TextEditingController(text: p?.authUser ?? '');
    _displayName = TextEditingController(text: p?.displayName ?? '');
    _conference = TextEditingController(text: p?.conferenceUri ?? '');
    _stun = TextEditingController(text: p?.stunServer ?? '');
    _turn = TextEditingController(text: p?.turnServer ?? '');
    _turnUser = TextEditingController(text: p?.turnUser ?? '');
    _turnPassword = TextEditingController(text: p?.turnPassword ?? '');
    _transport = p?.transport ?? Transport.udp;
    _encryption = p?.mediaEncryption ?? MediaEncryption.none;
    _ice = p?.iceEnabled ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _uri, _password, _serverUrl, _authUser, _displayName, _conference,
      _stun, _turn, _turnUser, _turnPassword,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final locked = c.isConnected || c.busy;
    final ws = _transport == Transport.ws || _transport == Transport.wss;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
          children: [
            const Text('Settings', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Configure your personal SIP phone', style: TextStyle(color: Color(0xFF9AA8C0))),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section(Icons.account_circle_outlined, 'SIP account'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _uri,
                        enabled: !locked,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'SIP address / AOR', hintText: '201@pbx.example.com', prefixIcon: Icon(Icons.alternate_email_rounded)),
                        validator: (v) => v == null || !v.contains('@') ? 'Enter a SIP address such as 201@pbx.example.com' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _password, enabled: !locked, obscureText: true, decoration: const InputDecoration(labelText: 'SIP password', prefixIcon: Icon(Icons.lock_outline_rounded))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Transport>(
                        initialValue: _transport,
                        decoration: const InputDecoration(labelText: 'SIP transport'),
                        items: [for (final t in Transport.values) DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))],
                        onChanged: locked ? null : (v) => setState(() => _transport = v ?? Transport.udp),
                      ),
                      if (ws) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _serverUrl,
                          enabled: !locked,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(labelText: 'WebSocket server URL', hintText: 'wss://pbx.example.com:8089/ws'),
                          validator: (v) => ws && (v == null || v.trim().isEmpty) ? 'A WS/WSS URL is required' : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(controller: _authUser, enabled: !locked, decoration: const InputDecoration(labelText: 'Authentication username (optional)')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _displayName, enabled: !locked, decoration: const InputDecoration(labelText: 'Caller ID / display name (optional)')),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFF29364D)),
                      const SizedBox(height: 14),
                      _section(Icons.groups_2_outlined, 'Conference calling'),
                      const SizedBox(height: 12),
                      TextFormField(controller: _conference, enabled: !locked, decoration: const InputDecoration(labelText: 'PBX conference room / bridge', hintText: '600 or conference@pbx.example.com')),
                      const SizedBox(height: 8),
                      const Text('The PBX must provision this conference room. Everyone who dials the same room joins its server-mixed conference.', style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF9AA8C0))),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFF29364D)),
                      const SizedBox(height: 14),
                      _section(Icons.tune_rounded, 'Media & network'),
                      if (!ws) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<MediaEncryption>(
                          initialValue: _encryption,
                          decoration: const InputDecoration(labelText: 'Media encryption'),
                          items: const [
                            DropdownMenuItem(value: MediaEncryption.none, child: Text('RTP (PBX default)')),
                            DropdownMenuItem(value: MediaEncryption.sdes, child: Text('SRTP · SDES')),
                            DropdownMenuItem(value: MediaEncryption.dtlsSrtp, child: Text('SRTP · DTLS')),
                          ],
                          onChanged: locked ? null : (v) => setState(() => _encryption = v ?? MediaEncryption.none),
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        const Text('WSS uses DTLS-SRTP and ICE for WebRTC interoperability.', style: TextStyle(fontSize: 12, color: Color(0xFF9AA8C0))),
                      ],
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _ice,
                        onChanged: locked ? null : (v) => setState(() => _ice = v),
                        title: const Text('Enable ICE / NAT traversal'),
                        subtitle: const Text('Use STUN/TURN when required by your PBX or network.'),
                      ),
                      if (_ice) ...[
                        const SizedBox(height: 8),
                        TextFormField(controller: _stun, enabled: !locked, decoration: const InputDecoration(labelText: 'STUN server', hintText: 'stun:stun.example.com:3478')),
                        const SizedBox(height: 10),
                        TextFormField(controller: _turn, enabled: !locked, decoration: const InputDecoration(labelText: 'TURN server', hintText: 'turn:turn.example.com:3478')),
                        const SizedBox(height: 10),
                        TextFormField(controller: _turnUser, enabled: !locked, decoration: const InputDecoration(labelText: 'TURN username')),
                        const SizedBox(height: 10),
                        TextFormField(controller: _turnPassword, enabled: !locked, obscureText: true, decoration: const InputDecoration(labelText: 'TURN password')),
                      ],
                      const SizedBox(height: 14),
                      _infoBox('SIP and TURN passwords are stored in the operating system secure credential store. Other profile data stays on this device.'),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: c.busy ? null : (c.isConnected || c.registrationState == RegState.registering || c.registrationState == RegState.reconnecting) ? c.disconnect : _connect,
                                icon: Icon(c.isConnected ? Icons.link_off_rounded : Icons.link_rounded),
                                label: Text(c.busy ? 'Please wait…' : (c.isConnected || c.registrationState == RegState.registering || c.registrationState == RegState.reconnecting) ? 'Disconnect' : 'Connect account'),
                                style: FilledButton.styleFrom(backgroundColor: c.isConnected ? const Color(0xFF9B435B) : const Color(0xFF6657D9), foregroundColor: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(tooltip: 'Forget saved account', onPressed: c.busy ? null : _forget, icon: const Icon(Icons.delete_outline_rounded)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(c.isConnected ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 18, color: c.isConnected ? const Color(0xFF36D6A0) : const Color(0xFFF4BB55)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(c.registrationMessage, style: const TextStyle(color: Color(0xFFB4C0D3), fontSize: 13))),
                        ],
                      ),
                      if (c.notice.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(c.notice, style: const TextStyle(color: Color(0xFFE5BC74), fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (Platform.isWindows) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section(Icons.headphones_rounded, 'Windows audio devices'),
                      const SizedBox(height: 8),
                      const Text('Choose the microphone and speaker used for calls.', style: TextStyle(color: Color(0xFF9AA8C0), fontSize: 12)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: c.selectedInputDevice,
                        decoration: const InputDecoration(labelText: 'Microphone'),
                        items: [for (final d in c.inputDevices) DropdownMenuItem(value: d.name, child: Text(d.description.isEmpty ? d.name : d.description, overflow: TextOverflow.ellipsis))],
                        onChanged: c.inputDevices.isEmpty ? null : c.selectInputDevice,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: c.selectedOutputDevice,
                        decoration: const InputDecoration(labelText: 'Speaker / headphones'),
                        items: [for (final d in c.outputDevices) DropdownMenuItem(value: d.name, child: Text(d.description.isEmpty ? d.name : d.description, overflow: TextOverflow.ellipsis))],
                        onChanged: c.outputDevices.isEmpty ? null : c.selectOutputDevice,
                      ),
                      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: c.refreshAudioDevices, icon: const Icon(Icons.refresh_rounded, size: 17), label: const Text('Refresh devices'))),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('About Shadow-SIP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    SizedBox(height: 9),
                    Text('Personal SIP softphone · Windows + Android', style: TextStyle(color: Color(0xFF9AA8C0))),
                    SizedBox(height: 10),
                    Text('Manual call recordings are saved in Shadow-SIP/Recordings under the app documents directory.', style: TextStyle(color: Color(0xFF8291AA), fontSize: 12, height: 1.5)),
                    SizedBox(height: 12),
                    Text('Shadow-SIP 0.1.0 · SIP engine powered by Medut-SDK', style: TextStyle(color: Color(0xFF7E8BA1), fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(IconData icon, String title) => Row(
        children: [
          Icon(icon, color: const Color(0xFFB5A9FF)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _infoBox(String message) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFF26314A).withValues(alpha: .5), borderRadius: BorderRadius.circular(13)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF9D91FF), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFFB4C0D3)))),
          ],
        ),
      );

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = SipProfile(
      uri: _uri.text.trim(),
      password: _password.text,
      transport: _transport,
      serverUrl: _serverUrl.text.trim(),
      authUser: _authUser.text.trim(),
      displayName: _displayName.text.trim(),
      conferenceUri: _conference.text.trim(),
      iceEnabled: _ice,
      stunServer: _stun.text.trim(),
      turnServer: _turn.text.trim(),
      turnUser: _turnUser.text.trim(),
      turnPassword: _turnPassword.text,
      mediaEncryption: _encryption,
    );
    await widget.controller.connect(profile);
  }

  Future<void> _forget() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget SIP account?'),
        content: const Text('This disconnects the account and removes its locally saved credentials from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Forget account')),
        ],
      ),
    );
    if (confirm == true) {
      await widget.controller.forgetProfile();
      for (final field in [_uri, _password, _serverUrl, _authUser, _displayName, _conference, _stun, _turn, _turnUser, _turnPassword]) {
        field.clear();
      }
      setState(() {
        _transport = Transport.udp;
        _encryption = MediaEncryption.none;
        _ice = false;
      });
    }
  }
}
