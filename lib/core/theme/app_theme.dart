import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        primaryColor: kOrange,
        scaffoldBackgroundColor: kBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kOrange,
          primary: kOrange,
          surface: kBackground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kDark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kDark,
            side: const BorderSide(color: kMuted),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kOrange, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kDestructive),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: kMutedFg),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: kOrange,
          unselectedItemColor: kMutedFg,
          backgroundColor: kBackground,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: kMuted),
          ),
          color: kBackground,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: kMuted,
          selectedColor: kOrange,
          labelStyle: TextStyle(fontSize: 13),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        dividerTheme: const DividerThemeData(
          color: kMuted,
          thickness: 1,
          space: 1,
        ),
      );
}
