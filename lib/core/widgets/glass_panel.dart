import 'dart:ui';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Frosted panel that sits over the scenery.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.radius = Tokens.r22,
    this.opacity = Tokens.glassOpacity,
    this.padding = const EdgeInsets.all(Tokens.s16),
  });

  final Widget child;
  final double radius;
  final double opacity;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: Tokens.glassBlur,
          sigmaY: Tokens.glassBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Tokens.glass.withValues(alpha: opacity),
            borderRadius: shape,
            border: Border.all(color: Tokens.glassBorder),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
