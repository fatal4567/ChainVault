import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ChainVaultApp());
}

class ChainVaultApp extends StatelessWidget {
  const ChainVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService().isDarkMode,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'ChainVault',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const LoginScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}