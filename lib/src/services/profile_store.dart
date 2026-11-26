import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medut/medut.dart';

class SipProfile {
  const SipProfile({
    required this.uri,
    required this.password,
    required this.transport,
    required this.serverUrl,
    required this.authUser,
    required this.displayName,
    this.conferenceUri = '',
    this.iceEnabled = false,
    this.stunServer = '',
    this.turnServer = '',
    this.turnUser = '',
    this.turnPassword = '',
    this.mediaEncryption = MediaEncryption.none,
  });

  final String uri;
  final String password;
  final Transport transport;
  final String serverUrl;
  final String authUser;
  final String displayName;
  final String conferenceUri;
  final bool iceEnabled;
  final String stunServer;
  final String turnServer;
  final String turnUser;
  final String turnPassword;
  final MediaEncryption mediaEncryption;

  Map<String, Object?> toJson() => {
        'uri': uri,
        'transport': transport.name,
        'serverUrl': serverUrl,
        'authUser': authUser,
        'displayName': displayName,
        'conferenceUri': conferenceUri,
        'iceEnabled': iceEnabled,
        'stunServer': stunServer,
        'turnServer': turnServer,
        'turnUser': turnUser,
        'mediaEncryption': mediaEncryption.name,
      };

  factory SipProfile.fromJson(Map<String, dynamic> json, String password) {
    final transportName = json['transport'] as String? ?? 'udp';
    final transport = Transport.values.firstWhere(
      (item) => item.name == transportName,
      orElse: () => Transport.udp,
    );
    return SipProfile(
      uri: json['uri'] as String? ?? '',
      password: password,
      transport: transport,
      serverUrl: json['serverUrl'] as String? ?? '',
      authUser: json['authUser'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      conferenceUri: json['conferenceUri'] as String? ?? '',
      iceEnabled: json['iceEnabled'] as bool? ?? false,
      stunServer: json['stunServer'] as String? ?? '',
      turnServer: json['turnServer'] as String? ?? '',
      turnUser: json['turnUser'] as String? ?? '',
      turnPassword: '',
      mediaEncryption: MediaEncryption.values.firstWhere(
        (value) => value.name == (json['mediaEncryption'] as String? ?? 'none'),
        orElse: () => MediaEncryption.none,
      ),
    );
  }
}

class ProfileStore {
  static const _profileKey = 'shadow_sip.sip.profile';
  static const _passwordKey = 'shadow_sip.sip.password';
  static const _turnPasswordKey = 'shadow_sip.sip.turn_password';
  static const _secure = FlutterSecureStorage();

  Future<SipProfile?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final password = await _secure.read(key: _passwordKey) ?? '';
      final profile = SipProfile.fromJson(decoded, password);
      final turnPassword = await _secure.read(key: _turnPasswordKey) ?? '';
      return SipProfile(
        uri: profile.uri, password: profile.password, transport: profile.transport,
        serverUrl: profile.serverUrl, authUser: profile.authUser, displayName: profile.displayName,
        conferenceUri: profile.conferenceUri, iceEnabled: profile.iceEnabled,
        stunServer: profile.stunServer, turnServer: profile.turnServer, turnUser: profile.turnUser,
        turnPassword: turnPassword, mediaEncryption: profile.mediaEncryption,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SipProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    if (profile.password.isEmpty) {
      await _secure.delete(key: _passwordKey);
    } else {
      await _secure.write(key: _passwordKey, value: profile.password);
    }
    if (profile.turnPassword.isEmpty) {
      await _secure.delete(key: _turnPasswordKey);
    } else {
      await _secure.write(key: _turnPasswordKey, value: profile.turnPassword);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await _secure.delete(key: _passwordKey);
    await _secure.delete(key: _turnPasswordKey);
  }
}
