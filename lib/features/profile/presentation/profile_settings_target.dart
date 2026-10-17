import 'package:flutter/material.dart';

Widget buildProfileSettingsTarget(BuildContext context) {
  return const _SettingsTargetUnavailable();
}

class _SettingsTargetUnavailable extends StatelessWidget {
  const _SettingsTargetUnavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0F1724),
        title: const Text('Settings'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The existing Settings screen could not be discovered automatically.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
