import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'author_profile_store.dart';
import 'analytics_service.dart';
import 'analytics_studio_view.dart';
import 'backup_health.dart';
import 'character_studio.dart';
import 'core/connected_domain.dart' show AuthorRecord;
import 'core/search_models.dart' show SearchDestination;
import 'create_profile_page.dart';
import 'local_image.dart';
import 'login_select_user_page.dart';
import 'manuscript_studio.dart';
import 'manuscript_store.dart';
import 'map_studio_view.dart';
import 'migrations/research_panel_migration.dart';
import 'core/project_roster_entry.dart';
import 'core/writing_series.dart';
import 'onboarding.dart';
import 'project_roster_store.dart';
import 'plot_service.dart';
import 'persistence/authoros_database.dart';
import 'release_destinations.dart';
import 'research_service.dart';
import 'research_studio_view.dart';
import 'supabase_service.dart';
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
        title: 'AuthorOS',
        theme: themeData,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AuthorOS',
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

  /// Opens a different project from the roster.
  ///
  /// The roster is the durable list; this makes one of its entries the open
  /// one. It also writes the project back through [OnboardingStore], because
  /// `author_studio.starter_project` is still the pointer the app reads on
  /// next launch — the roster is additive, not a replacement for it.
  Future<void> _switchProject(StarterProject next) async {
    if (next.id == project?.id) return;
    await widget.store.saveProject(next);
    if (!mounted) return;
    setState(() {
      project = next;
      // A freshly opened project is not the one the author was mid-sprint in.
      openFirstDraft = false;
      startSprint = false;
    });
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
      onProjectChanged: _switchProject,
    );
  }
}

enum StudioSection {
  dashboard,
  worldBoard,
  search,
  statistics,
  analytics,
  backup,
  projects,
  ideas,
  manuscript,
  chapters,
  characters,
  codex,
  world,
  map,
  plot,
  timeline,
  research,
  notes,
  settings,
}

extension StudioSectionData on StudioSection {
  String get label => switch (this) {
        StudioSection.dashboard => 'Dashboard',
        StudioSection.worldBoard => 'World Board',
        StudioSection.search => 'Search',
        StudioSection.statistics => 'Statistics',
        StudioSection.analytics => 'Analytics',
        StudioSection.backup => 'Backup',
        StudioSection.projects => 'Projects',
        StudioSection.ideas => 'Ideas',
        StudioSection.manuscript => 'Manuscript',
        StudioSection.chapters => 'Chapters',
        StudioSection.characters => 'Characters',
        StudioSection.codex => 'Story Codex',
        StudioSection.world => 'World',
        StudioSection.map => 'Map',
        StudioSection.plot => 'Plot',
        StudioSection.timeline => 'Timeline',
        StudioSection.research => 'Research',
        StudioSection.notes => 'Notes',
        StudioSection.settings => 'Settings',
      };

  IconData get icon => switch (this) {
        StudioSection.dashboard => Icons.space_dashboard_outlined,
        StudioSection.worldBoard => Icons.hub_outlined,
        StudioSection.search => Icons.search_outlined,
        StudioSection.statistics => Icons.bar_chart_outlined,
        StudioSection.analytics => Icons.insights_outlined,
        StudioSection.backup => Icons.backup_outlined,
        StudioSection.projects => Icons.folder_copy_outlined,
        StudioSection.ideas => Icons.lightbulb_outline,
        StudioSection.manuscript => Icons.menu_book_outlined,
        StudioSection.chapters => Icons.chrome_reader_mode_outlined,
        StudioSection.characters => Icons.groups_outlined,
        StudioSection.codex => Icons.auto_stories_outlined,
        StudioSection.world => Icons.public_outlined,
        StudioSection.map => Icons.map_outlined,
        StudioSection.plot => Icons.route_outlined,
        StudioSection.timeline => Icons.timeline_outlined,
        StudioSection.research => Icons.local_library_outlined,
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
    this.onProjectChanged,
    this.rosterStore,
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

  /// Called when the author opens a different project from the Projects
  /// Studio. The host swaps the project and this shell rebuilds around it.
  final ValueChanged<StarterProject>? onProjectChanged;

  /// Where the Projects Studio reads the book roster from. Threaded through
  /// the shell the same way [manuscriptStore] is, so a test can hand in an
  /// in-memory database instead of the app-wide one.
  final ProjectRosterStore? rosterStore;

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
    StudioSection.analytics,
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
    StudioSection.map,
    StudioSection.plot,
    StudioSection.timeline,
    StudioSection.research,
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
            // Keyed by project as well as section: every Studio caches the
            // project in initState, so switching books has to remount them
            // rather than leave the previous book's services mounted.
            key: ValueKey('${currentSection.name}:${widget.project.id}'),
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
            onProjectChanged: widget.onProjectChanged,
            rosterStore: widget.rosterStore,
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
                  'AuthorOS',
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
    StudioSection.analytics,
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
    StudioSection.map,
    StudioSection.plot,
    StudioSection.timeline,
    StudioSection.research,
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
                  'AuthorOS',
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
              ],
            ),
          ),
          // Settings is pinned below the scrolling groups so it stays
          // reachable however many Studios the workspace grows to hold.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _NavigationTile(
              section: StudioSection.settings,
              isSelected:
                  selectedIndex == sections.indexOf(StudioSection.settings),
              onTap: () => onSelected(sections.indexOf(StudioSection.settings)),
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
    this.onProjectChanged,
    this.rosterStore,
  });

  final StudioSection section;
  final StarterProject project;

  /// Called when the author opens a different project from the Projects
  /// Studio. The shell rebuilds around it.
  final ValueChanged<StarterProject>? onProjectChanged;

  /// Where the Projects Studio reads the roster from; a test seam.
  final ProjectRosterStore? rosterStore;
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
              onNavigate: (request) => onNavigate(
                switch (request.destination) {
                  SearchDestination.characterStudio => StudioSection.characters,
                  SearchDestination.worldStudio => StudioSection.world,
                  SearchDestination.timelineStudio => StudioSection.timeline,
                  SearchDestination.plotStudio => StudioSection.plot,
                  SearchDestination.storyCodex => StudioSection.codex,
                  SearchDestination.seriesStudio => StudioSection.projects,
                  SearchDestination.manuscriptStudio ||
                  SearchDestination.record =>
                    StudioSection.manuscript,
                },
              ),
            );
            final research = _ResearchSidePanel(
              projectId: project.id,
              onOpenResearchStudio: () =>
                  onNavigate(StudioSection.research),
              // The shell's store already carries the repository the rest of
              // the manuscript section reads through; reuse it so tests can
              // inject an in-memory database without a new plumbing path.
              repository: manuscriptStore.repository,
            );
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
        StudioSection.analytics => AnalyticsStudioView(
            project: project,
            service: AnalyticsService(
              project: project,
              repository: authorOsRepository,
              manuscriptStore: manuscriptStore,
            ),
          ),
        StudioSection.backup => const BackupHealthView(),
        StudioSection.projects => _ProjectsStudioView(
            activeProjectId: project.id,
            onProjectChanged: onProjectChanged,
            manuscriptStore: manuscriptStore,
            rosterStore: rosterStore,
          ),
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
        StudioSection.map => MapStudioView(project: project),
        StudioSection.plot => PlotStudioView(
          project: project,
          service: PlotService(
            projectId: project.id,
            repository: authorOsRepository,
          ),
        ),
        StudioSection.timeline => TimelineStudioView(
            project: project,
            onNavigate: (request) => onNavigate(
              switch (request.destination) {
                SearchDestination.characterStudio => StudioSection.characters,
                SearchDestination.worldStudio => StudioSection.world,
                SearchDestination.timelineStudio => StudioSection.timeline,
                SearchDestination.plotStudio => StudioSection.plot,
                SearchDestination.manuscriptStudio => StudioSection.manuscript,
                SearchDestination.seriesStudio => StudioSection.projects,
                SearchDestination.storyCodex => StudioSection.codex,
                SearchDestination.record => StudioSection.timeline,
              },
            ),
          ),
        StudioSection.research => ResearchStudioView(
            project: project,
            service: ResearchService(
              projectId: project.id,
              repository: authorOsRepository,
            ),
          ),
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

/// The manuscript's research rail.
///
/// This used to own its own `SharedPreferences` store, which put research in
/// two places at once and left the panel's copy outside every backup path.
/// It is now a **read-only window onto canonical research records** — the same
/// records Research Studio shows. Creating and editing happen there; this
/// panel reads, and links across.
///
/// On first open for a project it runs [ResearchPanelMigrationService], which
/// lifts anything still in the legacy store into records. That migration is
/// idempotent and never deletes the legacy key.
class _ResearchSidePanel extends StatefulWidget {
  const _ResearchSidePanel({
    required this.projectId,
    this.onOpenResearchStudio,
    this.repository,
  });

  final String projectId;
  final VoidCallback? onOpenResearchStudio;

  /// Injectable for tests; defaults to the app-wide repository.
  final DriftConnectedDomainRepository? repository;

  @override
  State<_ResearchSidePanel> createState() => _ResearchSidePanelState();
}

class _ResearchSidePanelState extends State<_ResearchSidePanel> {
  List<AuthorRecord> entries = const [];
  bool loading = true;
  String? error;

  /// How many entries were lifted out of the legacy store on this open, so
  /// the author is told their pinned references moved rather than vanished.
  int migratedCount = 0;

  DriftConnectedDomainRepository get _repository =>
      widget.repository ?? authorOsRepository;

  ResearchService get _research => ResearchService(
        projectId: widget.projectId,
        repository: _repository,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ResearchSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      entries = const [];
      migratedCount = 0;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // Migrate first, so anything still in the legacy store shows up in the
      // list below on this very open rather than the next one.
      final report = await ResearchPanelMigrationService(
        projectId: widget.projectId,
        repository: _repository,
      ).migrate();
      final records = await _research.query.all();
      if (!mounted) return;
      setState(() {
        migratedCount = report.created.length;
        entries = records;
        loading = false;
      });
    } catch (loadError) {
      if (!mounted) return;
      setState(() {
        error = '$loadError';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('manuscript-research-panel'),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Research',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  key: const ValueKey('manuscript-research-refresh'),
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                  onPressed: loading ? null : _load,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
          ),
          if (migratedCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                migratedCount == 1
                    ? '1 pinned reference moved into your research library.'
                    : '$migratedCount pinned references moved into your '
                        'research library.',
                key: const ValueKey('manuscript-research-migrated-notice'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          Expanded(child: _buildBody(theme)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('manuscript-research-open-studio'),
                onPressed: widget.onOpenResearchStudio,
                icon: const Icon(Icons.local_library_outlined, size: 18),
                label: const Text('Open Research Studio'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            'Research could not be loaded.',
            key: const ValueKey('manuscript-research-error'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            'No research yet. Create entries in Research Studio and they '
            'appear here.',
            key: const ValueKey('manuscript-research-empty'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final record = entries[index];
        final summary = ResearchService.summaryOf(record);
        return ListTile(
          key: ValueKey('manuscript-research-${record.id}'),
          dense: true,
          leading: ResearchService.isImportant(record)
              ? const Icon(Icons.star, size: 16)
              : null,
          title: Text(record.title),
          subtitle: Text(
            summary.isEmpty
                ? '${ResearchService.kindOf(record)} · '
                    '${ResearchService.categoryOf(record)}'
                : summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

/// The Projects Studio — the author's book roster.
///
/// This screen used to be a mock: two hardcoded projects held in memory that
/// no amount of clicking ever persisted. It is now backed by
/// [ProjectRosterStore], which is what lets AuthorOS hold more than one book
/// at a time and what makes a series something real to measure.
///
/// Word counts here come from [ManuscriptStore.peekStudio], never
/// `loadStudio`: opening a list of projects must not create a manuscript for
/// every project in it.
class _ProjectsStudioView extends StatefulWidget {
  const _ProjectsStudioView({
    required this.activeProjectId,
    this.onProjectChanged,
    this.rosterStore,
    this.manuscriptStore = const ManuscriptStore(),
  });

  /// The project the shell currently has open, marked as active in the list.
  final String activeProjectId;

  /// Called when the author opens a different project. The shell rebuilds
  /// around it; this view does not switch anything by itself.
  final ValueChanged<StarterProject>? onProjectChanged;

  final ProjectRosterStore? rosterStore;
  final ManuscriptStore manuscriptStore;

  @override
  State<_ProjectsStudioView> createState() => _ProjectsStudioViewState();
}

class _ProjectsStudioViewState extends State<_ProjectsStudioView> {
  static const projectTypes = <String>[
    'Novel',
    'Memoir',
    'Short Story',
    'Screenplay',
  ];

  late final ProjectRosterStore rosterStore;

  List<ProjectRosterEntry> roster = const [];
  List<WritingSeries> seriesList = const [];

  /// Words already written per project, read without writing anything.
  Map<String, int> wordCounts = const {};

  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    rosterStore = widget.rosterStore ?? const ProjectRosterStore();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final entries = await rosterStore.load();
      final allSeries = await rosterStore.allSeries();
      final counts = <String, int>{};
      for (final entry in entries) {
        // peekStudio, never loadStudio: listing projects must not bring
        // manuscripts into existence for the ones never opened.
        final manuscript =
            await widget.manuscriptStore.peekStudio(entry.projectId);
        counts[entry.projectId] = manuscript?.wordCount ?? 0;
      }
      if (!mounted) return;
      setState(() {
        roster = entries;
        seriesList = allSeries;
        wordCounts = counts;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = 'Projects could not be loaded: $error';
        loading = false;
      });
    }
  }

  List<ProjectRosterEntry> _standaloneProjects() =>
      roster.where((entry) => !entry.isBook).toList();

  List<ProjectRosterEntry> _booksOf(String seriesId) {
    final books =
        roster.where((entry) => entry.seriesId == seriesId).toList()
          ..sort((a, b) =>
              (a.seriesPosition ?? 0).compareTo(b.seriesPosition ?? 0));
    return books;
  }

  Future<void> _createProject() async {
    final created = await showDialog<_NewProjectResult>(
      context: context,
      builder: (context) => _NewProjectDialog(series: seriesList),
    );
    if (created == null || !mounted) return;

    final project = StarterProject(
      id: 'project_${DateTime.now().microsecondsSinceEpoch}',
      title: created.title,
      genre: created.genre,
      projectType: created.projectType,
      wordGoal: created.wordGoal,
      acts: const [],
      chapters: const [],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );
    await rosterStore.save(project);
    final seriesId = created.seriesId;
    if (seriesId != null) {
      await rosterStore.addBookToSeries(
        projectId: project.id,
        seriesId: seriesId,
      );
    }
    await _load();
  }

  Future<void> _createSeries() async {
    final created = await showDialog<WritingSeries>(
      context: context,
      builder: (context) => const _NewSeriesDialog(),
    );
    if (created == null || !mounted) return;
    await rosterStore.saveSeries(created);
    await _load();
  }

  Future<void> _openProject(ProjectRosterEntry entry) async {
    // The shell owns which project is open; this view only asks.
    widget.onProjectChanged?.call(entry.project);
  }

  Future<void> _assignToSeries(ProjectRosterEntry entry) async {
    if (seriesList.isEmpty) return;
    final seriesId = await showDialog<String>(
      context: context,
      builder: (context) => _PickSeriesDialog(series: seriesList),
    );
    if (seriesId == null || !mounted) return;
    await rosterStore.addBookToSeries(
      projectId: entry.projectId,
      seriesId: seriesId,
    );
    await _load();
  }

  Future<void> _removeFromSeries(ProjectRosterEntry entry) async {
    await rosterStore.removeBookFromSeries(entry.projectId);
    await _load();
  }

  Future<void> _move(ProjectRosterEntry entry, int delta) async {
    final seriesId = entry.seriesId;
    if (seriesId == null) return;
    final books = _booksOf(seriesId).map((book) => book.projectId).toList();
    final index = books.indexOf(entry.projectId);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= books.length) return;
    books
      ..removeAt(index)
      ..insert(target, entry.projectId);
    await rosterStore.reorderBooks(seriesId, books);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) {
      return const Padding(
        key: Key('projects-loading'),
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = loadError;
    if (error != null) {
      return Column(
        key: const Key('projects-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    return Column(
      key: const Key('projects-studio'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Projects',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Every book you are writing, and the series they belong '
                    'to.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              key: const Key('projects-series-new'),
              onPressed: _createSeries,
              icon: const Icon(Icons.collections_bookmark_outlined, size: 18),
              label: const Text('New series'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('projects-new'),
              onPressed: _createProject,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New project'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (roster.isEmpty)
          Container(
            key: const Key('projects-empty'),
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              'No projects yet. Create one to start writing, and group several '
              'into a series to track them together.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (final series in seriesList) ...[
          _SeriesGroup(
            key: Key('projects-series-${series.id}'),
            series: series,
            books: _booksOf(series.id),
            activeProjectId: widget.activeProjectId,
            wordCounts: wordCounts,
            onOpen: _openProject,
            onRemoveFromSeries: _removeFromSeries,
            onMove: _move,
          ),
          const SizedBox(height: 18),
        ],
        if (_standaloneProjects().isNotEmpty) ...[
          Text(
            'Standalone projects',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Column(
            key: const Key('projects-roster'),
            children: [
              for (final entry in _standaloneProjects()) ...[
                _ProjectTile(
                  entry: entry,
                  isActive: entry.projectId == widget.activeProjectId,
                  wordCount: wordCounts[entry.projectId] ?? 0,
                  onOpen: () => _openProject(entry),
                  onAssign:
                      seriesList.isEmpty ? null : () => _assignToSeries(entry),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One series and its books, in reading order.
class _SeriesGroup extends StatelessWidget {
  const _SeriesGroup({
    super.key,
    required this.series,
    required this.books,
    required this.activeProjectId,
    required this.wordCounts,
    required this.onOpen,
    required this.onRemoveFromSeries,
    required this.onMove,
  });

  final WritingSeries series;
  final List<ProjectRosterEntry> books;
  final String activeProjectId;
  final Map<String, int> wordCounts;
  final Future<void> Function(ProjectRosterEntry) onOpen;
  final Future<void> Function(ProjectRosterEntry) onRemoveFromSeries;
  final Future<void> Function(ProjectRosterEntry, int) onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  series.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${books.length} ${books.length == 1 ? 'book' : 'books'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (books.isEmpty)
            Text(
              'No books in this series yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final book in books) ...[
              _ProjectTile(
                entry: book,
                isActive: book.projectId == activeProjectId,
                wordCount: wordCounts[book.projectId] ?? 0,
                onOpen: () => onOpen(book),
                onUnassign: () => onRemoveFromSeries(book),
                onMoveUp: book == books.first ? null : () => onMove(book, -1),
                onMoveDown: book == books.last ? null : () => onMove(book, 1),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// One project in the list.
class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.entry,
    required this.isActive,
    required this.wordCount,
    required this.onOpen,
    this.onAssign,
    this.onUnassign,
    this.onMoveUp,
    this.onMoveDown,
  });

  final ProjectRosterEntry entry;
  final bool isActive;
  final int wordCount;
  final VoidCallback onOpen;
  final VoidCallback? onAssign;
  final VoidCallback? onUnassign;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = entry.targetWords;
    return Container(
      key: Key('projects-roster-entry-${entry.projectId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          if (entry.bookNumber != null) ...[
            Text(
              'BOOK ${entry.bookNumber}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: Key('projects-active-badge-${entry.projectId}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Open',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  target > 0
                      ? '${formatWorldBoardCount(wordCount)} / '
                          '${formatWorldBoardCount(target)} words'
                      : '${formatWorldBoardCount(wordCount)} words · '
                          'no word goal',
                  key: Key('projects-words-${entry.projectId}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onMoveUp != null || onMoveDown != null) ...[
            IconButton(
              key: Key('projects-series-move-up-${entry.projectId}'),
              onPressed: onMoveUp,
              icon: const Icon(Icons.arrow_upward, size: 18),
              tooltip: 'Move earlier',
            ),
            IconButton(
              key: Key('projects-series-move-down-${entry.projectId}'),
              onPressed: onMoveDown,
              icon: const Icon(Icons.arrow_downward, size: 18),
              tooltip: 'Move later',
            ),
          ],
          if (onAssign != null)
            TextButton(
              key: Key('projects-assign-${entry.projectId}'),
              onPressed: onAssign,
              child: const Text('Add to series'),
            ),
          if (onUnassign != null)
            TextButton(
              key: Key('projects-unassign-${entry.projectId}'),
              onPressed: onUnassign,
              child: const Text('Remove'),
            ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            key: Key('projects-open-${entry.projectId}'),
            onPressed: isActive ? null : onOpen,
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

/// What the new-project dialog hands back.
class _NewProjectResult {
  const _NewProjectResult({
    required this.title,
    required this.genre,
    required this.projectType,
    required this.wordGoal,
    this.seriesId,
  });

  final String title;
  final String genre;
  final String projectType;
  final int wordGoal;
  final String? seriesId;
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog({required this.series});

  final List<WritingSeries> series;

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final genreController = TextEditingController(text: 'Fantasy');
  final goalController = TextEditingController(text: '80000');

  String projectType = _ProjectsStudioViewState.projectTypes.first;
  String? seriesId;

  /// True until the author edits the goal themselves, so choosing a series can
  /// still seed the field but never overwrite a number they typed.
  bool goalUntouched = true;

  @override
  void initState() {
    super.initState();
    goalController.addListener(() {
      if (goalController.text != '80000') goalUntouched = false;
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    genreController.dispose();
    goalController.dispose();
    super.dispose();
  }

  void _pickSeries(String? id) {
    setState(() {
      seriesId = id;
      if (!goalUntouched || id == null) return;
      final series =
          widget.series.where((entry) => entry.id == id).firstOrNull;
      if (series != null && series.hasDefaultTarget) {
        goalController.text = '${series.defaultTargetWords}';
      }
    });
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _NewProjectResult(
        title: titleController.text.trim(),
        genre: genreController.text.trim().isEmpty
            ? 'Fantasy'
            : genreController.text.trim(),
        projectType: projectType,
        wordGoal: int.parse(goalController.text.trim()),
        seriesId: seriesId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('projects-new-dialog'),
      title: const Text('New project'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('projects-new-title-field'),
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Give the project a title.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('projects-new-genre-field'),
                controller: genreController,
                decoration: const InputDecoration(
                  labelText: 'Genre',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('projects-new-type-field'),
                initialValue: projectType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in _ProjectsStudioViewState.projectTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) => setState(
                  () => projectType = value ?? projectType,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('projects-new-goal-field'),
                controller: goalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Word goal',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null) {
                    return 'Enter a whole number of words.';
                  }
                  if (parsed < 0) return 'A goal cannot be negative.';
                  return null;
                },
              ),
              if (widget.series.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: const Key('projects-new-series-field'),
                  initialValue: seriesId,
                  decoration: const InputDecoration(
                    labelText: 'Series (optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Standalone'),
                    ),
                    for (final series in widget.series)
                      DropdownMenuItem<String?>(
                        value: series.id,
                        child: Text(series.name),
                      ),
                  ],
                  onChanged: _pickSeries,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('projects-new-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('projects-new-save'),
          onPressed: _save,
          child: const Text('Create project'),
        ),
      ],
    );
  }
}

class _NewSeriesDialog extends StatefulWidget {
  const _NewSeriesDialog();

  @override
  State<_NewSeriesDialog> createState() => _NewSeriesDialogState();
}

class _NewSeriesDialogState extends State<_NewSeriesDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final goalController = TextEditingController(
    text: '${WritingSeries.defaultTargetWordsSeed}',
  );

  @override
  void dispose() {
    nameController.dispose();
    goalController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      WritingSeries(
        id: WritingSeriesId.create(),
        name: nameController.text.trim(),
        defaultTargetWords: int.parse(goalController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('projects-series-dialog'),
      title: const Text('New series'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('projects-series-name-field'),
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Series name',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Give the series a name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('projects-series-goal-field'),
                controller: goalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Default word goal per book',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null) {
                    return 'Enter a whole number of words.';
                  }
                  if (parsed < 0) return 'A goal cannot be negative.';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'A new book starts from this goal. Each book keeps its own '
                'target afterwards, so book five can be longer than book one.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('projects-series-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('projects-series-save'),
          onPressed: _save,
          child: const Text('Create series'),
        ),
      ],
    );
  }
}

class _PickSeriesDialog extends StatelessWidget {
  const _PickSeriesDialog({required this.series});

  final List<WritingSeries> series;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      key: const Key('projects-pick-series-dialog'),
      title: const Text('Add to series'),
      children: [
        for (final entry in series)
          SimpleDialogOption(
            key: Key('projects-pick-series-${entry.id}'),
            onPressed: () => Navigator.of(context).pop(entry.id),
            child: Text(entry.name),
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
                          child: LocalImage(
                            path: profile.avatarPath,
                            width: 62,
                            height: 62,
                            fallback: Container(
                              alignment: Alignment.center,
                              color: theme.colorScheme.primaryContainer,
                              child: Text(
                                profile.initials,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                ),
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
