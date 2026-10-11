import 'package:flutter/material.dart';

/// Keeps the whole app above the phone's navigation bar.
///
/// Android 15 draws apps edge to edge: without this, the bottom of lists,
/// buttons and sheets would sit under the navigation bar, where a tap goes
/// to the bar. The app gets the bar's height as padding at the bottom, and the
/// strip behind the bar takes [color] (the color of the tab bar). Inside, the
/// bottom padding is zero and the keyboard is measured from the app's bottom,
/// so screens and sheets keep working as if the bar were not there.
class SystemBarsFrame extends StatelessWidget {
  final Widget child;

  /// The color behind the navigation bar; the theme's surface when null.
  final Color? color;

  const SystemBarsFrame({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bar = media.viewPadding.bottom;
    if (bar <= 0) return child;

    final keyboard = media.viewInsets.bottom - bar;

    return ColoredBox(
      color: color ?? Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.only(bottom: bar),
        child: MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(bottom: 0),
            viewPadding: media.viewPadding.copyWith(bottom: 0),
            viewInsets: media.viewInsets.copyWith(bottom: keyboard > 0 ? keyboard : 0),
          ),
          child: child,
        ),
      ),
    );
  }
}
