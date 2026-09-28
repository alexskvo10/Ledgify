import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';

/// Centered icon + title + text + optional actions for empty screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: p.tint(p.accent),
                  borderRadius: BorderRadius.circular(Radii.xl),
                ),
                child: Icon(icon, size: 36, color: p.accentText),
              ),
              const SizedBox(height: Space.xxl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyles.title2,
              ),
              const SizedBox(height: Space.s),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyles.body.copyWith(color: p.textSecondary),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.xxl),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
