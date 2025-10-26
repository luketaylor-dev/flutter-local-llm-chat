import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_interface/src/di/di.dart';
import 'package:llm_interface/src/features/home/presentation/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const ProviderScope(child: LlmApp()));
}

class LlmApp extends StatelessWidget {
  const LlmApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ColorScheme scheme = ColorScheme.dark(
      primary: Color(0xFFA855F7), // purple-500
      secondary: Color(0xFF7C3AED), // purple-700
      tertiary: Color(0xFF9333EA), // purple-600
      surface: Color(0xFF0A0A0A),
      background: Color(0xFF0A0A0A),
      surfaceVariant: Color(0xFF3B0764), // purple-950
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFFEEEFF0),
      onBackground: Color(0xFFEEEFF0),
    );
    final ThemeData theme = ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withOpacity(0.95),
        elevation: 0,
      ),
      useMaterial3: true,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LLM Chat',
      theme: theme,
      home: const HomePage(),
    );
  }
}
