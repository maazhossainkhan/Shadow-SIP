import 'package:flutter/material.dart';

import 'screens/contacts_screen.dart';
import 'screens/dialer_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/sip_controller.dart';
import 'widgets/status_pill.dart';

class ShadowSipApp extends StatelessWidget {
  const ShadowSipApp({super.key, required this.controller});

  final SipController controller;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7565F6);
    return MaterialApp(
      title: 'Shadow-SIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF121827),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1020),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF151D2E),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B2538),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2A3650)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seed, width: 1.5),
          ),
        ),
      ),
      home: ShadowSipShell(controller: controller),
    );
  }
}

class ShadowSipShell extends StatefulWidget {
  const ShadowSipShell({super.key, required this.controller});

  final SipController controller;

  @override
  State<ShadowSipShell> createState() => _ShadowSipShellState();
}

class _ShadowSipShellState extends State<ShadowSipShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _Destination('Dialer', Icons.dialpad_rounded),
    _Destination('History', Icons.history_rounded),
    _Destination('Contacts', Icons.people_alt_outlined),
    _Destination('Settings', Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final pages = [
      DialerScreen(controller: widget.controller),
      HistoryScreen(controller: widget.controller),
      ContactsScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 22,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8C7BFF), Color(0xFF5746D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.graphic_eq_rounded, size: 21, color: Colors.white),
            ),
            const SizedBox(width: 11),
            const Text('Shadow-SIP', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2)),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: StatusPill(
                  state: widget.controller.registrationState,
                  label: widget.controller.registrationMessage,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) => setState(() => _selectedIndex = value),
              labelType: NavigationRailLabelType.all,
              backgroundColor: const Color(0xFF0F1625),
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.icon, color: const Color(0xFFB7AEFF)),
                    label: Text(destination.label),
                  ),
              ],
            ),
          if (wide)
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF202B40)),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) => setState(() => _selectedIndex = value),
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}
