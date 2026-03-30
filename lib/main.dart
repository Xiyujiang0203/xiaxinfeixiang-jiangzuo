import 'package:flutter/material.dart';
import 'package:xiaxinfeixiang/notifications/notifier.dart';
import 'package:xiaxinfeixiang/pages/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Notifier.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2));
    return MaterialApp(
      title: '厦信飞翔讲座',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      home: const HomeShell(),
    );
  }
}
