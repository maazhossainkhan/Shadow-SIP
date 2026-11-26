import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/call_log.dart';
import '../models/phone_contact.dart';

class LocalDataStore {
  static const _historyKey = 'shadow_sip.call.history';
  static const _contactsKey = 'shadow_sip.contacts';

  Future<List<CallLogItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CallLogItem.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addHistory(CallLogItem item) async {
    final items = await loadHistory();
    items.insert(0, item);
    if (items.length > 250) items.removeRange(250, items.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<List<PhoneContact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PhoneContact.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveContacts(List<PhoneContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contactsKey,
      jsonEncode(contacts.map((e) => e.toJson()).toList()),
    );
  }
}
