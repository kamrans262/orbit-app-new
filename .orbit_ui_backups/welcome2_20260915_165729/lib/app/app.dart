import 'package:flutter/material.dart';

import '../features/welcome/presentation/screens/welcome_screen.dart';
import 'theme/app_theme.dart';

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
    );
  }
}
