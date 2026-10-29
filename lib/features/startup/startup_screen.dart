import 'package:flutter/material.dart';
import '../../core/localization/strings.dart';

/// Shown on every cold launch, before first-hatch onboarding or the dashboard.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff0f7e6),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/videos/icon.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                semanticLabel: tr('main.001'),
              ),
              const SizedBox(height: 24),
              Text(
                tr('splash.slogan'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff46765b),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
