import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:flutter/material.dart';

/// One sheet that its shortcut toggles: open it, or close it if it's open,
/// never stacking a second copy.
class SheetToggle {
  SheetToggle(this.builder);

  final WidgetBuilder builder;
  DialogRoute<void>? _route;

  bool get isOpen => _route?.isActive ?? false;

  void toggle(BuildContext context) => isOpen ? close(context) : show(context);

  void show(BuildContext context) {
    if (isOpen) return;
    final route = DialogRoute<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: builder,
    );
    _route = route;
    Navigator.of(context, rootNavigator: true).push(route);
  }

  void close(BuildContext context) {
    final route = _route;
    if (route != null && route.isActive) {
      Navigator.of(context, rootNavigator: true).removeRoute(route);
    }
  }
}

/// The glass panel inside a sheet. Clicking outside it closes the sheet,
/// and it has its own messenger so Undo toasts show above the backdrop.
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    required this.width,
    required this.height,
    required this.child,
    super.key,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        // Mouse convenience only: VoiceOver uses the Close button and Esc,
        // so these taps stay out of the accessibility tree.
        body: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: GestureDetector(
              excludeFromSemantics: true,
              onTap: () {}, // clicks inside the panel stay inside
              child: SizedBox(
                width: width,
                height: height,
                child: GlassPanel(
                  radius: 24,
                  opacity: 0.9,
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
