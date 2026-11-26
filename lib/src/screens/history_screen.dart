import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/call_log.dart';
import '../services/sip_controller.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});
  final SipController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 950),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Call history', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                      SizedBox(height: 5),
                      Text('Your recent incoming and outgoing calls', style: TextStyle(color: Color(0xFF9AA8C0))),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: controller.history.isEmpty ? null : () => _confirmClear(context),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (controller.history.isEmpty)
              const _EmptyState(
                icon: Icons.history_rounded,
                title: 'No calls yet',
                detail: 'Completed calls will appear here after you connect a SIP account.',
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < controller.history.length; i++) ...[
                      _HistoryTile(item: controller.history[i]),
                      if (i != controller.history.length - 1)
                        const Divider(height: 1, indent: 72, color: Color(0xFF29364D)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear call history?'),
        content: const Text('This removes the locally saved call history from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear history')),
        ],
      ),
    );
    if (yes == true) await controller.clearHistory();
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final CallLogItem item;

  @override
  Widget build(BuildContext context) {
    final outgoing = item.outgoing;
    final date = item.startedAt;
    final duration = item.durationSeconds;
    final time = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final mm = (duration ~/ 60).toString();
    final ss = (duration % 60).toString().padLeft(2, '0');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: outgoing ? const Color(0xFF273A4C) : const Color(0xFF2E2A55),
        child: Icon(outgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
            color: outgoing ? const Color(0xFF7EC5FF) : const Color(0xFFB3A8FF), size: 19),
      ),
      title: Text(item.peer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('$time  ·  ${item.result}', style: const TextStyle(color: Color(0xFF8E9DB5), fontSize: 12)),
      trailing: Text('$mm:$ss', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()], color: Color(0xFFBBC7D9))),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 46),
          child: Column(
            children: [
              Icon(icon, size: 46, color: const Color(0xFF7F8CA4)),
              const SizedBox(height: 13),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8E9DB5), height: 1.5)),
            ],
          ),
        ),
      );
}
