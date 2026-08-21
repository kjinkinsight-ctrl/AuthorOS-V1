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
import 'navigation/authoros_router.dart';
import 'onboarding.dart';
import 'plot_service.dart';
import 'persistence/authoros_database.dart';
import 'platform/url_strategy.dart';
import 'release_destinations.dart';
import 'research_service.dart';
import 'research_studio_view.dart';
import 'startup_status.dart';
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

  // Real URL paths rather than hash routes, so `/manuscript` is what an author
  // sees, bookmarks, and shares. No-op off the web. See
  // `lib/platform/url_strategy.dart`.
  configureUrlStrategy();

  // A widget that throws while building would otherwise paint Flutter's grey
  // "red screen" replacement in release -- or, in a browser, nothing at all.
  // Authors get an AuthorOS surface instead. The framework has already logged
  // the real error by the time this runs, so nothing is hidden.
  ErrorWidget.builder = (details) => StartupFailureScreen(
        message: 'Something in AuthorOS stopped responding.',
        detail: details.exceptionAsString(),
        onRetry: _reloadApp,
        onReturnToStart: _reloadApp,
      );

  await AppSupabase.initialize();
  runApp(const AuthorStudioApp());
}

/// Rebuilds the application from scratch after a failure.
///
/// Nothing here is persistent state, so tearing the tree down and starting
/// again is enough to recover from a transient failure -- a database that was
/// not ready, a preference read that timed out -- without asking the author to
/// find the reload button themselves.
void _reloadApp() {
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

  /// Why the theme could not be read, if it could not.
  ///
  /// Reading the theme is the first thing AuthorOS does, and on the web it is
  /// the first thing that can fail for a reason the author did not cause --
  /// browser storage refused in a private window, for instance. Holding the
  /// error lets the app say so rather than sit on a loading screen.
  Object? _startupError;

  /// Where the author is, and what the address bar says.
  ///
  /// Created once and kept for the life of the app: recreating it would drop
  /// the current section and reset the URL on every theme change.
  late final AuthorOsRouterDelegate _routerDelegate;

  static const _routeParser = AuthorOsRouteParser();

  ThemeBrightness get _hostBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? ThemeBrightness.dark
          : ThemeBrightness.light;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routerDelegate = AuthorOsRouterDelegate(builder: _buildForRoute);
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
    try {
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
        _startupError = null;
        _loadingTheme = false;
      });
    } catch (error, stackTrace) {
      // Reported to the framework so it reaches the console and any crash
      // handler, then shown to the author as a workspace that would not open.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'AuthorOS startup',
          context: ErrorDescription('while loading the theme selection'),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _startupError = error;
        _loadingTheme = false;
      });
    }
  }

  /// Retries the theme load after a failure.
  void _retryStartup() {
    setState(() {
      _startupError = null;
      _loadingTheme = true;
    });
    unawaited(_loadThemeSelection());
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
    // One app, one Router, from the very first frame -- including while the
    // theme is still loading and if it fails.
    //
    // Showing a plain `MaterialApp` for those states looked harmless and was
    // not: a plain MaterialApp installs its own Navigator, which on the web
    // reports its `/` route to the browser and overwrites the address an author
    // arrived on. Opening `/plot` and refreshing landed back at `/`, which is
    // the whole feature failing quietly at the one moment it is needed.
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'AuthorOS',
      theme: _buildThemeData(),
      routerDelegate: _routerDelegate,
      routeInformationParser: _routeParser,
    );
  }

  /// Builds the application for whatever section the router is pointing at.
  ///
  /// The router decides *where*; this still decides *what an author in that
  /// state should see*, which is the same startup gate as before. A section in
  /// the URL does not skip signing in -- it is remembered through the gate and
  /// honoured once the workspace opens.
  Widget _buildForRoute(
    BuildContext context,
    AuthorOsRouterDelegate delegate,
  ) {
    final startupError = _startupError;
    if (startupError != null) {
      return StartupFailureScreen(
        detail: startupError.toString(),
        onRetry: _retryStartup,
        onReturnToStart: _retryStartup,
      );
    }

    if (_loadingTheme || _resolvedTheme == null || _themeSelection == null) {
      return const StartupLoadingScreen();
    }

    return StudioThemeScope(
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
        requestedSection: delegate.pendingSection,
        onSectionChanged: delegate.goToSection,
        onLeaveWorkspace: delegate.returnToStartup,
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
    this.requestedSection,
    this.onSectionChanged,
    this.onLeaveWorkspace,
  });

  /// The section the URL is asking for, if any.
  ///
  /// A cold load of `/manuscript` still has to pass the startup gate, so this
  /// survives sign-in and is handed to the shell when the workspace opens.
  /// Without it every deep link would resolve to the default section, which is
  /// the same as having no deep links at all.
  final StudioSection? requestedSection;

  /// Reports the section the author moved to, so the URL can follow.
  final ValueChanged<StudioSection>? onSectionChanged;

  /// Called when the author leaves the workspace, so the URL stops pointing
  /// into a workspace that is no longer open.
  final VoidCallback? onLeaveWorkspace;

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
      welcomeTarget = null;
      existingProfileName = storedName.isEmpty ? null : storedName;
      existingProfileEmail = storedEmail.isEmpty ? null : storedEmail;
    });
    // The address bar should stop pointing into a workspace that is no longer
    // open -- otherwise signing out leaves a link straight back into it.
    widget.onLeaveWorkspace?.call();
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
    final target = _sectionForWelcomeAction(action);
    setState(() {
      welcomeDismissed = true;
      welcomeTarget = target;
    });
    // Entering the workspace from the launcher is the first thing that gives
    // the author an address worth keeping, so the URL follows it too.
    widget.onSectionChanged?.call(target);
  }

  StudioSection _sectionForWelcomeAction(WelcomeAction action) =>
      switch (action) {
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const StartupLoadingScreen();
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

    // The welcome page is the authenticated landing page: it greets the author
    // who just signed in, then falls through to whichever step is still
    // outstanding -- the first project, or the studio itself.
    //
    // It is skipped when the URL already names a section. An author opening a
    // bookmark has said where they are going; greeting them and asking again
    // is the difference between a link that works and a link that merely gets
    // you into the app.
    if (widget.showWelcome &&
        !welcomeDismissed &&
        widget.requestedSection == null) {
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
      // Two things can name a section: the URL the author arrived on, and the
      // launcher button they pressed. The URL wins, because it is the more
      // recent statement of intent in every case that matters -- a pasted
      // link, a bookmark, browser back -- and the launcher's choice is written
      // to the URL the moment it is made, so the two agree from then on.
      initialSection: widget.requestedSection ?? welcomeTarget,
      onSectionChanged: widget.onSectionChanged,
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
  /// The section's address, the part of the URL after the origin.
  ///
  /// Written out rather than derived from [name] so that renaming an enum
  /// value, or reordering the enum, never silently invalidates a link an
  /// author has bookmarked or shared. A slug is a published contract; the
  /// Dart identifier beside it is not.
  String get slug => switch (this) {
        StudioSection.dashboard => 'dashboard',
        StudioSection.worldBoard => 'world-board',
        StudioSection.search => 'search',
        StudioSection.statistics => 'statistics',
        StudioSection.analytics => 'analytics',
        StudioSection.backup => 'backup',
        StudioSection.projects => 'projects',
        StudioSection.ideas => 'ideas',
        StudioSection.manuscript => 'manuscript',
        StudioSection.chapters => 'chapters',
        StudioSection.characters => 'characters',
        StudioSection.codex => 'story-codex',
        StudioSection.world => 'world',
        StudioSection.map => 'map',
        StudioSection.plot => 'plot',
        StudioSection.timeline => 'timeline',
        StudioSection.research => 'research',
        StudioSection.notes => 'notes',
        StudioSection.settings => 'settings',
      };

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

/// Finds the section a URL slug addresses, or null if it addresses nothing.
///
/// Unknown slugs are a normal thing to receive -- a stale bookmark, a typo, a
/// link from a build where the section had a different name -- so this reports
/// "no such section" rather than throwing, and callers decide where to send
/// the author instead.
StudioSection? studioSectionForSlug(String slug) {
  final normalized = slug.trim().toLowerCase();
  for (final section in StudioSection.values) {
    if (section.slug == normalized) {
      return section;
    }
  }
  return null;
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
    this.onSectionChanged,
  });

  final StarterProject project;
  final bool openFirstDraft;
  final bool startSprint;

  /// Section to show. Re-supplying a different one moves the shell there, so
  /// the URL can drive it; null keeps whatever the shell is already showing.
  final StudioSection? initialSection;

  /// Reports a section the author chose from the navigation.
  ///
  /// Null when nothing outside the shell cares -- a test driving it directly,
  /// for instance. When the router supplies it, this is what puts the section
  /// in the address bar and in browser history.
  final ValueChanged<StudioSection>? onSectionChanged;
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

/// How much room the shell has, and therefore which navigation it shows.
///
/// AuthorOS has one navigation architecture -- the sections in
/// [_AuthorStudioShellState.sections], drawn by [_NavigationGroup] and
/// [_NavigationTile]. This decides how much of it is on screen at once, not
/// what it contains.
enum ShellLayout {
  /// Full sidebar beside the workspace: labelled tiles, grouped, always
  /// visible. What a desktop window and a maximised browser get.
  expanded,

  /// The same tiles collapsed to an icon rail. Every section is still one
  /// click away and the workspace gets back the ~200px the labels were using.
  /// What a small laptop or a landscape tablet gets.
  rail,

  /// Navigation moves into a drawer behind a menu button in the top bar, so
  /// the workspace has the whole width. What a portrait tablet and anything
  /// narrower gets.
  drawer;

  /// Chooses the layout for a shell [width].
  ///
  /// The thresholds are derived from what the workspace needs rather than from
  /// device names. The sidebar occupies 312px including its margins and the
  /// rail 108px, and the workspace itself wants roughly 820px before its
  /// studios start crowding -- so the sidebar is affordable from 1180px, the
  /// rail from 820px, and below that neither is.
  static ShellLayout forWidth(double width) {
    if (width >= expandedBreakpoint) return ShellLayout.expanded;
    if (width >= railBreakpoint) return ShellLayout.rail;
    return ShellLayout.drawer;
  }

  static const double expandedBreakpoint = 1180;
  static const double railBreakpoint = 820;
}

class _AuthorStudioShellState extends State<AuthorStudioShell> {
  int selectedIndex = 0;
  bool focusModeEnabled = false;

  /// Opens the navigation drawer at widths where it is the only navigation.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    selectedIndex = _indexFor(widget.initialSection);
  }

  @override
  void didUpdateWidget(AuthorStudioShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The section can now change from outside -- browser back, a pasted URL, a
    // restored bookmark -- so the shell follows it rather than only reading it
    // once at startup.
    final requested = widget.initialSection;
    if (requested != null && requested != oldWidget.initialSection) {
      final index = sections.indexOf(requested);
      if (index >= 0 && index != selectedIndex) {
        setState(() => selectedIndex = index);
      }
    }
  }

  int _indexFor(StudioSection? section) {
    final index = sections.indexOf(section ?? StudioSection.manuscript);
    return index >= 0 ? index : sections.indexOf(StudioSection.manuscript);
  }

  void _selectSection(StudioSection section) {
    final index = sections.indexOf(section);
    if (index >= 0) {
      _selectIndex(index);
    }
  }

  /// Selects by index, tells whoever is listening, and closes the drawer if the
  /// choice came from inside it.
  void _selectIndex(int index, {bool fromDrawer = false}) {
    if (index != selectedIndex) {
      setState(() => selectedIndex = index);
      widget.onSectionChanged?.call(sections[index]);
    }
    if (fromDrawer && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
    }
  }

  void _toggleFocusMode() {
    setState(() => focusModeEnabled = !focusModeEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = ShellLayout.forWidth(constraints.maxWidth);
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

        // Only the drawer layout hangs navigation off the Scaffold; giving the
        // other two a drawer as well would put a menu button in a top bar that
        // already has the sidebar beside it.
        final usesDrawer = layout == ShellLayout.drawer;

        return Scaffold(
          key: _scaffoldKey,
          drawer: usesDrawer
              ? _NavigationDrawerPanel(
                  sections: sections,
                  selectedIndex: selectedIndex,
                  onSelected: (index) =>
                      _selectIndex(index, fromDrawer: true),
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (layout != ShellLayout.drawer)
                  _DesktopNavigation(
                    sections: sections,
                    selectedIndex: selectedIndex,
                    onSelected: _selectIndex,
                    collapsed: layout == ShellLayout.rail,
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
                          // Non-null only in the drawer layout, where the top
                          // bar is the only way back to the section list.
                          onOpenNavigation: usesDrawer
                              ? () => _scaffoldKey.currentState?.openDrawer()
                              : null,
                        ),
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.fromLTRB(
                              usesDrawer ? 0 : 12,
                              0,
                              0,
                              0,
                            ),
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
    this.onOpenNavigation,
  });

  final StudioSection section;
  final ValueChanged<StudioSection> onNavigate;
  final bool focusMode;
  final VoidCallback onToggleFocus;

  /// Opens the navigation drawer, in the one layout that has one.
  ///
  /// Null wherever the sidebar or the rail is already on screen, which is also
  /// what tells the bar it has the room for the full workspace heading.
  final VoidCallback? onOpenNavigation;

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

    // In the drawer layout the bar has to fit a menu button and the same five
    // actions into a phone-width row, so the logo and the tagline give up
    // their space to the section the author is actually in.
    final compact = onOpenNavigation != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 4 : 16, 18, 20, 12),
      child: Row(
        children: [
          if (onOpenNavigation != null)
            IconButton(
              key: const Key('open-navigation'),
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Open navigation',
              onPressed: onOpenNavigation,
            )
          else ...[
            const _AppMark(),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compact ? section.label : 'AuthorOS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (!compact)
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

/// The sidebar beside the workspace, in either of its two widths.
///
/// Collapsed, it is the same list of sections with the labels taken away
/// rather than a different navigation: identical order, identical grouping,
/// identical selection, and Settings still pinned at the foot. Each tile keeps
/// its label as a tooltip and as its accessible name, so nothing is lost to a
/// screen reader or to a pointer that hovers.
class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
    this.collapsed = false,
  });

  final List<StudioSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Whether to show the icon rail rather than the full labelled sidebar.
  final bool collapsed;

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
      width: collapsed ? 76 : 280,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: _NavigationBody(
        sections: sections,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        collapsed: collapsed,
      ),
    );
  }
}

/// The contents of the navigation, shared by the sidebar, the rail, and the
/// drawer.
///
/// Having one widget build all three is what keeps AuthorOS to a single
/// navigation: adding a section to [StudioSection] puts it in every layout at
/// once, in the same group and the same order, with Settings still pinned
/// below the scrolling groups.
class _NavigationBody extends StatelessWidget {
  const _NavigationBody({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
    this.collapsed = false,
  });

  final List<StudioSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final settingsIndex = sections.indexOf(StudioSection.settings);
    final padding = collapsed
        ? const EdgeInsets.fromLTRB(8, 0, 8, 12)
        : const EdgeInsets.fromLTRB(12, 0, 12, 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NavigationHeader(collapsed: collapsed),
        Expanded(
          child: ListView(
            padding: padding,
            children: [
              _NavigationGroup(
                label: 'WORKSPACE',
                items: _DesktopNavigation.workspaceSections,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                sections: sections,
                collapsed: collapsed,
              ),
              const SizedBox(height: 16),
              _NavigationGroup(
                label: 'STORY',
                items: _DesktopNavigation.storySections,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                sections: sections,
                collapsed: collapsed,
              ),
            ],
          ),
        ),
        // Settings is pinned below the scrolling groups so it stays
        // reachable however many Studios the workspace grows to hold.
        Padding(
          padding: padding,
          child: _NavigationTile(
            section: StudioSection.settings,
            isSelected: selectedIndex == settingsIndex,
            onTap: () => onSelected(settingsIndex),
            collapsed: collapsed,
          ),
        ),
      ],
    );
  }
}

/// The AuthorOS mark at the top of the navigation, in either width.
///
/// Collapsed there is no room for the wordmark, so the monogram carries the
/// identity and the full name moves into its tooltip.
class _NavigationHeader extends StatelessWidget {
  const _NavigationHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 14),
        child: Center(
          child: Tooltip(
            message: 'AuthorOS workspace',
            child: Text(
              'A',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
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
    );
  }
}

/// Navigation for the narrowest layout, where the workspace needs the whole
/// width and the sections live behind the top bar's menu button.
class _NavigationDrawerPanel extends StatelessWidget {
  const _NavigationDrawerPanel({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<StudioSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: _NavigationBody(
          sections: sections,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
        ),
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
    this.collapsed = false,
  });

  final String label;
  final List<StudioSection> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<StudioSection> sections;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsed, the group heading would not fit and would only repeat
        // what the rule already says, so a divider carries the grouping.
        if (collapsed)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant,
            ),
          )
        else
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
            collapsed: collapsed,
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
    this.collapsed = false,
  });

  final StudioSection section;
  final bool isSelected;
  final VoidCallback onTap;

  /// Whether to draw the icon alone, with the label moved into a tooltip.
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          // Without this a keyboard user tabbing the rail has no idea which
          // section they are on, since the icon alone carries no focus cue.
          focusColor: theme.colorScheme.primary.withValues(alpha: 0.18),
          child: Padding(
            padding: collapsed
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 11)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(section.icon, color: foreground),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.label,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!collapsed) {
      return tile;
    }

    // The label is the only thing the rail drops, so it is put back twice: as
    // a tooltip for a pointer, and as the accessible name for anything reading
    // the tree, which would otherwise announce an unnamed button.
    return Tooltip(
      message: section.label,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        label: section.label,
        selected: isSelected,
        button: true,
        child: tile,
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
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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
                  child: LocalImage(
                    path: avatarPath,
                    width: 72,
                    height: 72,
                    fallback: Container(
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
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authorBio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
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
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              templateStarterText(selectedProject!.template),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
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
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
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
