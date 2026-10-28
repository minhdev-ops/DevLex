import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/home/home_shell.dart';

void main() {
  runApp(const ItGlossaryApp());
}

class ItGlossaryApp extends StatelessWidget {
  const ItGlossaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IT Glossary & Roadmap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}
