import 'package:flutter/material.dart';

ThemeData monsterTheme() => ThemeData(
  fontFamily: 'NotoSansSC',
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff78b84b),
    primary: const Color(0xff477c28),
  ),
  scaffoldBackgroundColor: const Color(0xfff0f7e6),
  textTheme: ThemeData.light().textTheme.apply(
    fontFamily: 'NotoSansSC',
    bodyColor: const Color(0xff293a22),
    displayColor: const Color(0xff293a22),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    ),
  ),
  cardTheme: const CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
    ),
  ),
);
