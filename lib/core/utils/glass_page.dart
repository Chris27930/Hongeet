import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class GlassPage extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GlassPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: themeProvider.useGlassTheme
          ? Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0A0A0A), Color(0xFF000000)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: padding,
                    child: child,
                  ),
                ),
              ],
            )
          : SafeArea(
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
    );
  }
}
