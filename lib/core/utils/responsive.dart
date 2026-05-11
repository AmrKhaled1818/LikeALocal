import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;
  static const double maxFeedWidth = 760;
  static const double maxFormWidth = 560;
  static const double maxDetailWidth = 860;
}

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= AppBreakpoints.tablet && w < AppBreakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
}

/// Centers and constrains [child] on screens wider than [AppBreakpoints.tablet].
/// On mobile it is a transparent pass-through.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxFeedWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.tablet) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
