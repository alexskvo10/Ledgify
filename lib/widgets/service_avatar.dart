import 'package:flutter/material.dart';

import '../models/subscription.dart';

/// Rounded square with the service's colour and emoji/letters.
/// Used at 16 (calendar), 40–44 (rows) and 64 (detail).
class ServiceAvatar extends StatelessWidget {
  const ServiceAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.dimmed = false,
  });

  ServiceAvatar.of(Subscription sub, {Key? key, double size = 40})
    : this(
        key: key,
        icon: sub.icon,
        color: sub.color,
        size: size,
        dimmed: !sub.status.isRecurring,
      );

  final String icon;
  final Color color;
  final double size;

  /// Canceled/archived services are shown desaturated.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final small = size < 24;
    final base = dimmed
        ? Color.lerp(color, const Color(0xFF8E8E93), 0.6)!
        : color;
    // Letters get white or black depending on how light the colour is.
    final onColor = base.computeLuminance() > 0.6
        ? Colors.black87
        : Colors.white;
    final isText = icon.runes.every((r) => r < 0x2000);

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, Color.lerp(base, Colors.black, 0.22)!],
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: small
              ? null
              : [
                  BoxShadow(
                    color: base.withValues(alpha: 0.28),
                    blurRadius: size * 0.25,
                    offset: Offset(0, size * 0.08),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: dimmed ? 0.7 : 1,
          child: Text(
            icon,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: size * (isText ? 0.42 : 0.5),
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: onColor,
            ),
          ),
        ),
      ),
    );
  }
}
