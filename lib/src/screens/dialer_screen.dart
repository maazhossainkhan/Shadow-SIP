import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:medut/medut.dart';

import '../services/sip_controller.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key, required this.controller});
  final SipController controller;
  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  final _number = TextEditingController();
  @override
  void dispose() { _number.dispose(); super.dispose(); }

  void _append(String digit) => setState(() => _number.text += digit);
  void _erase() {
    if (_number.text.isNotEmpty) {
      setState(() => _number.text = _number.text.substring(0, _number.text.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
          children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dialer', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('Simple SIP calling', style: TextStyle(color: Color(0xFF9AA8C0))),
              ])),
              if (!c.isConnected)
                FilledButton.tonalIcon(
                  onPressed: () => showDialog<void>(context: context, builder: (context) => AlertDialog(
                    title: const Text('Set up your SIP account'),
                    content: const Text('Open Settings, enter your SIP address and password, then connect.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                  )),
                  icon: const Icon(Icons.settings_phone_rounded),
                  label: const Text('Set up'),
                ),
            ]),
            const SizedBox(height: 22),
            if (c.hasCall)
              _ActiveCall(controller: c)
            else if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: _buildPad(c)),
                const SizedBox(width: 18),
                Expanded(flex: 5, child: _QuickPanel(controller: c)),
              ])
            else
              Column(children: [
                _buildPad(c),
                const SizedBox(height: 18),
                _QuickPanel(controller: c),
              ]),
            if (c.notice.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Notice(message: c.notice),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPad(SipController c) {
    const digits = ['1','2','3','4','5','6','7','8','9','*','0','#'];
    const letters = ['', 'ABC','DEF','GHI','JKL','MNO','PQRS','TUV','WXYZ','','+',''];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(
            controller: _number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 1),
            decoration: const InputDecoration(
              hintText: 'Number or SIP extension',
              filled: false,
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0x33FFFFFF))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B7CFF), width: 2)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: digits.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: 1.7,
            ),
            itemBuilder: (context, i) => InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _append(digits[i]),
              child: Ink(
                decoration: BoxDecoration(color: const Color(0xFF202B41), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A3854))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(digits[i], style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
                  if (letters[i].isNotEmpty) Text(letters[i], style: const TextStyle(fontSize: 9, letterSpacing: 1.6, color: Color(0xFF93A2BD))),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(width: 52, child: IconButton(tooltip: 'Delete last digit', onPressed: _erase, icon: const Icon(Icons.backspace_outlined))),
            Expanded(child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: c.isConnected && _number.text.trim().isNotEmpty ? () => c.dial(_number.text.trim()) : null,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FBF88), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                child: const Icon(Icons.call_rounded, size: 25),
              ),
            )),
            const SizedBox(width: 52),
          ]),
        ]),
      ),
    );
  }
}

class _QuickPanel extends StatelessWidget {
  const _QuickPanel({required this.controller});
  final SipController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            Icon(c.isConnected ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: c.isConnected ? const Color(0xFF36D6A0) : const Color(0xFFF4BB55)),
            const SizedBox(width: 9),
            Expanded(child: Text(c.isConnected ? 'SIP account is ready' : c.registrationMessage, style: const TextStyle(color: Color(0xFFB6C2D6)))),
          ]),
          const SizedBox(height: 17),
          const Divider(color: Color(0xFF29364D)),
          const SizedBox(height: 10),
          const Text('Quick dial', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (c.contacts.isEmpty)
            const Text('Saved contacts will appear here.', style: TextStyle(color: Color(0xFF8E9DB5)))
          else
            ...c.contacts.take(4).map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: const Color(0xFF322E61), child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase())),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(p.number),
              trailing: IconButton(onPressed: c.isConnected ? () => c.dial(p.number) : null, icon: const Icon(Icons.call_rounded, color: Color(0xFF36D6A0))),
            )),
          if (c.savedProfile?.conferenceUri.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: c.isConnected ? c.dialConference : null,
              icon: const Icon(Icons.groups_2_rounded),
              label: const Text('Join conference room'),
            )),
          ],
          const SizedBox(height: 8),
          const Text('Dial an extension, SIP URI, or a number routed by your PBX.', style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF8291AA))),
        ]),
      ),
    );
  }
}

class _ActiveCall extends StatelessWidget {
  const _ActiveCall({required this.controller});
  final SipController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ringing = c.callState == CallState.ringing;
    final connected = c.callState == CallState.established || c.callState == CallState.held;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(width: 76, height: 76, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF8D7EFF), Color(0xFF4C3DBB)])), child: const Icon(Icons.person_rounded, size: 39, color: Colors.white)),
          const SizedBox(height: 14),
          Text(c.activePeer, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(ringing ? (c.isOutgoing ? 'Ringing…' : 'Incoming call') : connected ? (c.isHeld ? 'On hold' : 'Connected') : c.callState?.name ?? 'Call', style: const TextStyle(color: Color(0xFF9DAAC0))),
          if (connected) ...[
            const SizedBox(height: 8),
            Text(_duration(c.callDuration), style: const TextStyle(fontSize: 20, fontFeatures: [FontFeature.tabularFigures()])),
          ],
          const SizedBox(height: 22),
          if (ringing && !c.isOutgoing)
            Wrap(alignment: WrapAlignment.center, spacing: 30, children: [
              _Action(icon: Icons.call_end_rounded, label: 'Decline', color: const Color(0xFFE65067), onTap: c.decline),
              _Action(icon: Icons.call_rounded, label: 'Answer', color: const Color(0xFF1FBF88), onTap: c.answer),
            ])
          else if (!connected)
            Column(children: [const Text('Calling…', style: TextStyle(color: Color(0xFF9DAAC0))), const SizedBox(height: 18), _Hangup(onTap: c.hangup)])
          else ...[
            Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 14, children: [
              _Action(icon: c.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, label: c.isMuted ? 'Unmute' : 'Mute', color: c.isMuted ? const Color(0xFF6657D9) : const Color(0xFF29364D), onTap: c.toggleMute),
              _Action(icon: c.isHeld ? Icons.play_arrow_rounded : Icons.pause_rounded, label: c.isHeld ? 'Resume' : 'Hold', color: c.isHeld ? const Color(0xFF6657D9) : const Color(0xFF29364D), onTap: c.toggleHold),
              if (Platform.isAndroid) _Action(icon: Icons.volume_up_rounded, label: c.isSpeaker ? 'Speaker on' : 'Speaker', color: c.isSpeaker ? const Color(0xFF6657D9) : const Color(0xFF29364D), onTap: c.toggleSpeaker),
              _Action(icon: c.isRecording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded, label: c.isRecording ? 'Stop rec' : 'Record', color: c.isRecording ? const Color(0xFFE65067) : const Color(0xFF29364D), onTap: c.toggleRecording),
              _Action(icon: Icons.dialpad_rounded, label: 'DTMF', color: const Color(0xFF29364D), onTap: () => _showDtmf(context, c)),
              _Action(icon: Icons.phone_forwarded_rounded, label: 'Transfer', color: const Color(0xFF29364D), onTap: () => _showTransfer(context, c)),
            ]),
            const SizedBox(height: 24),
            _Hangup(onTap: c.hangup),
          ],
          if (c.latestStats != null && connected) ...[
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF29364D)),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 22, runSpacing: 10, children: [
              _Metric('MOS', c.latestStats!.mosLq.toStringAsFixed(2)),
              _Metric('RTT', '${c.latestStats!.rttMs.toStringAsFixed(0)} ms'),
              _Metric('Loss', '${c.latestStats!.lossPct.toStringAsFixed(1)}%'),
              _Metric('Jitter', '${c.latestStats!.jitterMs.toStringAsFixed(0)} ms'),
              _Metric('Codec', c.latestStats!.codec),
            ]),
          ],
        ]),
      ),
    );
  }

  static String _duration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }

  static Future<void> _showDtmf(BuildContext context, SipController c) async {
    const digits = ['1','2','3','4','5','6','7','8','9','*','0','#'];
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('DTMF keypad'),
      content: SizedBox(width: 250, child: GridView.count(shrinkWrap: true, crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [for (final d in digits) FilledButton.tonal(onPressed: () => c.sendDtmf(d), child: Text(d, style: const TextStyle(fontSize: 21)))])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }

  static Future<void> _showTransfer(BuildContext context, SipController c) async {
    final field = TextEditingController();
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Blind transfer'),
      content: TextField(controller: field, autofocus: true, decoration: const InputDecoration(labelText: 'Transfer destination', hintText: '201 or user@pbx.example.com')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () { c.blindTransfer(field.text); Navigator.pop(context); }, child: const Text('Transfer')),
      ],
    ));
    field.dispose();
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onTap;
  @override
  Widget build(BuildContext context) => SizedBox(width: 84, child: Column(children: [
    Material(color: color, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 56, height: 56, child: Icon(icon, color: Colors.white, size: 22)))),
    const SizedBox(height: 7),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFFB7C2D5))),
  ]));
}

class _Hangup extends StatelessWidget {
  const _Hangup({required this.onTap});
  final Future<void> Function() onTap;
  @override
  Widget build(BuildContext context) => SizedBox(width: 180, height: 52, child: FilledButton.icon(
    onPressed: onTap,
    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65067), foregroundColor: Colors.white),
    icon: const Icon(Icons.call_end_rounded), label: const Text('End call'),
  ));
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B9BB4))),
  ]);
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF8D6A2A).withValues(alpha: .15), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFB8893D).withValues(alpha: .3))),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, color: Color(0xFFF0C16C)),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFE4D2AC), fontSize: 13))),
    ]),
  );
}
