import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'author_profile_store.dart';
import 'backup_health.dart';
import 'character_studio.dart';
import 'continuity.dart';
import 'continuity_actions.dart';
import 'core/search_models.dart' show SearchDestination;
import 'create_profile_page.dart';
import 'impact_trace.dart';
import 'login_select_user_page.dart';
import 'manuscript_studio.dart';
import 'manuscript_store.dart';
import 'onboarding.dart';
import 'plot_service.dart';
import 'persistence/authoros_database.dart';
import 'release_destinations.dart';
import 'supabase_service.dart';
import 'timeline.dart';
import 'timeline_studio_view.dart';
import 'plot_studio_view.dart';
import 'welcome_page.dart';
import 'world_board/world_board_models.dart';
import 'world_board/world_board_view.dart';
import 'world_workspace.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/resolved_theme.dart';
import 'theme/theme_definition.dart';
import 'theme/theme_engine.dart';
import 'theme/theme_persistence.dart';
import 'theme/theme_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSupabase.initialize();
  runApp(const AuthorStudioApp());
}

class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.accentColor,
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color accentColor;

  static const List<AppThemePreset> values = [
    AppThemePreset(
      id: 'light',
      name: 'Light',
      description: 'Light blue, white, and cool gray for daytime writing.',
      brightness: Brightness.light,
      backgroundColor: Color(0xFFF2F7FC),
      surfaceColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF4F8FCB),
    ),
    AppThemePreset(
      id: 'dark',
      name: 'Dark',
      description: 'Black, gold, and white for focused evening writing.',
      brightness: Brightness.dark,
      backgroundColor: Color(0xFF080808),
      surfaceColor: Color(0xFF141414),
      accentColor: Color(0xFFD4AF37),
    ),
  ];

  static String normalizeId(String? id) => switch (id) {
        'dark' ||
        'obsidian' ||
        'midnight' ||
        'forest' ||
        'burgundy' ||
        'plum' ||
        'ocean' =>
          'dark',
        _ => 'light',
      };

  static AppThemePreset byId(String? id) {
    final normalizedId = normalizeId(id);
    return values.firstWhere((theme) => theme.id == normalizedId);
  }
}

class AppThemeAccent {
  const AppThemeAccent({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;

  static const List<AppThemeAccent> values = [
    AppThemeAccent(
        id: 'default', label: 'Theme Default', color: Color(0x00000000)),
    AppThemeAccent(id: 'amber', label: 'Amber', color: Color(0xFFB78551)),
    AppThemeAccent(id: 'teal', label: 'Teal', color: Color(0xFF5AC4BA)),
    AppThemeAccent(id: 'crimson', label: 'Crimson', color: Color(0xFFCA6C7A)),
    AppThemeAccent(id: 'cobalt', label: 'Cobalt', color: Color(0xFF5A7CC7)),
    AppThemeAccent(id: 'olive', label: 'Olive', color: Color(0xFF7C9B5A)),
    AppThemeAccent(id: 'coral', label: 'Coral', color: Color(0xFFE28B6F)),
    AppThemeAccent(id: 'slate', label: 'Slate', color: Color(0xFF798DA7)),
  ];

  static AppThemeAccent byId(String? id) =>
      values.firstWhere((accent) => accent.id == (id ?? 'default'),
          orElse: () => values.first);
}

class AppThemeSelection {
  const AppThemeSelection({
    required this.themeId,
    required this.accentId,
  });

  final String themeId;
  final String accentId;

  Color get resolvedAccentColor {
    return AppThemePreset.byId(themeId).accentColor;
  }
}

class AuthorProfileSummary {
  const AuthorProfileSummary({
    required this.name,
    required this.focus,
    required this.bio,
    required this.avatarPath,
    required this.publicProfile,
  });

  final String name;
  final String focus;
  final String bio;
  final String avatarPath;
  final bool publicProfile;

  static const defaultName = 'Ari Rowan';
  static const defaultFocus = 'Fantasy romance and literary thrillers';
  static const defaultBio =
      'I write character-led stories with strong atmosphere, sharp stakes, and hopeful endings.';

  static Future<AuthorProfileSummary> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthorProfileSummary(
      name: prefs.getString('author_studio.profile.name') ?? defaultName,
      focus: prefs.getString('author_studio.profile.focus') ?? defaultFocus,
      bio: prefs.getString('author_studio.profile.bio') ?? defaultBio,
      avatarPath: prefs.getString('author_studio.profile.avatar_path') ?? '',
      publicProfile: prefs.getBool('author_studio.profile.public') ?? true,
    );
  }

  String get initials => name.trim().isEmpty
      ? 'A'
      : name.trim().split(RegExp(r'\s+')).first[0].toUpperCase();
}

class AuthorStudioApp extends StatefulWidget {
  const AuthorStudioApp({
    super.key,
    this.store = const OnboardingStore(),
    this.manuscriptStore = const ManuscriptStore(),
    this.showWelcome = true,
  });

  final OnboardingStore store;
  final ManuscriptStore manuscriptStore;

  /// Whether the Author OS welcome page is shown before the studio shell.
  ///
  /// Tests that drive the studio directly pass false so they land on the
  /// shell without stepping through the launcher.
  final bool showWelcome;

  @override
  State<AuthorStudioApp> createState() => _AuthorStudioAppState();
}

class _AuthorStudioAppState extends State<AuthorStudioApp>
    with WidgetsBindingObserver {
  bool _loadingTheme = true;
  ThemeEngine? _themeEngine;
  ThemeSelection? _themeSelection;
  ResolvedTheme? _resolvedTheme;

  ThemeBrightness get _hostBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? ThemeBrightness.dark
          : ThemeBrightness.light;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemeSelection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_loadingTheme || _themeEngine == null || _themeSelection == null) {
      return;
    }
    if (_themeSelection!.mode != AuthorOsThemeMode.system) {
      return;
    }
    _resolveCurrentTheme();
  }

  Future<void> _loadThemeSelection() async {
    final engine = ThemeEngine.standard(
      store: await SharedPreferencesThemeStore.load(),
    );
    final selection = await engine.load();
    final resolved = await engine.resolve(hostBrightness: _hostBrightness);
    if (!mounted) {
      return;
    }
    setState(() {
      _themeEngine = engine;
      _themeSelection = selection;
      _resolvedTheme = resolved;
      _loadingTheme = false;
    });
  }

  Future<void> _resolveCurrentTheme() async {
    final engine = _themeEngine;
    if (engine == null) {
      return;
    }
    final resolved = await engine.resolve(hostBrightness: _hostBrightness);
    if (!mounted) {
      return;
    }
    setState(() {
      _resolvedTheme = resolved;
      _themeSelection = engine.selection ?? _themeSelection;
    });
  }

  Future<void> _applySelection(ThemeSelection selection) async {
    final engine = _themeEngine;
    if (engine == null) {
      return;
    }
    final resolved = await engine.select(
      selection: selection,
      hostBrightness: _hostBrightness,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _themeSelection = engine.selection ?? selection;
      _resolvedTheme = resolved;
    });
  }

  Future<void> _handleLegacyThemeChanged(
    String themeId,
    String accentId,
  ) async {
    final selection = ThemeSelection(
      themeId: AppThemePreset.byId(themeId).id,
      mode: AppThemePreset.byId(themeId).brightness == Brightness.dark
          ? AuthorOsThemeMode.dark
          : AuthorOsThemeMode.light,
      accentId: accentId,
    );
    await _applySelection(selection);
  }

  ThemeData _buildThemeData() {
    final resolved = _resolvedTheme;
    if (resolved == null) {
      return ThemeData(useMaterial3: true);
    }
    return AuthorOsTheme.toThemeData(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _buildThemeData();

    if (_loadingTheme || _resolvedTheme == null || _themeSelection == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Indie Author OS',
        theme: themeData,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Indie Author OS',
      theme: themeData,
      home: StudioThemeScope(
        theme: _resolvedTheme!,
        studio: StudioId.shell,
        child: _OnboardingBootstrap(
          store: widget.store,
          manuscriptStore: widget.manuscriptStore,
          themeSelection: _themeSelection!,
          onThemeSelectionChanged: (selection) {
            unawaited(_applySelection(selection));
          },
          themeId: _themeSelection!.themeId,
          accentId: _themeSelection!.accentId,
          onThemeChanged: (themeId, accentId) {
            unawaited(_handleLegacyThemeChanged(themeId, accentId));
          },
          showWelcome: widget.showWelcome,
        ),
      ),
    );
  }
}

class _OnboardingBootstrap extends StatefulWidget {
  const _OnboardingBootstrap({
    required this.store,
    required this.manuscriptStore,
    required this.themeSelection,
    required this.onThemeSelectionChanged,
    required this.themeId,
    required this.accentId,
    required this.onThemeChanged,
    this.showWelcome = true,
  });

  final OnboardingStore store;
  final ManuscriptStore manuscriptStore;
  final ThemeSelection themeSelection;
  final ValueChanged<ThemeSelection> onThemeSelectionChanged;
  final String themeId;
  final String accentId;
  final void Function(String themeId, String accentId) onThemeChanged;
  final bool showWelcome;

  @override
  State<_OnboardingBootstrap> createState() => _OnboardingBootstrapState();
}

class _OnboardingBootstrapState extends State<_OnboardingBootstrap> {
  static const _profileCompleteKey = 'author_studio.profile_setup_complete';
  static const _profileNameKey = 'author_studio.profile.name';
  static const _profileEmailKey = 'author_studio.profile.email';

  static const _profileStore = AuthorProfileStore();

  StarterProject? project;
  bool loading = true;
  bool profileComplete = false;
  bool openFirstDraft = false;
  bool startSprint = false;
  String? existingProfileName;
  String? existingProfileEmail;

  /// Local profiles offered on the login screen, most recently active first.
  List<AuthorProfile> profiles = const [];

  /// True while the author is on Create Your Profile rather than login.
  bool creatingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadStartupState();
  }

  Future<void> _loadStartupState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProject = await widget.store.loadProject();
    final roster = await _profileStore.loadProfiles();
    final storedName = (prefs.getString(_profileNameKey) ?? '').trim();
    final storedEmail = (prefs.getString(_profileEmailKey) ?? '').trim();
    if (!mounted) {
      return;
    }
    setState(() {
      project = savedProject;
      profiles = roster;
      existingProfileName = storedName.isEmpty ? null : storedName;
      existingProfileEmail = storedEmail.isEmpty ? null : storedEmail;
      profileComplete = false;
      creatingProfile = false;
      openFirstDraft = false;
      startSprint = false;
      loading = false;
    });
  }

  /// Enters the workspace as an existing local profile.
  Future<void> _continueAsProfile(AuthorProfile profile) async {
    await _profileStore.markActive(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_profileCompleteKey, true);
    final savedProject = await widget.store.loadProject();
    final roster = await _profileStore.loadProfiles();
    if (!mounted) {
      return;
    }
    setState(() {
      profileComplete = true;
      creatingProfile = false;
      project = savedProject;
      profiles = roster;
      existingProfileName = profile.displayName;
      existingProfileEmail = profile.email;
      openFirstDraft = false;
      startSprint = false;
    });
  }

  /// Saves a newly created profile and enters the workspace as that author.
  Future<void> _createProfile(AuthorProfile profile) async {
    final created = await _profileStore.createProfile(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_profileCompleteKey, true);
    final savedProject = await widget.store.loadProject();
    final roster = await _profileStore.loadProfiles();
    if (!mounted) {
      return;
    }
    setState(() {
      profileComplete = true;
      creatingProfile = false;
      project = savedProject;
      profiles = roster;
      existingProfileName = created.displayName;
      existingProfileEmail = created.email;
      openFirstDraft = false;
      startSprint = false;
    });
  }

  Future<void> _completeOnboarding(OnboardingResult result) async {
    await widget.store.saveProject(result.project);
    if (!mounted) {
      return;
    }
    setState(() {
      project = result.project;
      openFirstDraft = true;
      startSprint = result.startSprint;
    });
  }

  Future<void> _resetStartupState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileCompleteKey);
    await prefs.remove(_profileNameKey);
    await prefs.remove(_profileEmailKey);
    await prefs.remove(AuthorProfileStore.profilesKey);
    await OnboardingStore.clearProjectState();
    if (!mounted) {
      return;
    }
    setState(() {
      project = null;
      profiles = const [];
      profileComplete = false;
      creatingProfile = false;
      openFirstDraft = false;
      startSprint = false;
      existingProfileName = null;
      existingProfileEmail = null;
    });
  }

  Future<void> _logoutToProfileSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileCompleteKey);
    await AppSupabase.signOut();
    final roster = await _profileStore.loadProfiles();
    final storedName = (prefs.getString(_profileNameKey) ?? '').trim();
    final storedEmail = (prefs.getString(_profileEmailKey) ?? '').trim();
    if (!mounted) {
      return;
    }
    setState(() {
      project = null;
      profiles = roster;
      profileComplete = false;
      creatingProfile = false;
      openFirstDraft = false;
      startSprint = false;
      // Signing back in passes through the opening page again.
      welcomeDismissed = false;
      existingProfileName = storedName.isEmpty ? null : storedName;
      existingProfileEmail = storedEmail.isEmpty ? null : storedEmail;
    });
  }

  /// Set once the author leaves the welcome page, so returning to the shell
  /// does not bounce them back to the launcher.
  bool welcomeDismissed = false;

  /// Section the welcome page asked for, opened on the first shell build.
  StudioSection? welcomeTarget;

  /// Maps a welcome page action onto the studio section that serves it.
  ///
  /// The launcher offers a few entry points the studio does not model as its
  /// own section yet -- templates and recent projects both live in Projects,
  /// and "continue writing" drops straight into the manuscript.
  void _openFromWelcome(WelcomeAction action) {
    setState(() {
      welcomeDismissed = true;
      welcomeTarget = switch (action) {
        WelcomeAction.openProject ||
        WelcomeAction.newProject ||
        WelcomeAction.recentProjects ||
        WelcomeAction.templates =>
          StudioSection.projects,
        WelcomeAction.worlds || WelcomeAction.buildWorld => StudioSection.world,
        WelcomeAction.settings => StudioSection.settings,
        WelcomeAction.createCharacter => StudioSection.characters,
        WelcomeAction.openTimeline => StudioSection.timeline,
        WelcomeAction.newManuscript ||
        WelcomeAction.continueWriting =>
          StudioSection.manuscript,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Startup asks who is entering before anything else is shown. Only once a
    // profile is chosen or created does the welcome page greet that author.
    if (!profileComplete) {
      if (creatingProfile) {
        return CreateProfilePage(
          onStartAdventure: _createProfile,
          onBack: () => setState(() => creatingProfile = false),
        );
      }
      return LoginSelectUserPage(
        profiles: profiles,
        onContinue: _continueAsProfile,
        onAddNewUser: () => setState(() => creatingProfile = true),
        onReset: _resetStartupState,
      );
    }

    // The welcome page is now the authenticated landing page: it greets the
    // author who just signed in, then falls through to whichever step is still
    // outstanding -- the first project, or the studio itself.
    if (widget.showWelcome && !welcomeDismissed) {
      return WelcomePage(
        onAction: _openFromWelcome,
        authorName: existingProfileName,
        heroImage: const AssetImage('assets/welcome-hero.png'),
      );
    }

    final currentProject = project;
    if (currentProject == null) {
      return FirstRunProjectWizard(
        onComplete: _completeOnboarding,
        onSignIn: _logoutToProfileSelection,
      );
    }

    return AuthorStudioShell(
      project: currentProject,
      manuscriptStore: widget.manuscriptStore,
      openFirstDraft: openFirstDraft,
      startSprint: startSprint,
      themeSelection: widget.themeSelection,
      onThemeSelectionChanged: widget.onThemeSelectionChanged,
      themeId: widget.themeId,
      accentId: widget.accentId,
      onThemeChanged: widget.onThemeChanged,
      onLogout: _logoutToProfileSelection,
      initialSection: welcomeTarget,
    );
  }
}

enum StudioSection {
  dashboard,
  worldBoard,
  search,
  statistics,
  backup,
  projects,
  ideas,
  manuscript,
  chapters,
  characters,
  codex,
  world,
  plot,
  timeline,
  notes,
  settings,
}

extension StudioSectionData on StudioSection {
  String get label => switch (this) {
        StudioSection.dashboard => 'Dashboard',
        StudioSection.worldBoard => 'World Board',
        StudioSection.search => 'Search',
        StudioSection.statistics => 'Statistics',
        StudioSection.backup => 'Backup',
        StudioSection.projects => 'Projects',
        StudioSection.ideas => 'Ideas',
        StudioSection.manuscript => 'Manuscript',
        StudioSection.chapters => 'Chapters',
        StudioSection.characters => 'Characters',
        StudioSection.codex => 'Story Codex',
        StudioSection.world => 'World',
        StudioSection.plot => 'Plot',
        StudioSection.timeline => 'Timeline',
        StudioSection.notes => 'Notes',
        StudioSection.settings => 'Settings',
      };

  IconData get icon => switch (this) {
        StudioSection.dashboard => Icons.space_dashboard_outlined,
        StudioSection.worldBoard => Icons.hub_outlined,
        StudioSection.search => Icons.search_outlined,
        StudioSection.statistics => Icons.bar_chart_outlined,
        StudioSection.backup => Icons.backup_outlined,
        StudioSection.projects => Icons.folder_copy_outlined,
        StudioSection.ideas => Icons.lightbulb_outline,
        StudioSection.manuscript => Icons.menu_book_outlined,
        StudioSection.chapters => Icons.chrome_reader_mode_outlined,
        StudioSection.characters => Icons.groups_outlined,
        StudioSection.codex => Icons.auto_stories_outlined,
        StudioSection.world => Icons.public_outlined,
        StudioSection.plot => Icons.route_outlined,
        StudioSection.timeline => Icons.timeline_outlined,
        StudioSection.notes => Icons.sticky_note_2_outlined,
        StudioSection.settings => Icons.settings_outlined,
      };
}

Future<void> _defaultLogout() async {}

class AuthorStudioShell extends StatefulWidget {
  const AuthorStudioShell({
    super.key,
    required this.project,
    this.openFirstDraft = false,
    this.startSprint = false,
    this.themeSelection,
    this.onThemeSelectionChanged,
    required this.themeId,
    required this.accentId,
    required this.onThemeChanged,
    this.manuscriptStore = const ManuscriptStore(),
    this.onLogout = _defaultLogout,
    this.initialSection,
  });

  final StarterProject project;
  final bool openFirstDraft;
  final bool startSprint;

  /// Section to open on first build; defaults to the manuscript.
  final StudioSection? initialSection;
  final ThemeSelection? themeSelection;
  final ValueChanged<ThemeSelection>? onThemeSelectionChanged;
  final String themeId;
  final String accentId;
  final void Function(String themeId, String accentId) onThemeChanged;
  final ManuscriptStore manuscriptStore;
  final Future<void> Function() onLogout;

  @override
  State<AuthorStudioShell> createState() => _AuthorStudioShellState();
}

class _AuthorStudioShellState extends State<AuthorStudioShell> {
  int selectedIndex = 0;
  bool focusModeEnabled = false;

  static const workspaceSections = <StudioSection>[
    StudioSection.dashboard,
    StudioSection.worldBoard,
    StudioSection.search,
    StudioSection.statistics,
    StudioSection.backup,
    StudioSection.projects,
    StudioSection.ideas,
    StudioSection.manuscript,
  ];

  static const storySections = <StudioSection>[
    StudioSection.chapters,
    StudioSection.characters,
    StudioSection.codex,
    StudioSection.world,
    StudioSection.plot,
    StudioSection.timeline,
    StudioSection.notes,
  ];

  static const sections = <StudioSection>[
    ...workspaceSections,
    ...storySections,
    StudioSection.settings,
  ];

  @override
  void initState() {
    super.initState();
    final requested = widget.initialSection ?? StudioSection.manuscript;
    final index = sections.indexOf(requested);
    selectedIndex = index >= 0 ? index : sections.indexOf(StudioSection.manuscript);
  }

  void _selectSection(StudioSection section) {
    final index = sections.indexOf(section);
    if (index >= 0) {
      setState(() => selectedIndex = index);
    }
  }

  void _toggleFocusMode() {
    setState(() => focusModeEnabled = !focusModeEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final currentSection = sections[selectedIndex];
        final theme = Theme.of(context);

        final content = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _SectionView(
            key: ValueKey(currentSection),
            section: currentSection,
            project: widget.project,
            startSprint: widget.openFirstDraft && widget.startSprint,
            onNavigate: _selectSection,
            themeSelection: widget.themeSelection,
            onThemeSelectionChanged: widget.onThemeSelectionChanged,
            themeId: widget.themeId,
            accentId: widget.accentId,
            onThemeChanged: widget.onThemeChanged,
            manuscriptStore: widget.manuscriptStore,
            onLogout: widget.onLogout,
            minimalFocusMode:
                focusModeEnabled && currentSection == StudioSection.manuscript,
          ),
        );

        if (focusModeEnabled) {
          return Scaffold(
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    pinned: true,
                    floating: true,
                    snap: true,
                    expandedHeight: 88,
                    toolbarHeight: 72,
                    backgroundColor: theme.scaffoldBackgroundColor.withValues(
                      alpha: 0.96,
                    ),
                    surfaceTintColor: Colors.transparent,
                    titleSpacing: 0,
                    title: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentSection.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _HeaderActionButton(
                            key: const Key('focus-mode-toggle'),
                            icon: Icons.fullscreen_exit_rounded,
                            label: 'Exit focus',
                            tooltip: 'Toggle focus mode',
                            onPressed: _toggleFocusMode,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(
                                alpha: 0.26,
                              ),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 18, 18),
                    child: Column(
                      children: [
                        _TopBar(
                          section: currentSection,
                          onNavigate: _selectSection,
                          focusMode: false,
                          onToggleFocus: _toggleFocusMode,
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(
                                alpha: 0.38,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: content,
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
  const _TopBar({
    required this.section,
    required this.onNavigate,
    required this.focusMode,
    required this.onToggleFocus,
  });

  final StudioSection section;
  final ValueChanged<StudioSection> onNavigate;
  final bool focusMode;
  final VoidCallback onToggleFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionButtons = <Widget>[
      _HeaderActionButton(
        icon: Icons.search_rounded,
        label: 'Search',
        shortcut: 'Ctrl+K',
        tooltip: 'Open search',
        onPressed: () => onNavigate(StudioSection.search),
      ),
      _HeaderActionButton(
        icon: Icons.notifications_none_rounded,
        label: 'Alerts',
        badge: '3',
        tooltip: 'Review project alerts',
        onPressed: () => onNavigate(StudioSection.backup),
      ),
      _HeaderActionButton(
        icon: Icons.palette_outlined,
        label: 'Theme',
        tooltip: 'Open theme settings',
        onPressed: () => onNavigate(StudioSection.settings),
      ),
      _HeaderActionButton(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        tooltip: 'Open profile settings',
        onPressed: () => onNavigate(StudioSection.settings),
      ),
      _HeaderActionButton(
        key: const Key('focus-mode-toggle'),
        icon: focusMode
            ? Icons.fullscreen_exit_rounded
            : Icons.fullscreen_rounded,
        label: focusMode ? 'Exit focus' : 'Focus',
        tooltip: 'Toggle focus mode',
        onPressed: onToggleFocus,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 20, 12),
      child: Row(
        children: [
          const _AppMark(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Indie Author OS',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  focusMode
                      ? 'Focused drafting mode'
                      : 'Write with structure, continuity, and momentum',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: focusMode
                  ? [
                      _HeaderActionButton(
                        icon: Icons.palette_outlined,
                        label: 'Theme',
                        tooltip: 'Open theme settings',
                        onPressed: () => onNavigate(StudioSection.settings),
                      ),
                      _HeaderActionButton(
                        key: const Key('focus-mode-toggle'),
                        icon: Icons.fullscreen_exit_rounded,
                        label: 'Exit focus',
                        tooltip: 'Toggle focus mode',
                        onPressed: onToggleFocus,
                      ),
                    ]
                  : actionButtons,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.shortcut,
    this.badge,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final String? badge;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (shortcut != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        shortcut!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/author-studio-logo.png',
          fit: BoxFit.contain,
        ),
      ),
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

  static const workspaceSections = <StudioSection>[
    StudioSection.dashboard,
    StudioSection.worldBoard,
    StudioSection.search,
    StudioSection.statistics,
    StudioSection.backup,
    StudioSection.projects,
    StudioSection.ideas,
    StudioSection.manuscript,
  ];

  static const storySections = <StudioSection>[
    StudioSection.chapters,
    StudioSection.characters,
    StudioSection.codex,
    StudioSection.world,
    StudioSection.plot,
    StudioSection.timeline,
    StudioSection.notes,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORKSPACE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Indie Author OS',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                _NavigationGroup(
                  label: 'WORKSPACE',
                  items: workspaceSections,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  sections: sections,
                ),
                const SizedBox(height: 16),
                _NavigationGroup(
                  label: 'STORY',
                  items: storySections,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  sections: sections,
                ),
                const SizedBox(height: 16),
                _NavigationTile(
                  section: StudioSection.settings,
                  isSelected:
                      selectedIndex == sections.indexOf(StudioSection.settings),
                  onTap: () =>
                      onSelected(sections.indexOf(StudioSection.settings)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationGroup extends StatelessWidget {
  const _NavigationGroup({
    required this.label,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.sections,
  });

  final String label;
  final List<StudioSection> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<StudioSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 8),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...items.map((section) {
          final sectionIndex = sections.indexOf(section);
          return _NavigationTile(
            section: section,
            isSelected: sectionIndex == selectedIndex,
            onTap: () => onSelected(sectionIndex),
          );
        }),
      ],
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final StudioSection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
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
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 88,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
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
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(section.label),
              ],
            ),
            backgroundColor: theme.colorScheme.surface,
            selectedColor: theme.colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          );
        },
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({
    super.key,
    required this.section,
    required this.project,
    required this.startSprint,
    required this.onNavigate,
    this.themeSelection,
    this.onThemeSelectionChanged,
    required this.themeId,
    required this.accentId,
    required this.onThemeChanged,
    required this.manuscriptStore,
    this.onLogout,
    this.minimalFocusMode = false,
  });

  final StudioSection section;
  final StarterProject project;
  final bool startSprint;
  final ValueChanged<StudioSection> onNavigate;
  final ThemeSelection? themeSelection;
  final ValueChanged<ThemeSelection>? onThemeSelectionChanged;
  final String themeId;
  final String accentId;
  final void Function(String themeId, String accentId) onThemeChanged;
  final ManuscriptStore manuscriptStore;
  final Future<void> Function()? onLogout;
  final bool minimalFocusMode;

  @override
  Widget build(BuildContext context) {
    if (section == StudioSection.manuscript) {
      final studio = Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final manuscript = ManuscriptStudioView(
              project: project,
              startSprint: startSprint,
              minimalMode: minimalFocusMode,
              store: manuscriptStore,
            );
            final research = _ResearchSidePanel(projectId: project.id);
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  Expanded(child: manuscript),
                  const SizedBox(height: 12),
                  SizedBox(height: 220, child: research),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: manuscript),
                const SizedBox(width: 12),
                SizedBox(width: 260, child: research),
              ],
            );
          },
        ),
      );
      if (minimalFocusMode) {
        return SizedBox(
          key: PageStorageKey(section),
          height: (MediaQuery.sizeOf(context).height - 140).clamp(520, 900),
          child: studio,
        );
      }
      return SizedBox.expand(
        key: PageStorageKey(section),
        child: studio,
      );
    }

    return SingleChildScrollView(
      key: PageStorageKey(section),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: switch (section) {
        StudioSection.dashboard => _DashboardView(
            project: project,
            onNavigate: onNavigate,
          ),
        StudioSection.worldBoard => WorldBoardView(
            project: project,
            manuscriptStore: manuscriptStore,
            onNavigate: (destination) => onNavigate(
              switch (destination) {
                WorldBoardDestination.projects => StudioSection.projects,
                WorldBoardDestination.manuscript => StudioSection.manuscript,
                WorldBoardDestination.characters => StudioSection.characters,
                WorldBoardDestination.world => StudioSection.world,
                WorldBoardDestination.timeline => StudioSection.timeline,
                WorldBoardDestination.plot => StudioSection.plot,
              },
            ),
          ),
        StudioSection.search => SearchStudioView(project: project),
        StudioSection.statistics => StatisticsStudioView(project: project),
        StudioSection.backup => const BackupHealthView(),
        StudioSection.projects => const _ProjectsStudioView(),
        StudioSection.ideas => const RecordStudioView(
            collection: 'ideas',
            title: 'Ideas',
            subtitle: 'Capture concepts, prompts, and story fragments.',
            categories: ['Concept', 'Scene', 'Dialogue', 'Research'],
          ),
        StudioSection.manuscript => const SizedBox.shrink(),
        StudioSection.chapters => ChapterStudioView(project: project),
        StudioSection.characters => CharacterBoardView(
            project: project,
            onNavigate: (destination) => onNavigate(
              switch (destination) {
                CharacterWorkspaceDestination.manuscript =>
                  StudioSection.manuscript,
                CharacterWorkspaceDestination.timeline =>
                  StudioSection.timeline,
                CharacterWorkspaceDestination.codex => StudioSection.world,
                CharacterWorkspaceDestination.world => StudioSection.world,
                CharacterWorkspaceDestination.plot => StudioSection.plot,
              },
            ),
          ),
        StudioSection.codex => StoryCodexWorkspace(
            projectId: project.id,
            onNavigate: (request) => onNavigate(
              switch (request.destination) {
                SearchDestination.characterStudio => StudioSection.characters,
                SearchDestination.worldStudio => StudioSection.world,
                SearchDestination.timelineStudio => StudioSection.timeline,
                SearchDestination.plotStudio => StudioSection.plot,
                SearchDestination.manuscriptStudio => StudioSection.manuscript,
                SearchDestination.seriesStudio => StudioSection.projects,
                SearchDestination.storyCodex ||
                SearchDestination.record =>
                  StudioSection.codex,
              },
            ),
          ),
        StudioSection.world => WorldWorkspace(
            projectId: project.id,
            onNavigate: (request) => onNavigate(
              switch (request.destination) {
                SearchDestination.characterStudio => StudioSection.characters,
                SearchDestination.worldStudio => StudioSection.world,
                SearchDestination.timelineStudio => StudioSection.timeline,
                SearchDestination.plotStudio => StudioSection.plot,
                SearchDestination.manuscriptStudio => StudioSection.manuscript,
                SearchDestination.seriesStudio => StudioSection.projects,
                SearchDestination.storyCodex => StudioSection.codex,
                SearchDestination.record => StudioSection.world,
              },
            ),
          ),
        StudioSection.plot => PlotStudioView(
          project: project,
          service: PlotService(
            projectId: project.id,
            repository: authorOsRepository,
          ),
        ),
        StudioSection.timeline => TimelineStudioView(project: project),
        StudioSection.notes => const _NotesStudioView(),
        StudioSection.settings => SettingsStudioView(
            selection: themeSelection,
            onSelectionChanged: onThemeSelectionChanged,
            themeId: themeId,
            accentId: accentId,
            onThemeChanged: onThemeChanged,
            onLogout: onLogout ?? () async {},
          ),
      },
    );
  }
}

enum ResearchTab { research, notes, timeline }

class ResearchReference {
  const ResearchReference({
    required this.title,
    required this.detail,
    required this.tag,
  });

  final String title;
  final String detail;
  final String tag;

  Map<String, String> toJson() => {
        'title': title,
        'detail': detail,
        'tag': tag,
      };

  factory ResearchReference.fromJson(Map<String, dynamic> json) =>
      ResearchReference(
        title: json['title'] as String? ?? 'Untitled reference',
        detail: json['detail'] as String? ?? '',
        tag: json['tag'] as String? ?? 'Research',
      );
}

class ProjectResearchStore {
  const ProjectResearchStore({required this.projectId});

  final String projectId;

  String get _key => 'author_studio.research_panel.$projectId';

  Future<Map<ResearchTab, List<ResearchReference>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    if (encoded == null || encoded.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final result = <ResearchTab, List<ResearchReference>>{};
      for (final entry in decoded.entries) {
        final tab = ResearchTab.values.firstWhere(
          (value) => value.name == entry.key,
          orElse: () => ResearchTab.research,
        );
        final items = (entry.value as List)
            .map((value) => ResearchReference.fromJson(
                Map<String, dynamic>.from(value as Map)))
            .toList();
        result[tab] = items;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> save(
      Map<ResearchTab, List<ResearchReference>> references) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, List<Map<String, String>>>{};
    for (final entry in references.entries) {
      payload[entry.key.name] =
          entry.value.map((reference) => reference.toJson()).toList();
    }
    await prefs.setString(_key, jsonEncode(payload));
  }
}

class _ResearchSidePanel extends StatefulWidget {
  const _ResearchSidePanel({required this.projectId});

  final String projectId;

  @override
  State<_ResearchSidePanel> createState() => _ResearchSidePanelState();
}

class _ResearchSidePanelState extends State<_ResearchSidePanel> {
  Map<ResearchTab, List<ResearchReference>> references = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded =
        await ProjectResearchStore(projectId: widget.projectId).load();
    if (!mounted) {
      return;
    }
    setState(() {
      references = {
        for (final tab in ResearchTab.values) tab: [...?loaded[tab]],
      };
      loading = false;
    });
  }

  Future<void> _addReference(ResearchTab tab) async {
    final titleController = TextEditingController();
    final detailController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${tab.name} reference'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Details'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    if (accepted != true || title.isEmpty) {
      return;
    }
    setState(() {
      references[tab] = [
        ...?references[tab],
        ResearchReference(
          title: title,
          detail: detailController.text.trim(),
          tag: tab.name,
        ),
      ];
    });
    await ProjectResearchStore(projectId: widget.projectId).save(references);
  }

  Future<void> _removeReference(ResearchTab tab, int index) async {
    setState(() {
      references[tab] = [...?references[tab]]..removeAt(index);
    });
    await ProjectResearchStore(projectId: widget.projectId).save(references);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: ResearchTab.values.length,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Text(
                'Pinned references',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Research'),
                Tab(text: 'Notes'),
                Tab(text: 'Timeline'),
              ],
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        for (final tab in ResearchTab.values) _buildTab(tab),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(ResearchTab tab) {
    final items = references[tab] ?? const [];
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No pinned references.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.title),
                      subtitle: item.detail.isEmpty ? null : Text(item.detail),
                      trailing: IconButton(
                        tooltip: 'Remove reference',
                        onPressed: () => _removeReference(tab, index),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addReference(tab),
              icon: const Icon(Icons.add),
              label: const Text('Pin reference'),
            ),
          ),
        ),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
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

class _TimelineStudioView extends StatefulWidget {
  const _TimelineStudioView({required this.project});

  final StarterProject project;

  @override
  State<_TimelineStudioView> createState() => _TimelineStudioViewState();
}

class _TimelineStudioViewState extends State<_TimelineStudioView> {
  static const eventPageSize = 30;
  final List<String> eventStatuses = const [
    'Planned',
    'Established',
    'Completed',
    'Archived',
  ];

  final List<String> importanceLevels = const [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  final List<String> eventTypes = const [
    'Historical',
    'Plot',
    'Character',
    'Political',
    'War',
    'Discovery',
    'Relationship',
    'World',
    'Personal',
    'Custom',
  ];

  final List<TimelineEvent> events = [];
  final List<TimelineEra> eras = [];
  final List<TimelineSequence> sequences = [];
  final TextEditingController searchController = TextEditingController();
  final Set<String> createdContinuityCharacters = {};
  final Set<String> createdContinuityLocations = {};

  bool isLoading = true;
  String statusFilter = 'All';
  String typeFilter = 'All';
  String eraFilter = 'All';
  String sequenceFilter = 'All';
  String sortMode = 'chronological';
  String selectedEventId = '';
  int visibleEventCount = eventPageSize;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final timeline = await const TimelineStore().load(widget.project);
    if (!mounted) {
      return;
    }
    setState(() {
      eras.addAll(timeline.eras);
      sequences.addAll(timeline.sequences);
      events.addAll(timeline.events);
      selectedEventId = events.isEmpty ? '' : events.first.id;
      isLoading = false;
    });
  }

  Future<void> _saveTimeline() => const TimelineStore().save(
        widget.project.id,
        TimelineState(eras: eras, sequences: sequences, events: events),
      );

  Future<void> _applyContinuityRecommendation(
    ContinuityIntegrityIssue issue,
  ) async {
    TimelineEvent? affectedEvent;
    for (final eventId in issue.eventIds.reversed) {
      final matchingEvents = events.where((event) => event.id == eventId);
      if (matchingEvents.isNotEmpty) {
        affectedEvent = matchingEvents.first;
        break;
      }
    }
    if (affectedEvent == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('The affected timeline event was not found.')),
        );
      }
      return;
    }

    setState(() => selectedEventId = affectedEvent!.id);
    if (issue.actionKind == ContinuityActionKind.create) {
      final suggestedName = switch (issue.type) {
        ContinuityWarningType.unknownLocation => affectedEvent.location,
        ContinuityWarningType.unknownCharacter => affectedEvent
                .presentCharacters
                .where((name) => !_knownCharacterNames.contains(name))
                .firstOrNull ??
            '',
        _ => '',
      };
      final name = await _confirmContinuityCreation(issue, suggestedName);
      if (name == null || !mounted) {
        return;
      }
      final result = await ContinuityActionService(
        projectId: widget.project.id,
        repository: authorOsRepository,
      ).createForRecommendation(
        issue,
        name: name,
        confirmed: true,
        recheck: () => !_warningResolvesWithName(issue, name),
      );
      if (!mounted) {
        return;
      }
      if (result.mutationApplied) {
        setState(() {
          if (issue.type == ContinuityWarningType.unknownCharacter) {
            createdContinuityCharacters.add(name);
          } else if (issue.type == ContinuityWarningType.unknownLocation) {
            createdContinuityLocations.add(name);
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    await openEventEditor(existing: affectedEvent);
  }

  Future<String?> _confirmContinuityCreation(
    ContinuityIntegrityIssue issue,
    String suggestedName,
  ) async {
    final controller = TextEditingController(text: suggestedName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(issue.type == ContinuityWarningType.unknownCharacter
            ? 'Create character'
            : 'Create location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue.message),
            const SizedBox(height: 16),
            TextField(
              key: const Key('continuity-create-name'),
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: issue.type == ContinuityWarningType.unknownCharacter
                    ? 'Character name'
                    : 'Location name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-continuity-create'),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  bool _warningResolvesWithName(
    ContinuityIntegrityIssue issue,
    String createdName,
  ) {
    final warnings = const ContinuityAnalyzer().analyze(
      continuityEvents,
      knownCharacters: {..._knownCharacterNames, createdName},
      knownLocations: {..._knownLocationNames, createdName},
    );
    return !warnings.any((warning) =>
        warning.type == issue.type &&
        warning.eventIds.any(issue.eventIds.contains));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<TimelineEvent> get filteredEvents {
    final query = searchController.text.trim().toLowerCase();

    final base = events.where((event) {
      if (statusFilter != 'All' && event.status != statusFilter) {
        return false;
      }
      if (typeFilter != 'All' && event.type != typeFilter) {
        return false;
      }
      if (eraFilter != 'All' && event.eraId != eraFilter) {
        return false;
      }
      if (sequenceFilter != 'All' && event.sequenceId != sequenceFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = '${event.title} ${event.description} ${event.dateLabel}'
          .toLowerCase();
      return haystack.contains(query);
    }).toList();

    int importanceRank(String level) {
      switch (level) {
        case 'Critical':
          return 4;
        case 'High':
          return 3;
        case 'Medium':
          return 2;
        default:
          return 1;
      }
    }

    switch (sortMode) {
      case 'updated-desc':
        base.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case 'created-desc':
        base.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'title-asc':
        base.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 'title-desc':
        base.sort(
            (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case 'importance-desc':
        base.sort((a, b) => importanceRank(b.importance)
            .compareTo(importanceRank(a.importance)));
      case 'order-asc':
        base.sort((a, b) => a.order.compareTo(b.order));
      default:
        base.sort((a, b) => a.order.compareTo(b.order));
    }

    return base;
  }

  TimelineEvent? get selectedEvent {
    if (selectedEventId.isEmpty) {
      return null;
    }
    for (final event in events) {
      if (event.id == selectedEventId) {
        return event;
      }
    }
    return null;
  }

  int get plannedCount =>
      events.where((event) => event.status == 'Planned').length;
  int get completedCount =>
      events.where((event) => event.status == 'Completed').length;
  List<ContinuityEventSnapshot> get continuityEvents => events
      .map((event) => ContinuityEventSnapshot(
            id: event.id,
            title: event.title,
            startDay: event.startDay,
            endDay: event.endDay,
            order: event.order,
            pov: event.pov,
            plotline: event.plotline,
            presentCharacters: event.presentCharacters,
            dateLabel: event.dateLabel,
            type: event.type,
            location: event.location,
            travelDaysFromPrevious: event.travelDaysFromPrevious,
          ))
      .toList();
  Set<String> get _knownCharacterNames => {
        ...widget.project.characterSheets.map((character) => character.name),
        ...StoryCodexReferenceIndex.characterNames(
          StoryCodexStore.defaultEntries,
        ),
        ...createdContinuityCharacters,
      };
  Set<String> get _knownLocationNames => {
        ...StoryCodexReferenceIndex.locationNames(
          StoryCodexStore.defaultEntries,
        ),
        ...createdContinuityLocations,
      };
  List<ContinuityWarning> get continuityWarnings {
    return const ContinuityAnalyzer().analyze(
      continuityEvents,
      knownCharacters: _knownCharacterNames,
      knownLocations: _knownLocationNames,
    );
  }

  int get warningCount => continuityWarnings.length;

  ImpactTraceResult? get selectedImpactTrace {
    final selected = selectedEvent;
    if (selected == null) {
      return null;
    }

    final entities = <TraceEntity>[];
    final links = <TraceLink>[];
    final entityIds = <String>{};
    void addEntity(TraceEntity entity) {
      if (entityIds.add(entity.id)) {
        entities.add(entity);
      }
    }

    for (final event in events) {
      final sceneId = 'scene:${event.id}';
      addEntity(TraceEntity(
          id: sceneId, label: event.title, type: TraceEntityType.scene));
      for (final character in event.presentCharacters) {
        final characterId = 'character:$character';
        addEntity(TraceEntity(
            id: characterId,
            label: character,
            type: TraceEntityType.character));
        links.add(TraceLink(
            sourceId: sceneId, targetId: characterId, label: 'features'));
      }
      if (event.plotline.isNotEmpty) {
        final plotlineId = 'plotline:${event.plotline}';
        addEntity(TraceEntity(
            id: plotlineId,
            label: event.plotline,
            type: TraceEntityType.plotline));
        links.add(TraceLink(
            sourceId: sceneId, targetId: plotlineId, label: 'advances'));
      }
      if (event.linkedNote.isNotEmpty) {
        final noteId = 'note:${event.linkedNote}';
        addEntity(TraceEntity(
            id: noteId, label: event.linkedNote, type: TraceEntityType.note));
        links.add(TraceLink(
            sourceId: sceneId, targetId: noteId, label: 'references'));
      }
      if (event.plotBeat.isNotEmpty) {
        final beatId = 'beat:${event.plotBeat}';
        addEntity(TraceEntity(
            id: beatId, label: event.plotBeat, type: TraceEntityType.plotBeat));
        links.add(
            TraceLink(sourceId: sceneId, targetId: beatId, label: 'fulfills'));
      }
    }

    return const ImpactTraceAnalyzer().trace(
      sourceId: 'scene:${selected.id}',
      entities: entities,
      links: links,
    );
  }

  String getEraLabel(String eraId) {
    if (eraId.isEmpty) {
      return 'Unassigned';
    }
    final era =
        eras.where((item) => item.id == eraId).cast<TimelineEra?>().firstWhere(
              (item) => item != null,
              orElse: () => null,
            );
    return era?.title ?? 'Missing era reference';
  }

  String getSequenceLabel(String sequenceId) {
    if (sequenceId.isEmpty) {
      return 'Unassigned';
    }
    final sequence = sequences
        .where((item) => item.id == sequenceId)
        .cast<TimelineSequence?>()
        .firstWhere((item) => item != null, orElse: () => null);
    return sequence?.title ?? 'Missing sequence reference';
  }

  Future<void> openEraEditor({TimelineEra? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    var nextStatus = existing?.status ?? 'Planned';

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing == null ? 'Add Era' : 'Edit Era'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: nextStatus,
                  items: eventStatuses
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => nextStatus = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      setState(() {
        final now = DateTime.now();
        if (existing == null) {
          eras.add(
            TimelineEra(
              id: 'era_${now.microsecondsSinceEpoch}',
              title: titleController.text.trim(),
              status: nextStatus,
              description: descriptionController.text.trim(),
              createdAt: now,
              updatedAt: now,
            ),
          );
        } else {
          final index = eras.indexWhere((era) => era.id == existing.id);
          if (index >= 0) {
            eras[index] = eras[index].copyWith(
              title: titleController.text.trim(),
              status: nextStatus,
              description: descriptionController.text.trim(),
              updatedAt: now,
            );
          }
        }
      });
      await _saveTimeline();
    }

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> openSequenceEditor({TimelineSequence? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    var nextStatus = existing?.status ?? 'Planned';
    var nextEraId = existing?.eraId ?? (eras.isNotEmpty ? eras.first.id : '');

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing == null ? 'Add Sequence' : 'Edit Sequence'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: nextEraId.isEmpty ? null : nextEraId,
                  items: eras
                      .map((era) => DropdownMenuItem(
                          value: era.id, child: Text(era.title)))
                      .toList(),
                  onChanged: (value) {
                    setModalState(() => nextEraId = value ?? '');
                  },
                  decoration: const InputDecoration(labelText: 'Era'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: nextStatus,
                  items: eventStatuses
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => nextStatus = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      setState(() {
        final now = DateTime.now();
        if (existing == null) {
          sequences.add(
            TimelineSequence(
              id: 'seq_${now.microsecondsSinceEpoch}',
              title: titleController.text.trim(),
              status: nextStatus,
              description: descriptionController.text.trim(),
              eraId: nextEraId,
              order: sequences.length + 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
        } else {
          final index =
              sequences.indexWhere((sequence) => sequence.id == existing.id);
          if (index >= 0) {
            sequences[index] = sequences[index].copyWith(
              title: titleController.text.trim(),
              status: nextStatus,
              description: descriptionController.text.trim(),
              eraId: nextEraId,
              updatedAt: now,
            );
          }
        }
      });
      await _saveTimeline();
    }

    titleController.dispose();
    descriptionController.dispose();
  }

  void deleteEra(TimelineEra era) {
    setState(() {
      eras.removeWhere((item) => item.id == era.id);
      for (var i = 0; i < sequences.length; i++) {
        if (sequences[i].eraId == era.id) {
          sequences[i] =
              sequences[i].copyWith(eraId: '', updatedAt: DateTime.now());
        }
      }
      for (var i = 0; i < events.length; i++) {
        if (events[i].eraId == era.id) {
          events[i] = events[i].copyWith(eraId: '', updatedAt: DateTime.now());
        }
      }
    });
    unawaited(_saveTimeline());
  }

  void deleteSequence(TimelineSequence sequence) {
    setState(() {
      sequences.removeWhere((item) => item.id == sequence.id);
      for (var i = 0; i < events.length; i++) {
        if (events[i].sequenceId == sequence.id) {
          events[i] =
              events[i].copyWith(sequenceId: '', updatedAt: DateTime.now());
        }
      }
    });
    unawaited(_saveTimeline());
  }

  Future<void> openEventEditor({TimelineEvent? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    final dateController =
        TextEditingController(text: existing?.dateLabel ?? '');
    final startDayController =
        TextEditingController(text: (existing?.startDay ?? 1).toString());
    final endDayController =
        TextEditingController(text: (existing?.endDay ?? 1).toString());
    final plotlineController =
        TextEditingController(text: existing?.plotline ?? 'Main Plot');
    final locationController =
        TextEditingController(text: existing?.location ?? '');
    final travelDaysController = TextEditingController(
        text: (existing?.travelDaysFromPrevious ?? 0).toString());
    final linkedNoteController =
        TextEditingController(text: existing?.linkedNote ?? '');
    var nextPlotBeat = existing?.plotBeat ?? '';
    var nextPov = existing?.pov ?? '';
    final nextPresentCharacters = <String>{
      ...?existing?.presentCharacters,
    };
    var nextStatus = existing?.status ?? 'Planned';
    var nextImportance = existing?.importance ?? 'Medium';
    var nextType = existing?.type ?? 'Plot';
    var nextEraId = existing?.eraId ?? '';
    var nextSequenceId = existing?.sequenceId ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(existing == null
                  ? 'Add Timeline Event'
                  : 'Edit Timeline Event'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dateController,
                        decoration:
                            const InputDecoration(labelText: 'Date Label'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startDayController,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Start Day'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: endDayController,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'End Day'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: nextPov.isEmpty ? null : nextPov,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Unassigned')),
                          ...widget.project.characterSheets
                              .map((character) => DropdownMenuItem(
                                    value: character.name,
                                    child: Text(character.name),
                                  )),
                        ],
                        onChanged: (value) =>
                            setModalState(() => nextPov = value ?? ''),
                        decoration: const InputDecoration(labelText: 'POV'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: plotlineController,
                        decoration:
                            const InputDecoration(labelText: 'Plotline'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration:
                            const InputDecoration(labelText: 'Location'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: travelDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Travel days required from prior location',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: linkedNoteController,
                        decoration:
                            const InputDecoration(labelText: 'Linked note'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue:
                            nextPlotBeat.isEmpty ? null : nextPlotBeat,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Unassigned')),
                          ...widget.project.beatChecklist.map((beat) =>
                              DropdownMenuItem(value: beat, child: Text(beat))),
                        ],
                        onChanged: (value) =>
                            setModalState(() => nextPlotBeat = value ?? ''),
                        decoration: const InputDecoration(
                            labelText: 'Linked plot beat'),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Characters present',
                            style: Theme.of(context).textTheme.labelLarge),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: widget.project.characterSheets
                              .map((character) => FilterChip(
                                    label: Text(character.name),
                                    selected: nextPresentCharacters
                                        .contains(character.name),
                                    onSelected: (selected) {
                                      setModalState(() {
                                        if (selected) {
                                          nextPresentCharacters
                                              .add(character.name);
                                        } else {
                                          nextPresentCharacters
                                              .remove(character.name);
                                        }
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: nextStatus,
                        items: eventStatuses
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => nextStatus = value);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Status'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: nextImportance,
                        items: importanceLevels
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => nextImportance = value);
                          }
                        },
                        decoration:
                            const InputDecoration(labelText: 'Importance'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: nextType,
                        items: eventTypes
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => nextType = value);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Type'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: nextEraId.isEmpty ? null : nextEraId,
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Unassigned')),
                          ...eras.map((era) => DropdownMenuItem(
                              value: era.id, child: Text(era.title))),
                        ],
                        onChanged: (value) {
                          setModalState(() {
                            nextEraId = value ?? '';
                            if (nextEraId.isNotEmpty &&
                                nextSequenceId.isNotEmpty &&
                                sequences.any((item) =>
                                    item.id == nextSequenceId &&
                                    item.eraId != nextEraId)) {
                              nextSequenceId = '';
                            }
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Era'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue:
                            nextSequenceId.isEmpty ? null : nextSequenceId,
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Unassigned')),
                          ...sequences
                              .where((sequence) =>
                                  nextEraId.isEmpty ||
                                  sequence.eraId == nextEraId)
                              .map(
                                (sequence) => DropdownMenuItem(
                                  value: sequence.id,
                                  child: Text(sequence.title),
                                ),
                              ),
                        ],
                        onChanged: (value) {
                          setModalState(() => nextSequenceId = value ?? '');
                        },
                        decoration:
                            const InputDecoration(labelText: 'Sequence'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 4,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      titleController.dispose();
      descriptionController.dispose();
      dateController.dispose();
      startDayController.dispose();
      endDayController.dispose();
      plotlineController.dispose();
      locationController.dispose();
      travelDaysController.dispose();
      linkedNoteController.dispose();
      return;
    }

    setState(() {
      final now = DateTime.now();

      if (existing == null) {
        final event = TimelineEvent(
          id: 'event_${now.microsecondsSinceEpoch}',
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          dateLabel: dateController.text.trim(),
          startDay: int.tryParse(startDayController.text.trim()) ?? 1,
          endDay: int.tryParse(endDayController.text.trim()) ?? 1,
          pov: nextPov,
          plotline: plotlineController.text.trim(),
          presentCharacters: nextPresentCharacters.toList()..sort(),
          location: locationController.text.trim(),
          travelDaysFromPrevious:
              int.tryParse(travelDaysController.text.trim()) ?? 0,
          linkedNote: linkedNoteController.text.trim(),
          plotBeat: nextPlotBeat,
          status: nextStatus,
          importance: nextImportance,
          type: nextType,
          eraId: nextEraId,
          sequenceId: nextSequenceId,
          order: events.length + 1,
          createdAt: now,
          updatedAt: now,
        );
        events.add(event);
        selectedEventId = event.id;
      } else {
        final index = events.indexWhere((event) => event.id == existing.id);
        if (index >= 0) {
          events[index] = events[index].copyWith(
            title: titleController.text.trim(),
            description: descriptionController.text.trim(),
            dateLabel: dateController.text.trim(),
            startDay: int.tryParse(startDayController.text.trim()) ?? 1,
            endDay: int.tryParse(endDayController.text.trim()) ?? 1,
            pov: nextPov,
            plotline: plotlineController.text.trim(),
            presentCharacters: nextPresentCharacters.toList()..sort(),
            location: locationController.text.trim(),
            travelDaysFromPrevious:
                int.tryParse(travelDaysController.text.trim()) ?? 0,
            linkedNote: linkedNoteController.text.trim(),
            plotBeat: nextPlotBeat,
            status: nextStatus,
            importance: nextImportance,
            type: nextType,
            eraId: nextEraId,
            sequenceId: nextSequenceId,
            updatedAt: now,
          );
        }
      }
    });
    await _saveTimeline();

    titleController.dispose();
    descriptionController.dispose();
    dateController.dispose();
    startDayController.dispose();
    endDayController.dispose();
    plotlineController.dispose();
    locationController.dispose();
    travelDaysController.dispose();
    linkedNoteController.dispose();
  }

  void deleteEvent(TimelineEvent event) {
    setState(() {
      events.removeWhere((item) => item.id == event.id);
      if (selectedEventId == event.id) {
        selectedEventId = events.isNotEmpty ? events.first.id : '';
      }
    });
    unawaited(_saveTimeline());
  }

  void moveEvent(TimelineEvent event, int delta) {
    final index = events.indexWhere((item) => item.id == event.id);
    final nextIndex = index + delta;
    if (index < 0 || nextIndex < 0 || nextIndex >= events.length) {
      return;
    }

    setState(() {
      final item = events.removeAt(index);
      events.insert(nextIndex, item);
      for (var i = 0; i < events.length; i++) {
        events[i] = events[i].copyWith(order: i + 1, updatedAt: DateTime.now());
      }
    });
    unawaited(_saveTimeline());
  }

  String formatTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final matchingEvents = filteredEvents;
    final currentEvents = matchingEvents.take(visibleEventCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timeline Studio',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Build chronology with dates, status, and importance tracking.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => openEventEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Add Event'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => openEraEditor(),
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Add Era'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => openSequenceEditor(),
              icon: const Icon(Icons.linear_scale_outlined),
              label: const Text('Add Sequence'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricChip(label: 'Events', value: events.length.toString()),
            _MetricChip(label: 'Eras', value: eras.length.toString()),
            _MetricChip(label: 'Sequences', value: sequences.length.toString()),
            _MetricChip(label: 'Planned', value: plannedCount.toString()),
            _MetricChip(label: 'Completed', value: completedCount.toString()),
            _MetricChip(label: 'Warnings', value: warningCount.toString()),
          ],
        ),
        const SizedBox(height: 16),
        ContinuityTimelinePanel(
          events: continuityEvents,
          warnings: continuityWarnings,
          selectedEventId: selectedEventId,
          onEventSelected: (eventId) =>
              setState(() => selectedEventId = eventId),
          onRecommendationSelected: _applyContinuityRecommendation,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Status', isDense: true),
                  items: ['All', ...eventStatuses]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => statusFilter = value ?? 'All'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: typeFilter,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Type', isDense: true),
                  items: ['All', ...eventTypes]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => typeFilter = value ?? 'All'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: eraFilter,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Era', isDense: true),
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All')),
                    ...eras.map(
                      (era) => DropdownMenuItem(
                          value: era.id, child: Text(era.title)),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => eraFilter = value ?? 'All'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: sequenceFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sequence',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All')),
                    ...sequences
                        .where((sequence) =>
                            eraFilter == 'All' || sequence.eraId == eraFilter)
                        .map(
                          (sequence) => DropdownMenuItem(
                            value: sequence.id,
                            child: Text(sequence.title),
                          ),
                        ),
                  ],
                  onChanged: (value) =>
                      setState(() => sequenceFilter = value ?? 'All'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: sortMode,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Sort', isDense: true),
                  items: const [
                    DropdownMenuItem(
                        value: 'chronological', child: Text('Chronological')),
                    DropdownMenuItem(
                        value: 'updated-desc', child: Text('Recently updated')),
                    DropdownMenuItem(
                        value: 'created-desc', child: Text('Recently created')),
                    DropdownMenuItem(
                        value: 'title-asc', child: Text('Title A-Z')),
                    DropdownMenuItem(
                        value: 'title-desc', child: Text('Title Z-A')),
                    DropdownMenuItem(
                        value: 'importance-desc', child: Text('Importance')),
                    DropdownMenuItem(
                        value: 'order-asc', child: Text('Manual order')),
                  ],
                  onChanged: (value) =>
                      setState(() => sortMode = value ?? 'chronological'),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    statusFilter = 'All';
                    typeFilter = 'All';
                    eraFilter = 'All';
                    sequenceFilter = 'All';
                    sortMode = 'chronological';
                    searchController.clear();
                  });
                },
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  for (final event in currentEvents)
                    Card(
                      child: ListTile(
                        onTap: () => setState(() => selectedEventId = event.id),
                        title: Text(event.title),
                        subtitle: Text(
                            '${event.dateLabel.isEmpty ? 'Day ${event.startDay}-${event.endDay}' : event.dateLabel} | ${event.status} | ${event.type} | ${event.importance}\nPOV: ${event.pov.isEmpty ? 'Unassigned' : event.pov} | Plotline: ${event.plotline.isEmpty ? 'Unassigned' : event.plotline}\nEra: ${getEraLabel(event.eraId)} | Sequence: ${getSequenceLabel(event.sequenceId)}'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'Move up',
                              onPressed: () => moveEvent(event, -1),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'Move down',
                              onPressed: () => moveEvent(event, 1),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => openEventEditor(existing: event),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: event.status == 'Archived'
                                  ? 'Restore'
                                  : 'Archive',
                              onPressed: () {
                                setState(() {
                                  final index = events.indexWhere(
                                      (item) => item.id == event.id);
                                  if (index >= 0) {
                                    final status = event.status == 'Archived'
                                        ? 'Planned'
                                        : 'Archived';
                                    events[index] = event.copyWith(
                                        status: status,
                                        updatedAt: DateTime.now());
                                  }
                                });
                                unawaited(_saveTimeline());
                              },
                              icon: Icon(event.status == 'Archived'
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => deleteEvent(event),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (currentEvents.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No timeline events match current filters.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  if (matchingEvents.length > visibleEventCount)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton.icon(
                        key: const Key('load-more-primary-timeline-events'),
                        onPressed: () =>
                            setState(() => visibleEventCount += eventPageSize),
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          'Load ${matchingEvents.length - visibleEventCount > eventPageSize ? eventPageSize : matchingEvents.length - visibleEventCount} more events',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: selectedEvent == null
                      ? const Text('Select an event to inspect details.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedEvent!.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                                'Date: ${selectedEvent!.dateLabel.isEmpty ? 'Unknown' : selectedEvent!.dateLabel}'),
                            Text('Status: ${selectedEvent!.status}'),
                            Text('Type: ${selectedEvent!.type}'),
                            Text('Importance: ${selectedEvent!.importance}'),
                            Text(
                                'POV: ${selectedEvent!.pov.isEmpty ? 'Unassigned' : selectedEvent!.pov}'),
                            Text(
                                'Plotline: ${selectedEvent!.plotline.isEmpty ? 'Unassigned' : selectedEvent!.plotline}'),
                            Text(
                                'Present: ${selectedEvent!.presentCharacters.isEmpty ? 'No characters marked' : selectedEvent!.presentCharacters.join(', ')}'),
                            Text(
                                'Location: ${selectedEvent!.location.isEmpty ? 'Unassigned' : selectedEvent!.location}'),
                            Text(
                                'Travel required: ${selectedEvent!.travelDaysFromPrevious} days'),
                            Text(
                                'Linked note: ${selectedEvent!.linkedNote.isEmpty ? 'None' : selectedEvent!.linkedNote}'),
                            Text(
                                'Plot beat: ${selectedEvent!.plotBeat.isEmpty ? 'Unassigned' : selectedEvent!.plotBeat}'),
                            Text('Era: ${getEraLabel(selectedEvent!.eraId)}'),
                            Text(
                                'Sequence: ${getSequenceLabel(selectedEvent!.sequenceId)}'),
                            Text('Order: ${selectedEvent!.order}'),
                            const SizedBox(height: 10),
                            Text(
                              selectedEvent!.description.isEmpty
                                  ? 'No description yet.'
                                  : selectedEvent!.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Updated ${formatTime(selectedEvent!.updatedAt)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            if (selectedImpactTrace != null)
                              ImpactTracePanel(result: selectedImpactTrace!),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eras and Sequences',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                for (final era in eras)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${era.title} (${era.status})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit era',
                                onPressed: () => openEraEditor(existing: era),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete era',
                                onPressed: () => deleteEra(era),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          if (era.description.isNotEmpty)
                            Text(
                              era.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                          const SizedBox(height: 8),
                          for (final sequence in sequences
                              .where((sequence) => sequence.eraId == era.id))
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '• ${sequence.title} (${sequence.status})'),
                                ),
                                IconButton(
                                  tooltip: 'Edit sequence',
                                  onPressed: () =>
                                      openSequenceEditor(existing: sequence),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Delete sequence',
                                  onPressed: () => deleteSequence(sequence),
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                if (eras.isEmpty)
                  Text(
                    'No eras yet. Add an era to group sequence and event chronology.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectRecord {
  const _ProjectRecord({
    required this.id,
    required this.title,
    required this.template,
    required this.status,
    required this.goalWords,
    required this.currentWords,
    required this.description,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String template;
  final String status;
  final int goalWords;
  final int currentWords;
  final String description;
  final DateTime updatedAt;

  _ProjectRecord copyWith({
    String? title,
    String? template,
    String? status,
    int? goalWords,
    int? currentWords,
    String? description,
    DateTime? updatedAt,
  }) {
    return _ProjectRecord(
      id: id,
      title: title ?? this.title,
      template: template ?? this.template,
      status: status ?? this.status,
      goalWords: goalWords ?? this.goalWords,
      currentWords: currentWords ?? this.currentWords,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class _ProjectsStudioView extends StatefulWidget {
  const _ProjectsStudioView();

  @override
  State<_ProjectsStudioView> createState() => _ProjectsStudioViewState();
}

class _ProjectsStudioViewState extends State<_ProjectsStudioView> {
  final List<String> templates = const [
    'Novel',
    'Memoir',
    'Short Story',
    'Screenplay',
    'Series Planning',
  ];

  final List<_ProjectRecord> projects = [];
  final TextEditingController searchController = TextEditingController();

  String templateFilter = 'All';
  String statusFilter = 'All';
  String selectedProjectId = '';
  String authorName = 'Ari Rowan';
  String authorFocus = 'Fantasy romance and literary thrillers';
  String authorBio =
      'I write character-led stories with strong atmosphere, sharp stakes, and hopeful endings.';
  String avatarPath = '';
  bool publicProfile = true;

  @override
  void initState() {
    super.initState();
    _loadAuthorProfile();
    projects.addAll([
      _ProjectRecord(
        id: 'project_1',
        title: 'Ash and Lanterns',
        template: 'Novel',
        status: 'Active',
        goalWords: 90000,
        currentWords: 18420,
        description: 'Fantasy novel draft with three-act structure starter.',
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      _ProjectRecord(
        id: 'project_2',
        title: 'City of Quiet Bridges',
        template: 'Series Planning',
        status: 'Active',
        goalWords: 120000,
        currentWords: 42000,
        description: 'Series bible and book one outline.',
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
    selectedProjectId = projects.first.id;
  }

  Future<void> _loadAuthorProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      authorName = prefs.getString('author_studio.profile.name') ?? authorName;
      authorFocus =
          prefs.getString('author_studio.profile.focus') ?? authorFocus;
      authorBio = prefs.getString('author_studio.profile.bio') ?? authorBio;
      avatarPath =
          prefs.getString('author_studio.profile.avatar_path') ?? avatarPath;
      publicProfile =
          prefs.getBool('author_studio.profile.public') ?? publicProfile;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<_ProjectRecord> get filteredProjects {
    final query = searchController.text.trim().toLowerCase();
    return projects.where((project) {
      if (templateFilter != 'All' && project.template != templateFilter) {
        return false;
      }
      if (statusFilter != 'All' && project.status != statusFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return ('${project.title} ${project.description}'.toLowerCase())
          .contains(query);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  _ProjectRecord? get selectedProject {
    for (final project in projects) {
      if (project.id == selectedProjectId) {
        return project;
      }
    }
    return null;
  }

  String templateStarterText(String template) {
    switch (template) {
      case 'Novel':
        return 'Creates act structure, chapter placeholders, character sheets, and beat checklist.';
      case 'Memoir':
        return 'Creates memory timeline, voice notes area, and chapter reflection prompts.';
      case 'Short Story':
        return 'Creates compact arc scaffold, scene beats, and revision checklist.';
      case 'Screenplay':
        return 'Creates act breaks, slugline prompts, and dialogue pacing checklist.';
      default:
        return 'Creates multi-book map, shared world entries, and arc tracking.';
    }
  }

  Future<void> openProjectEditor({_ProjectRecord? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    final goalController = TextEditingController(
      text: existing?.goalWords.toString() ?? '90000',
    );
    var template = existing?.template ?? templates.first;
    var status = existing?.status ?? 'Active';

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing == null ? 'Create Project' : 'Edit Project'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration:
                        const InputDecoration(labelText: 'Project Title'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: template,
                    items: templates
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => template = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Template'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      templateStarterText(template),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Word Goal'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'Archived', child: Text('Archived')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => status = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      setState(() {
        final now = DateTime.now();
        final goal = int.tryParse(goalController.text.trim()) ?? 0;
        if (existing == null) {
          final project = _ProjectRecord(
            id: 'project_${now.microsecondsSinceEpoch}',
            title: titleController.text.trim(),
            template: template,
            status: status,
            goalWords: goal,
            currentWords: 0,
            description: descriptionController.text.trim(),
            updatedAt: now,
          );
          projects.add(project);
          selectedProjectId = project.id;
        } else {
          final index =
              projects.indexWhere((project) => project.id == existing.id);
          if (index >= 0) {
            projects[index] = projects[index].copyWith(
              title: titleController.text.trim(),
              template: template,
              status: status,
              goalWords: goal,
              description: descriptionController.text.trim(),
              updatedAt: now,
            );
          }
        }
      });
    }

    titleController.dispose();
    descriptionController.dispose();
    goalController.dispose();
  }

  void deleteProject(_ProjectRecord project) {
    setState(() {
      projects.removeWhere((item) => item.id == project.id);
      if (selectedProjectId == project.id) {
        selectedProjectId = projects.isNotEmpty ? projects.first.id : '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleProjects = filteredProjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarPath.isNotEmpty
                      ? Image.file(
                          File(avatarPath),
                          fit: BoxFit.cover,
                          width: 72,
                          height: 72,
                        )
                      : Container(
                          alignment: Alignment.center,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            authorName.isNotEmpty
                                ? authorName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              authorName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: publicProfile
                                  ? Colors.green.withValues(alpha: 0.14)
                                  : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              publicProfile
                                  ? 'Public profile'
                                  : 'Private profile',
                              style: TextStyle(
                                color: publicProfile
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authorFocus,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authorBio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Projects Studio',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Template-aware project creation and project hub workflows.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => openProjectEditor(),
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Search projects', isDense: true),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: templateFilter,
                decoration:
                    const InputDecoration(labelText: 'Template', isDense: true),
                items: ['All', ...templates]
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => templateFilter = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: statusFilter,
                decoration:
                    const InputDecoration(labelText: 'Status', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Archived', child: Text('Archived')),
                ],
                onChanged: (value) =>
                    setState(() => statusFilter = value ?? 'All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  for (final project in visibleProjects)
                    Card(
                      child: ListTile(
                        onTap: () =>
                            setState(() => selectedProjectId = project.id),
                        title: Text(project.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${project.template} | ${project.status} | Goal ${project.goalWords}'),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Author: $authorName',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () =>
                                  openProjectEditor(existing: project),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: project.status == 'Archived'
                                  ? 'Restore'
                                  : 'Archive',
                              onPressed: () {
                                setState(() {
                                  final index = projects.indexWhere(
                                      (item) => item.id == project.id);
                                  if (index >= 0) {
                                    projects[index] = projects[index].copyWith(
                                      status: project.status == 'Archived'
                                          ? 'Active'
                                          : 'Archived',
                                      updatedAt: DateTime.now(),
                                    );
                                  }
                                });
                              },
                              icon: Icon(project.status == 'Archived'
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => deleteProject(project),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (visibleProjects.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No projects match your filters.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: selectedProject == null
                      ? const Text('Select a project to inspect details.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedProject!.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text('Template: ${selectedProject!.template}'),
                            Text('Status: ${selectedProject!.status}'),
                            Text('Word Goal: ${selectedProject!.goalWords}'),
                            Text(
                                'Current Words: ${selectedProject!.currentWords}'),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: selectedProject!.goalWords == 0
                                  ? 0
                                  : (selectedProject!.currentWords /
                                          selectedProject!.goalWords)
                                      .clamp(0, 1),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              selectedProject!.description.isEmpty
                                  ? 'No description yet.'
                                  : selectedProject!.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              templateStarterText(selectedProject!.template),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white54),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NoteRecord {
  const _NoteRecord({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.status,
    required this.pinned,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String type;
  final String status;
  final bool pinned;
  final DateTime updatedAt;

  _NoteRecord copyWith({
    String? title,
    String? content,
    String? type,
    String? status,
    bool? pinned,
    DateTime? updatedAt,
  }) {
    return _NoteRecord(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      pinned: pinned ?? this.pinned,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class _NotesStudioView extends StatefulWidget {
  const _NotesStudioView();

  @override
  State<_NotesStudioView> createState() => _NotesStudioViewState();
}

class _NotesStudioViewState extends State<_NotesStudioView> {
  final List<String> noteTypes = const [
    'Idea',
    'Research',
    'Reference',
    'Revision',
    'Checklist',
  ];

  final List<_NoteRecord> notes = [];
  final TextEditingController searchController = TextEditingController();

  String typeFilter = 'All';
  String statusFilter = 'All';
  String sortMode = 'updated-desc';
  String selectedNoteId = '';

  @override
  void initState() {
    super.initState();
    notes.addAll([
      _NoteRecord(
        id: 'note_1',
        title: 'Bridge district sensory notes',
        content: 'Fog, brass railings, rainwater echoes, narrow alleys.',
        type: 'Research',
        status: 'Active',
        pinned: true,
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      _NoteRecord(
        id: 'note_2',
        title: 'Chapter 3 rewrite prompt',
        content: 'Raise tension before reveal and trim exposition.',
        type: 'Revision',
        status: 'Active',
        pinned: false,
        updatedAt: DateTime.now().subtract(const Duration(hours: 9)),
      ),
    ]);
    selectedNoteId = notes.first.id;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<_NoteRecord> get filteredNotes {
    final query = searchController.text.trim().toLowerCase();
    final base = notes.where((note) {
      if (typeFilter != 'All' && note.type != typeFilter) {
        return false;
      }
      if (statusFilter != 'All' && note.status != statusFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return ('${note.title} ${note.content}'.toLowerCase()).contains(query);
    }).toList();

    switch (sortMode) {
      case 'title-asc':
        base.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 'title-desc':
        base.sort(
            (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case 'updated-asc':
        base.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      default:
        base.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    base.sort((a, b) {
      if (a.pinned == b.pinned) {
        return 0;
      }
      return a.pinned ? -1 : 1;
    });

    return base;
  }

  _NoteRecord? get selectedNote {
    for (final note in notes) {
      if (note.id == selectedNoteId) {
        return note;
      }
    }
    return null;
  }

  Future<void> openNoteEditor({_NoteRecord? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    var type = existing?.type ?? noteTypes.first;
    var status = existing?.status ?? 'Active';
    var pinned = existing?.pinned ?? false;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing == null ? 'Add Note' : 'Edit Note'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: noteTypes
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => type = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'Archived', child: Text('Archived')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => status = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: pinned,
                  onChanged: (value) => setModalState(() => pinned = value),
                  title: const Text('Pinned'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Content'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      setState(() {
        final now = DateTime.now();
        if (existing == null) {
          final note = _NoteRecord(
            id: 'note_${now.microsecondsSinceEpoch}',
            title: titleController.text.trim(),
            content: contentController.text.trim(),
            type: type,
            status: status,
            pinned: pinned,
            updatedAt: now,
          );
          notes.add(note);
          selectedNoteId = note.id;
        } else {
          final index = notes.indexWhere((note) => note.id == existing.id);
          if (index >= 0) {
            notes[index] = notes[index].copyWith(
              title: titleController.text.trim(),
              content: contentController.text.trim(),
              type: type,
              status: status,
              pinned: pinned,
              updatedAt: now,
            );
          }
        }
      });
    }

    titleController.dispose();
    contentController.dispose();
  }

  void deleteNote(_NoteRecord note) {
    setState(() {
      notes.removeWhere((item) => item.id == note.id);
      if (selectedNoteId == note.id) {
        selectedNoteId = notes.isNotEmpty ? notes.first.id : '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotes = filteredNotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes Studio',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Capture, filter, and revise notes across your writing workspace.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => openNoteEditor(),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Add Note'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Search notes', isDense: true),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: typeFilter,
                decoration:
                    const InputDecoration(labelText: 'Type', isDense: true),
                items: ['All', ...noteTypes]
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => typeFilter = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: statusFilter,
                decoration:
                    const InputDecoration(labelText: 'Status', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Archived', child: Text('Archived')),
                ],
                onChanged: (value) =>
                    setState(() => statusFilter = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: sortMode,
                decoration:
                    const InputDecoration(labelText: 'Sort', isDense: true),
                items: const [
                  DropdownMenuItem(
                      value: 'updated-desc', child: Text('Recently updated')),
                  DropdownMenuItem(
                      value: 'updated-asc', child: Text('Oldest updated')),
                  DropdownMenuItem(
                      value: 'title-asc', child: Text('Title A-Z')),
                  DropdownMenuItem(
                      value: 'title-desc', child: Text('Title Z-A')),
                ],
                onChanged: (value) =>
                    setState(() => sortMode = value ?? 'updated-desc'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  for (final note in visibleNotes)
                    Card(
                      child: ListTile(
                        onTap: () => setState(() => selectedNoteId = note.id),
                        leading: Icon(
                          note.pinned
                              ? Icons.push_pin
                              : Icons.sticky_note_2_outlined,
                          color: note.pinned
                              ? const Color(0xFFC59B6D)
                              : Colors.white70,
                        ),
                        title: Text(note.title),
                        subtitle: Text('${note.type} | ${note.status}'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: note.pinned ? 'Unpin' : 'Pin',
                              onPressed: () {
                                setState(() {
                                  final index = notes
                                      .indexWhere((item) => item.id == note.id);
                                  if (index >= 0) {
                                    notes[index] = notes[index].copyWith(
                                      pinned: !note.pinned,
                                      updatedAt: DateTime.now(),
                                    );
                                  }
                                });
                              },
                              icon: Icon(note.pinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => openNoteEditor(existing: note),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: note.status == 'Archived'
                                  ? 'Restore'
                                  : 'Archive',
                              onPressed: () {
                                setState(() {
                                  final index = notes
                                      .indexWhere((item) => item.id == note.id);
                                  if (index >= 0) {
                                    notes[index] = notes[index].copyWith(
                                      status: note.status == 'Archived'
                                          ? 'Active'
                                          : 'Archived',
                                      updatedAt: DateTime.now(),
                                    );
                                  }
                                });
                              },
                              icon: Icon(
                                note.status == 'Archived'
                                    ? Icons.unarchive_outlined
                                    : Icons.archive_outlined,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => deleteNote(note),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (visibleNotes.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No notes match your filters.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: selectedNote == null
                      ? const Text('Select a note to inspect details.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedNote!.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text('Type: ${selectedNote!.type}'),
                            Text('Status: ${selectedNote!.status}'),
                            Text(
                                'Pinned: ${selectedNote!.pinned ? 'Yes' : 'No'}'),
                            const SizedBox(height: 10),
                            Text(
                              selectedNote!.content.isEmpty
                                  ? 'No note content yet.'
                                  : selectedNote!.content,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.project,
    required this.onNavigate,
  });

  final StarterProject project;
  final ValueChanged<StudioSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const cards = [
      _DashboardInfoTile(
        icon: '▣',
        title: 'Projects',
        body: 'Project-based organization and active story tracking.',
        accent: true,
        target: StudioSection.projects,
      ),
      _DashboardInfoTile(
        icon: '▤',
        title: 'Manuscript',
        body: 'Drafting workspace and writing momentum controls.',
        target: StudioSection.manuscript,
      ),
      _DashboardInfoTile(
        icon: '◇',
        title: 'Story',
        body: 'Characters, chapters, and story beats in one connected system.',
        target: StudioSection.chapters,
      ),
      _DashboardInfoTile(
        icon: '✦',
        title: 'Ideas',
        body: '12 total · 5 draft · 4 developing · 3 ready',
        target: StudioSection.ideas,
      ),
      _DashboardInfoTile(
        icon: '⌕',
        title: 'Universal Search',
        body:
            'Find projects, manuscript content, and story entities instantly.',
        actionLabel: 'Open Search',
        target: StudioSection.search,
      ),
      _DashboardInfoTile(
        icon: '◫',
        title: 'Statistics Studio',
        body:
            'Review manuscript, story, timeline, and notes analytics from canonical data.',
        actionLabel: 'Open Statistics',
        target: StudioSection.statistics,
      ),
      _DashboardInfoTile(
        icon: '⛁',
        title: 'Backup & Export',
        body: 'Create full backups, exports, and safe import previews.',
        actionLabel: 'Open Backup & Export',
        target: StudioSection.backup,
      ),
    ];

    final cardColumns = MediaQuery.of(context).size.width < 700
        ? 1
        : MediaQuery.of(context).size.width < 1100
            ? 2
            : 3;

    return FutureBuilder<AuthorProfileSummary>(
      future: AuthorProfileSummary.load(),
      builder: (context, snapshot) {
        final profile = snapshot.data ??
            const AuthorProfileSummary(
              name: AuthorProfileSummary.defaultName,
              focus: AuthorProfileSummary.defaultFocus,
              bio: AuthorProfileSummary.defaultBio,
              avatarPath: '',
              publicProfile: true,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: const Key('dashboard-hero'),
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTHOROS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ink & insight for your writing practice.',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.7),
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: profile.avatarPath.isNotEmpty
                              ? Image.file(
                                  File(profile.avatarPath),
                                  fit: BoxFit.cover,
                                  width: 62,
                                  height: 62,
                                )
                              : Container(
                                  alignment: Alignment.center,
                                  color: theme.colorScheme.primaryContainer,
                                  child: Text(
                                    profile.initials,
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.focus,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    profile.publicProfile
                                        ? Icons.public_outlined
                                        : Icons.lock_outline,
                                    size: 16,
                                    color: profile.publicProfile
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    profile.publicProfile
                                        ? 'Public author identity'
                                        : 'Private author identity',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Text(
                      'Welcome to the foundation of your authoring system.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GridView.builder(
              itemCount: cards.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cardColumns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: cardColumns == 1 ? 220 : 286,
              ),
              itemBuilder: (context, index) =>
                  cards[index].copyWith(onNavigate: onNavigate),
            ),
            const SizedBox(height: 24),
            Container(
              key: const Key('dashboard-recent-projects'),
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent Projects',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onNavigate(StudioSection.projects),
                        child: const Text('Open Story Library'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => onNavigate(StudioSection.projects),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(16),
                              ),
                            ),
                            child: Text(
                              '✦',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${project.genre} • ${project.projectType} • ${project.wordGoal} word target',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              key: const Key('dashboard-foundation'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FOUNDATION',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AuthorOS is online.',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'The AuthorOS foundation is operational. Core services, persistence, navigation, modules and diagnostics are active.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Text(
                      'READY',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
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

class _DashboardInfoTile extends StatelessWidget {
  const _DashboardInfoTile({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.accent = false,
    this.target,
    this.onNavigate,
  });

  final String icon;
  final String title;
  final String body;
  final String? actionLabel;
  final bool accent;
  final StudioSection? target;
  final ValueChanged<StudioSection>? onNavigate;

  _DashboardInfoTile copyWith({ValueChanged<StudioSection>? onNavigate}) {
    return _DashboardInfoTile(
      icon: icon,
      title: title,
      body: body,
      actionLabel: actionLabel,
      accent: accent,
      target: target,
      onNavigate: onNavigate ?? this.onNavigate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onTap = target == null || onNavigate == null
        ? null
        : () => onNavigate!(target!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        key: ValueKey('dashboard-tile-$title'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                icon,
                style: TextStyle(
                  color: accent
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  final targetSection = target ?? StudioSection.projects;
                  if (onNavigate != null) {
                    onNavigate!(targetSection);
                  }
                },
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
