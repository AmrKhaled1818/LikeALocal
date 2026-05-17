import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../theme/app_colors.dart';

/// App-wide toast helper. Wraps `toastification` with:
///   • top-right alignment (slides in from the side, doesn't block the header)
///   • `flat` style so it adapts automatically to dark/light theme
///   • `kOrange` accent on success/info/notification to match the app theme
///   • distinct colors only for `error` (red) and `warning` (amber) so users
///     can still tell something went wrong at a glance.
class AppToast {
  static const _duration = Duration(seconds: 4);

  static void _show({
    required ToastificationType type,
    required Color primaryColor,
    required IconData icon,
    required String title,
    String? description,
  }) {
    toastification.show(
      type: type,
      style: ToastificationStyle.flat, // auto-adapts to dark/light theme
      alignment: Alignment.topRight,
      autoCloseDuration: _duration,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      description: description != null
          ? Text(description, style: const TextStyle(fontSize: 12))
          : null,
      primaryColor: primaryColor,
      icon: Icon(icon, color: primaryColor),
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      closeOnClick: true,
      dragToClose: true,
    );
  }

  static void success(String msg) => _show(
        type: ToastificationType.success,
        primaryColor: kOrange,
        icon: Icons.check_circle,
        title: msg,
      );

  static void error(String msg) => _show(
        type: ToastificationType.error,
        primaryColor: kDestructive,
        icon: Icons.error_outline,
        title: msg,
      );

  static void warning(String msg) => _show(
        type: ToastificationType.warning,
        primaryColor: kAmber,
        icon: Icons.warning_amber_rounded,
        title: msg,
      );

  static void info(String msg) => _show(
        type: ToastificationType.info,
        primaryColor: kOrange,
        icon: Icons.info_outline,
        title: msg,
      );

  /// Two-line notification — used by NotificationService for new-message /
  /// upvote / comment / nearby pushes when the app is in the foreground.
  static void notification(String title, String body) => _show(
        type: ToastificationType.info,
        primaryColor: kOrange,
        icon: Icons.notifications_active_outlined,
        title: title,
        description: body,
      );
}
