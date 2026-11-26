import 'package:flutter/material.dart';
import 'package:medut/medut.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.state, required this.label});

  final RegState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final connected = state == RegState.registered;
    final waiting = state == RegState.registering || state == RegState.reconnecting;
    final color = connected
        ? const Color(0xFF36D6A0)
        : waiting
            ? const Color(0xFFF4BB55)
            : const Color(0xFFFF6E7A);
    final title = connected
        ? 'Online'
        : waiting
            ? 'Connecting'
            : state == RegState.failed
                ? 'Connection failed'
                : 'Offline';

    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: .32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
