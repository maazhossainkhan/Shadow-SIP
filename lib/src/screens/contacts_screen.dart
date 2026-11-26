import 'package:flutter/material.dart';

import '../models/phone_contact.dart';
import '../services/sip_controller.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key, required this.controller});
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
                      Text('Contacts', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                      SizedBox(height: 5),
                      Text('Your saved SIP contacts and extensions', style: TextStyle(color: Color(0xFF9AA8C0))),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _addContact(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add contact'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (controller.contacts.isEmpty)
              const _ContactsEmpty()
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < controller.contacts.length; i++) ...[
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF322E61),
                          child: Text(controller.contacts[i].name.isEmpty ? '?' : controller.contacts[i].name[0].toUpperCase()),
                        ),
                        title: Text(controller.contacts[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(controller.contacts[i].number),
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            IconButton(
                              tooltip: 'Call contact',
                              onPressed: controller.isConnected ? () => controller.dial(controller.contacts[i].number) : null,
                              icon: const Icon(Icons.call_rounded, color: Color(0xFF36D6A0)),
                            ),
                            IconButton(
                              tooltip: 'Remove contact',
                              onPressed: () => controller.removeContact(controller.contacts[i]),
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF8998B0)),
                            ),
                          ],
                        ),
                      ),
                      if (i != controller.contacts.length - 1)
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

  Future<void> _addContact(BuildContext context) async {
    final name = TextEditingController();
    final number = TextEditingController();
    final result = await showDialog<PhoneContact>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New contact'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: number, decoration: const InputDecoration(labelText: 'SIP extension or number')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || number.text.trim().isEmpty) return;
              Navigator.pop(context, PhoneContact(name: name.text.trim(), number: number.text.trim()));
            },
            child: const Text('Save contact'),
          ),
        ],
      ),
    );
    name.dispose();
    number.dispose();
    if (result != null) await controller.addContact(result);
  }
}

class _ContactsEmpty extends StatelessWidget {
  const _ContactsEmpty();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 46),
          child: Column(
            children: [
              Icon(Icons.people_alt_outlined, size: 46, color: Color(0xFF7F8CA4)),
              SizedBox(height: 13),
              Text('No contacts saved', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              SizedBox(height: 7),
              Text('Add an extension or SIP address to quickly call someone.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E9DB5), height: 1.5)),
            ],
          ),
        ),
      );
}
