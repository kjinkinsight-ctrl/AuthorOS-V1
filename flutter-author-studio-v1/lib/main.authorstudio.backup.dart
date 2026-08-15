import 'package:flutter/material.dart';

void main() {
  runApp(const AuthorStudioApp());
}

class AuthorStudioApp extends StatelessWidget {
  const AuthorStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC59B6D),
      brightness: Brightness.dark,
      surface: const Color(0xFF161A22),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Author Studio V1',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF161A22),
          surfaceTintColor: colorScheme.surfaceTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const AuthorStudioShell(),
    );
  }
}

enum StudioSection {
  dashboard,
  search,
  statistics,
  backup,
  projects,
  ideas,
  manuscript,
  chapters,
  characters,
  world,
  plot,
  timeline,
  notes,
  settings,
}

extension StudioSectionData on StudioSection {
  String get label => switch (this) {
        StudioSection.dashboard => 'Dashboard',
        StudioSection.search => 'Search',
        StudioSection.statistics => 'Statistics',
        StudioSection.backup => 'Backup',
        StudioSection.projects => 'Projects',
        StudioSection.ideas => 'Ideas',
        StudioSection.manuscript => 'Manuscript',
        StudioSection.chapters => 'Chapters',
        StudioSection.characters => 'Characters',
        StudioSection.world => 'World',
        StudioSection.plot => 'Plot',
        StudioSection.timeline => 'Timeline',
        StudioSection.notes => 'Notes',
        StudioSection.settings => 'Settings',
      };

  IconData get icon => switch (this) {
        StudioSection.dashboard => Icons.space_dashboard_outlined,
        StudioSection.search => Icons.search_outlined,
        StudioSection.statistics => Icons.bar_chart_outlined,
        StudioSection.backup => Icons.backup_outlined,
        StudioSection.projects => Icons.folder_copy_outlined,
        StudioSection.ideas => Icons.lightbulb_outline,
        StudioSection.manuscript => Icons.menu_book_outlined,
        StudioSection.chapters => Icons.chrome_reader_mode_outlined,
        StudioSection.characters => Icons.groups_outlined,
        StudioSection.world => Icons.public_outlined,
        StudioSection.plot => Icons.route_outlined,
        StudioSection.timeline => Icons.timeline_outlined,
        StudioSection.notes => Icons.sticky_note_2_outlined,
        StudioSection.settings => Icons.settings_outlined,
      };
}

class AuthorStudioShell extends StatefulWidget {
  const AuthorStudioShell({super.key});

  @override
  State<AuthorStudioShell> createState() => _AuthorStudioShellState();
}

class _AuthorStudioShellState extends State<AuthorStudioShell> {
  int selectedIndex = 0;

  static const sections = <StudioSection>[
    StudioSection.dashboard,
    StudioSection.search,
    StudioSection.statistics,
    StudioSection.backup,
    StudioSection.projects,
    StudioSection.ideas,
    StudioSection.manuscript,
    StudioSection.chapters,
    StudioSection.characters,
    StudioSection.world,
    StudioSection.plot,
    StudioSection.timeline,
    StudioSection.notes,
    StudioSection.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final currentSection = sections[selectedIndex];

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (isWide)
                  _DesktopNavigation(
                    sections: sections,
                    selectedIndex: selectedIndex,
                    onSelected: (index) =>
                        setState(() => selectedIndex = index),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(section: currentSection),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _SectionView(
                            key: ValueKey(currentSection),
                            section: currentSection,
                          ),
                        ),
                      ),
                      if (!isWide)
                        _MobileNavigation(
                          sections: sections,
                          selectedIndex: selectedIndex,
                          onSelected: (index) =>
                              setState(() => selectedIndex = index),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.section});

  final StudioSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          const _AppMark(),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Author Studio V1',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'Local-first writing workspace rebuilt in Flutter and Dart',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
          const Spacer(),
          _TopBarPill(label: section.label),
        ],
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFC59B6D), Color(0xFF8D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'A',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _TopBarPill extends StatelessWidget {
  const _TopBarPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2230),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(label),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<StudioSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141822),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        backgroundColor: Colors.transparent,
        labelType: NavigationRailLabelType.all,
        minWidth: 86,
        leading: const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace',
                style: TextStyle(
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Author Studio',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        destinations: [
          for (final section in sections)
            NavigationRailDestination(
              icon: Icon(section.icon),
              selectedIcon: Icon(section.icon, color: const Color(0xFFC59B6D)),
              label: Text(section.label),
            ),
        ],
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<StudioSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 88,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141822),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: sections.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = sections[index];
          final isSelected = index == selectedIndex;

          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onSelected(index),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  section.icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF0F1115) : Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(section.label),
              ],
            ),
            backgroundColor: const Color(0xFF1A1F2B),
            selectedColor: const Color(0xFFC59B6D),
            labelStyle: TextStyle(
              color: isSelected ? const Color(0xFF0F1115) : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            side: const BorderSide(color: Colors.white10),
          );
        },
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({super.key, required this.section});

  final StudioSection section;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: PageStorageKey(section),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: switch (section) {
        StudioSection.dashboard => const _DashboardView(),
        StudioSection.search => const _PlaceholderView(
            title: 'Search',
            description:
                'Universal search, filters, and cross-project discovery.',
            icon: Icons.search_outlined,
          ),
        StudioSection.statistics => const _PlaceholderView(
            title: 'Statistics',
            description: 'Word counts, session tracking, and project progress.',
            icon: Icons.bar_chart_outlined,
          ),
        StudioSection.backup => const _PlaceholderView(
            title: 'Backup',
            description:
                'Export, import, and long-term project safety workflows.',
            icon: Icons.backup_outlined,
          ),
        StudioSection.projects => const _PlaceholderView(
            title: 'Projects',
            description:
                'Project hub and templates for novels, memoirs, and series.',
            icon: Icons.folder_copy_outlined,
          ),
        StudioSection.ideas => const _PlaceholderView(
            title: 'Ideas',
            description:
                'Quick capture for concepts, prompts, and story fragments.',
            icon: Icons.lightbulb_outline,
          ),
        StudioSection.manuscript => const _PlaceholderView(
            title: 'Manuscript',
            description: 'Distraction-free drafting and clean writing focus.',
            icon: Icons.menu_book_outlined,
          ),
        StudioSection.chapters => const _PlaceholderView(
            title: 'Chapters',
            description:
                'Chapter planning and ordering for structured drafting.',
            icon: Icons.chrome_reader_mode_outlined,
          ),
        StudioSection.characters => const _PlaceholderView(
            title: 'Characters',
            description:
                'Character profiles, notes, and relationship tracking.',
            icon: Icons.groups_outlined,
          ),
        StudioSection.world => const _PlaceholderView(
            title: 'World',
            description:
                'Worldbuilding entries and connected story reference data.',
            icon: Icons.public_outlined,
          ),
        StudioSection.plot => const _PlaceholderView(
            title: 'Plot',
            description: 'Beat sheets, arcs, and planning connections.',
            icon: Icons.route_outlined,
          ),
        StudioSection.timeline => const _PlaceholderView(
            title: 'Timeline',
            description: 'Story chronology and event ordering.',
            icon: Icons.timeline_outlined,
          ),
        StudioSection.notes => const _PlaceholderView(
            title: 'Notes',
            description: 'Research notes, references, and project breadcrumbs.',
            icon: Icons.sticky_note_2_outlined,
          ),
        StudioSection.settings => const _PlaceholderView(
            title: 'Settings',
            description: 'Theme, layout, storage, and app preferences.',
            icon: Icons.settings_outlined,
          ),
      },
    );
  }
}

class _FocusModeView extends StatefulWidget {
  const _FocusModeView();

  @override
  State<_FocusModeView> createState() => _FocusModeViewState();
}

class _FocusModeViewState extends State<_FocusModeView> {
  final TextEditingController controller = TextEditingController(
    text: 'The rain on the window had already become part of the draft.\n\n'
        'Write the scene that matters most and hide the rest of the interface.',
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  int get wordCount {
    final words = controller.text.trim().split(RegExp(r'\s+'));
    return controller.text.trim().isEmpty ? 0 : words.length;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final count = wordCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FocusHeader(wordCount: count),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF141822),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus Draft',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ActionChip(label: 'Typewriter view'),
                      _ActionChip(label: 'Scene lock'),
                      _ActionChip(label: 'Calm theme'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    maxLines: 16,
                    minLines: 16,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                        ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Start drafting here...',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FocusHeader extends StatelessWidget {
  const _FocusHeader({required this.wordCount});

  final int wordCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manuscript',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'A distraction-free writing surface rebuilt in Flutter and Dart.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
        _MetricChip(label: 'Words', value: wordCount.toString()),
        const SizedBox(width: 10),
        const _MetricChip(label: 'Goal', value: '1,500'),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF22283A), Color(0xFF131720)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Author Studio V1',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  'A Flutter and Dart rebuild of the current author workspace, preserving the project structure, drafting flow, and planning surfaces that already exist in the app.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionChip(label: 'Focus mode'),
                  _ActionChip(label: 'Scene board'),
                  _ActionChip(label: 'Templates'),
                  _ActionChip(label: 'Cross-linking'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100 ? 3 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.55,
              children: const [
                _InfoCard(
                  title: 'Preserved from the current app',
                  body:
                      'Project-based organization, manuscript planning, characters, notes, worldbuilding, timeline, backup, and local-first storage.',
                  icon: Icons.copy_outlined,
                ),
                _InfoCard(
                  title: 'Rebuilt first in Flutter',
                  body:
                      'App shell, navigation, responsive layout, and dashboard content. The deeper feature modules can follow after the shell is stable.',
                  icon: Icons.build_outlined,
                ),
                _InfoCard(
                  title: 'Next high-value additions',
                  body:
                      'Focus mode, visual scene board, project templates, and stronger cross-linking between story entities.',
                  icon: Icons.trending_up_outlined,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFF1D2331),
      side: const BorderSide(color: Colors.white12),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: const Color(0xFFC59B6D)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: const Color(0xFFC59B6D)),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 18),
                Text(
                  'This section is intentionally kept as a lightweight rebuild placeholder so the existing app structure can be copied over incrementally.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
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
