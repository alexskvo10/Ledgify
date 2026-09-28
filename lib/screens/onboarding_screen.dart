import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/demo_data.dart';
import '../l10n/strings.dart';
import '../state/settings_provider.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Three swipeable slides on first launch. The last one asks whether to start
/// empty or with demo data (demo data is never added silently).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _icons = [
    Icons.layers_rounded,
    Icons.calendar_month_rounded,
    Icons.donut_large_rounded,
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) =>
      _pages.animateToPage(i, duration: Motion.slow, curve: Motion.enter);

  Future<void> _finish({required bool demo}) async {
    HapticFeedback.mediumImpact();
    final subs = context.read<SubsProvider>();
    final settings = context.read<SettingsProvider>();
    if (demo) await subs.upsertAll(buildDemoData(subs.today));
    await settings.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final settings = context.watch<SettingsProvider>();
    final slides = s.slides;
    final last = _page == slides.length - 1;
    final colors = [p.accent, p.info, p.warning];

    return DecoratedBox(
      decoration: BoxDecoration(gradient: p.glow),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.l,
                      Space.m,
                      Space.l,
                      0,
                    ),
                    child: Row(
                      children: [
                        for (final code in ['ru', 'en']) ...[
                          AppChip(
                            label: code.toUpperCase(),
                            selected: settings.locale.languageCode == code,
                            onTap: () => settings.setLocale(Locale(code)),
                          ),
                          const SizedBox(width: Space.s),
                        ],
                        const Spacer(),
                        if (!last)
                          TextButton(
                            onPressed: () => _go(slides.length - 1),
                            style: TextButton.styleFrom(
                              foregroundColor: p.textSecondary,
                            ),
                            child: Text(s.skip),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: slides.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.xxxl,
                          vertical: Space.xxl,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: Space.xxl),
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                color: p.tint(colors[i], 1.1),
                                borderRadius: BorderRadius.circular(34),
                                border: Border.all(
                                  color: colors[i].withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(
                                _icons[i],
                                size: 52,
                                color: colors[i],
                              ),
                            ),
                            const SizedBox(height: 40),
                            Text(
                              slides[i].$1,
                              textAlign: TextAlign.center,
                              style: TextStyles.title1.copyWith(
                                fontSize: 28,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: Space.l),
                            Text(
                              slides[i].$2,
                              textAlign: TextAlign.center,
                              style: TextStyles.body.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        GestureDetector(
                          onTap: () => _go(i),
                          child: AnimatedContainer(
                            duration: Motion.base,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page ? colors[i] : p.strokeStrong,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xxl),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xxl,
                      0,
                      Space.xxl,
                      Space.xxl,
                    ),
                    child: AnimatedSwitcher(
                      duration: Motion.base,
                      child: last
                          ? Column(
                              key: const ValueKey('final'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppButton(
                                  label: s.startFresh,
                                  expand: true,
                                  onPressed: () => _finish(demo: false),
                                ),
                                const SizedBox(height: Space.s),
                                AppButton(
                                  label: s.tryDemo,
                                  kind: ButtonKind.secondary,
                                  expand: true,
                                  onPressed: () => _finish(demo: true),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('nav'),
                              children: [
                                TextButton(
                                  onPressed: _page == 0
                                      ? null
                                      : () => _go(_page - 1),
                                  style: TextButton.styleFrom(
                                    foregroundColor: p.textSecondary,
                                  ),
                                  child: Text(s.back),
                                ),
                                const Spacer(),
                                AppButton(
                                  label: s.next,
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: () => _go(_page + 1),
                                ),
                              ],
                            ),
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
