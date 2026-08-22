import 'package:flutter/material.dart';

/// Actions the welcome page can hand back to the app shell.
///
/// The welcome page never navigates on its own. It reports intent and lets the
/// caller decide which studio section to open, so the same page works from the
/// launcher, from a menu item, or from a test.
enum WelcomeAction {
  openProject,
  newProject,
  recentProjects,
  templates,
  worlds,
  settings,
  createCharacter,
  buildWorld,
  newManuscript,
  openTimeline,
  continueWriting,
}

/// Palette for the welcome page.
///
/// The page is deliberately dark in every theme: it is a title screen shown
/// before the studio chrome, so it keeps its own colours rather than inheriting
/// the light/dark preset the workspace uses.
class _WelcomePalette {
  static const background = Color(0xFF0B0908);
  static const sidebar = Color(0xFF100D0B);
  static const panel = Color(0xFF161210);
  static const border = Color(0xFF2A2320);
  static const gold = Color(0xFFC9A227);
  static const goldBright = Color(0xFFE6C97E);
  static const cream = Color(0xFFEDE4D3);
  static const muted = Color(0xFFA2937E);
}

class _WelcomeEntry {
  const _WelcomeEntry({
    required this.action,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final WelcomeAction action;
  final IconData icon;
  final String title;
  final String? subtitle;
}

/// The Author OS title screen.
///
/// Layout is a sidebar of entry points, a hero panel, and a quick-start bar.
/// Below [_narrowBreakpoint] the sidebar drops away and the hero stacks above
/// the entry points, so the page still works in a small window or a browser.
class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    required this.onAction,
    this.authorName,
    this.heroImage,
  });

  /// Called with the action the author picked.
  final ValueChanged<WelcomeAction> onAction;

  /// Shown in place of the default greeting when the profile has a name.
  final String? authorName;

  /// Optional artwork for the hero panel.
  ///
  /// When null the hero paints its own monogram treatment, so the page is
  /// complete without a bundled image.
  final ImageProvider? heroImage;

  static const _narrowBreakpoint = 900.0;

  static const _entries = <_WelcomeEntry>[
    _WelcomeEntry(
      action: WelcomeAction.openProject,
      icon: Icons.folder_open_outlined,
      title: 'Open Project',
      subtitle: 'Continue your story',
    ),
    _WelcomeEntry(
      action: WelcomeAction.newProject,
      icon: Icons.create_outlined,
      title: 'New Project',
      subtitle: 'Start a new story',
    ),
    _WelcomeEntry(
      action: WelcomeAction.recentProjects,
      icon: Icons.schedule_outlined,
      title: 'Recent Projects',
      subtitle: 'Pick up where you left off',
    ),
    _WelcomeEntry(
      action: WelcomeAction.templates,
      icon: Icons.auto_stories_outlined,
      title: 'Templates',
      subtitle: 'Start with a structure',
    ),
    _WelcomeEntry(
      action: WelcomeAction.worlds,
      icon: Icons.public_outlined,
      title: 'Worlds',
      subtitle: 'Explore your universes',
    ),
    _WelcomeEntry(
      action: WelcomeAction.settings,
      icon: Icons.settings_outlined,
      title: 'Settings',
      subtitle: 'Customize Author OS',
    ),
  ];

  static const _quickStart = <_WelcomeEntry>[
    _WelcomeEntry(
      action: WelcomeAction.newProject,
      icon: Icons.create_outlined,
      title: 'New Project',
    ),
    _WelcomeEntry(
      action: WelcomeAction.createCharacter,
      icon: Icons.person_outline,
      title: 'Create Character',
    ),
    _WelcomeEntry(
      action: WelcomeAction.buildWorld,
      icon: Icons.public_outlined,
      title: 'Build World',
    ),
    _WelcomeEntry(
      action: WelcomeAction.newManuscript,
      icon: Icons.description_outlined,
      title: 'New Manuscript',
    ),
    _WelcomeEntry(
      action: WelcomeAction.openTimeline,
      icon: Icons.hourglass_empty_outlined,
      title: 'Open Timeline',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('welcome-page'),
      backgroundColor: _WelcomePalette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _narrowBreakpoint) {
              return _buildNarrow();
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WelcomeSidebar(
                  authorName: authorName,
                  entries: _entries,
                  onAction: onAction,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _WelcomeHero(image: heroImage)),
                      _QuickStartBar(items: _quickStart, onAction: onAction),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNarrow() {
    return SingleChildScrollView(
      key: const Key('welcome-narrow'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 320, child: _WelcomeHero(image: heroImage)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeWordmark(authorName: authorName),
                const SizedBox(height: 20),
                for (final entry in _entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EntryTile(
                      entry: entry,
                      selected: entry.action == WelcomeAction.openProject,
                      onTap: () => onAction(entry.action),
                    ),
                  ),
              ],
            ),
          ),
          _QuickStartBar(items: _quickStart, onAction: onAction, wrap: true),
        ],
      ),
    );
  }
}

class _WelcomeWordmark extends StatelessWidget {
  const _WelcomeWordmark({this.authorName});

  final String? authorName;

  @override
  Widget build(BuildContext context) {
    final name = authorName?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? 'Welcome to' : 'Welcome back,',
          style: const TextStyle(
            color: _WelcomePalette.cream,
            fontSize: 15,
            height: 1.3,
          ),
        ),
        Text(
          name.isEmpty ? 'AuthorOS' : name,
          style: const TextStyle(
            fontFamily: 'Merriweather',
            color: _WelcomePalette.goldBright,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your complete book creation studio.',
          style: TextStyle(
            color: _WelcomePalette.muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _WelcomeSidebar extends StatelessWidget {
  const _WelcomeSidebar({
    required this.entries,
    required this.onAction,
    this.authorName,
  });

  final List<_WelcomeEntry> entries;
  final ValueChanged<WelcomeAction> onAction;
  final String? authorName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      padding: const EdgeInsets.fromLTRB(22, 28, 18, 22),
      decoration: const BoxDecoration(
        color: _WelcomePalette.sidebar,
        border: Border(right: BorderSide(color: _WelcomePalette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeWordmark(authorName: authorName),
          const SizedBox(height: 18),
          const _Ornament(),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _EntryTile(
                        entry: entry,
                        selected: entry.action == WelcomeAction.openProject,
                        onTap: () => onAction(entry.action),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '"Stories are the architecture\nof imagination."',
            style: TextStyle(
              color: _WelcomePalette.muted,
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '— Build yours beautifully.',
            style: TextStyle(
              color: _WelcomePalette.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin rule with a centred diamond, echoing the dividers in the hero art.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: _WelcomePalette.border, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Transform.rotate(
            angle: 0.7853981633974483,
            child: Container(
              width: 5,
              height: 5,
              color: _WelcomePalette.gold,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: _WelcomePalette.border, height: 1),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onTap,
    this.selected = false,
  });

  final _WelcomeEntry entry;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final subtitle = entry.subtitle;
    return Material(
      color: selected ? _WelcomePalette.panel : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('welcome-entry-${entry.action.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _WelcomePalette.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(entry.icon, size: 19, color: _WelcomePalette.goldBright),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        color: _WelcomePalette.cream,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _WelcomePalette.muted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The centre panel: artwork when supplied, otherwise a painted monogram.
///
/// The artwork already carries the monogram, wordmark, tagline and quote, so
/// nothing is drawn over it. The painted fallback below reproduces those same
/// elements for builds that ship without the image.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final artwork = image;
    if (artwork != null) {
      return DecoratedBox(
        key: const Key('welcome-hero-artwork'),
        decoration: BoxDecoration(
          color: _WelcomePalette.background,
          image: DecorationImage(image: artwork, fit: BoxFit.cover),
        ),
        child: const SizedBox.expand(),
      );
    }

    return const DecoratedBox(
      key: Key('welcome-hero-painted'),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.1,
          colors: [Color(0xFF1C1512), _WelcomePalette.background],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Monogram(),
                SizedBox(height: 22),
                Text(
                  'AuthorOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    color: _WelcomePalette.goldBright,
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'PLAN  •  BUILD  •  WRITE  •  EXPLORE  •  CREATE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _WelcomePalette.gold,
                    fontSize: 12,
                    letterSpacing: 3.2,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(width: 260, child: _Ornament()),
                SizedBox(height: 20),
                Text(
                  'Every great story starts\nwith a blank page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    color: _WelcomePalette.cream,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The circled "AO" mark used when no artwork is supplied.
class _Monogram extends StatelessWidget {
  const _Monogram();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _WelcomePalette.gold, width: 1.4),
        gradient: const RadialGradient(
          colors: [Color(0xFF241A14), Color(0xFF0F0C0A)],
        ),
      ),
      child: const Text(
        'AO',
        style: TextStyle(
          fontFamily: 'Merriweather',
          color: _WelcomePalette.goldBright,
          fontSize: 44,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _QuickStartBar extends StatelessWidget {
  const _QuickStartBar({
    required this.items,
    required this.onAction,
    this.wrap = false,
  });

  final List<_WelcomeEntry> items;
  final ValueChanged<WelcomeAction> onAction;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      for (final item in items)
        _QuickStartButton(entry: item, onTap: () => onAction(item.action)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: _WelcomePalette.sidebar,
        border: Border(top: BorderSide(color: _WelcomePalette.border)),
      ),
      child: wrap
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _QuickStartHeading(),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
                const SizedBox(height: 12),
                _ContinueWriting(
                  onTap: () => onAction(WelcomeAction.continueWriting),
                ),
              ],
            )
          : Row(
              children: [
                const _QuickStartHeading(),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final button in buttons)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: button,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _ContinueWriting(
                  onTap: () => onAction(WelcomeAction.continueWriting),
                ),
              ],
            ),
    );
  }
}

class _QuickStartHeading extends StatelessWidget {
  const _QuickStartHeading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Quick Start',
          style: TextStyle(
            fontFamily: 'Merriweather',
            color: _WelcomePalette.cream,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        Text(
          'Jump straight into creating.',
          style: TextStyle(
            color: _WelcomePalette.muted,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _QuickStartButton extends StatelessWidget {
  const _QuickStartButton({required this.entry, required this.onTap});

  final _WelcomeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _WelcomePalette.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('welcome-quick-${entry.action.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _WelcomePalette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(entry.icon, size: 17, color: _WelcomePalette.goldBright),
              const SizedBox(width: 9),
              Text(
                entry.title,
                style: const TextStyle(
                  color: _WelcomePalette.cream,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueWriting extends StatelessWidget {
  const _ContinueWriting({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _WelcomePalette.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('welcome-continue-writing'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _WelcomePalette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue Writing',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      color: _WelcomePalette.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    'Stay in your flow.',
                    style: TextStyle(
                      color: _WelcomePalette.muted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _WelcomePalette.gold,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: Color(0xFF120E0B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
