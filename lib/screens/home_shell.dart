import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/sub_actions.dart';
import '../widgets/ui.dart';
import 'calendar_screen.dart';
import 'list_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Window chrome: top bar, 3-tab segmented control, body, "Add" button,
/// and the desktop keyboard shortcuts.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _searchFocus = FocusNode(debugLabel: 'search');

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _setTab(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  void _openSearch() {
    setState(() => _tab = 1);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  void _add() {
    HapticFeedback.lightImpact();
    openSubForm(context);
  }

  void _openSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  /// Arrow keys flip months only on the calendar and only when no text
  /// field has focus (a focused field consumes arrows before we see them).
  void _month(bool forward) {
    if (_tab != 0) return;
    final subs = context.read<SubsProvider>();
    forward ? subs.nextMonth() : subs.prevMonth();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _add,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            _setTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            _setTab(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            _setTab(2),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _month(false),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _month(true),
      },
      child: Focus(
        autofocus: true,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: p.glow),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(onSearch: _openSearch, onSettings: _openSettings),
                  const SizedBox(height: Space.s),
                  _SegmentedTabs(
                    labels: [s.tabCalendar, s.tabList, s.tabStats],
                    icons: const [
                      Icons.calendar_month_rounded,
                      Icons.view_agenda_rounded,
                      Icons.donut_large_rounded,
                    ],
                    active: _tab,
                    onChanged: _setTab,
                  ),
                  const SizedBox(height: Space.s),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.slow,
                      switchInCurve: Motion.enter,
                      switchOutCurve: Motion.exit,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.02),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: switch (_tab) {
                        0 => const CalendarScreen(key: ValueKey('cal')),
                        1 => ListScreen(
                          key: const ValueKey('list'),
                          searchFocus: _searchFocus,
                        ),
                        _ => const StatsScreen(key: ValueKey('stats')),
                      },
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: _AddButton(label: s.add, onTap: _add),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSearch, required this.onSettings});
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.l, 0),
      child: Row(
        children: [
          const AppMark(size: 28),
          const SizedBox(width: Space.s + 2),
          Text(
            s.appName,
            style: TextStyles.title2.copyWith(color: p.textPrimary),
          ),
          const Spacer(),
          AppIconButton(
            icon: Icons.search_rounded,
            tooltip: '${s.search}  (Ctrl+F)',
            onPressed: onSearch,
          ),
          const SizedBox(width: Space.s),
          AppIconButton(
            icon: Icons.settings_outlined,
            tooltip: s.settings,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.icons,
    required this.active,
    required this.onChanged,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(Space.xs),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: p.isDark ? 0.7 : 0.9),
            borderRadius: BorderRadius.circular(Radii.m),
            border: Border.all(color: p.stroke),
          ),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == active,
                    button: true,
                    label: labels[i],
                    excludeSemantics: true,
                    child: Tooltip(
                      message: 'Ctrl+${i + 1}',
                      waitDuration: const Duration(seconds: 1),
                      child: Material(
                        color: i == active ? p.sunken : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.s),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => onChanged(i),
                          child: AnimatedContainer(
                            duration: Motion.base,
                            curve: Motion.enter,
                            height: 36,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.s,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icons[i],
                                  size: 17,
                                  color: i == active
                                      ? p.accentText
                                      : p.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyles.subhead.copyWith(
                                      color: i == active
                                          ? p.textPrimary
                                          : p.textSecondary,
                                      fontWeight: i == active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: 'Ctrl+N',
      waitDuration: const Duration(seconds: 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: [
            BoxShadow(
              color: p.accent.withValues(alpha: p.isDark ? 0.35 : 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: p.accentFill,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 22, 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: Space.s),
                  Text(
                    label,
                    style: TextStyles.callout.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
