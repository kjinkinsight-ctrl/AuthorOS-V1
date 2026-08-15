import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/release_destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('premium palette uses richer dark and light color values', () {
    expect(AppThemePreset.byId('midnight').backgroundColor,
        const Color(0xFF0E1524));
    expect(
        AppThemePreset.byId('midnight').surfaceColor, const Color(0xFF1A2437));
    expect(
        AppThemePreset.byId('midnight').accentColor, const Color(0xFF8AA7D9));
    expect(
        AppThemePreset.byId('paper').backgroundColor, const Color(0xFFEDE2D5));
    expect(AppThemePreset.byId('paper').surfaceColor, const Color(0xFFF8F3EC));
    expect(AppThemePreset.byId('paper').accentColor, const Color(0xFFB87A46));
  });

  testWidgets('theme settings exposes palette choices and can change selection',
      (tester) async {
    String? pickedTheme;
    String? pickedAccent;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'obsidian',
          accentId: 'default',
          onThemeChanged: (themeId, accentId) {
            pickedTheme = themeId;
            pickedAccent = accentId;
          },
        ),
      ),
    );

    expect(find.text('Obsidian'), findsOneWidget);
    expect(find.text('Midnight'), findsOneWidget);
    expect(find.text('Paper'), findsOneWidget);

    final midnightFinder = find.text('Midnight');
    await tester.ensureVisible(midnightFinder);
    await tester.tap(midnightFinder);
    await tester.pumpAndSettle();

    expect(pickedTheme, 'midnight');
    expect(pickedAccent, 'default');
  });

  testWidgets('accent selection updates the selected accent value',
      (tester) async {
    String? pickedTheme;
    String? pickedAccent;

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'paper',
          accentId: 'default',
          onThemeChanged: (themeId, accentId) {
            pickedTheme = themeId;
            pickedAccent = accentId;
          },
        ),
      ),
    );

    final tealFinder = find.text('Teal');
    await tester.ensureVisible(tealFinder);
    await tester.tap(tealFinder);
    await tester.pumpAndSettle();

    expect(pickedTheme, 'paper');
    expect(pickedAccent, 'teal');
  });

  testWidgets('account security is exposed via a dedicated settings page',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'author_studio.profile.name': 'Elara West',
      'author_studio.profile.focus': 'Literary fantasy and mythic fiction',
      'author_studio.profile.bio': 'A writer of folklore and found family.',
      'author_studio.profile.public': true,
      'author_studio.profile.require_reauth': true,
      'author_studio.profile.secure_sessions': true,
      'author_studio.profile.sync_alerts': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'obsidian',
          accentId: 'default',
          onThemeChanged: (_, __) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Account Security'), findsOneWidget);
    await tester.tap(find.text('Account Security'));
    await tester.pumpAndSettle();

    expect(find.text('Require re-auth for sensitive actions'), findsOneWidget);
    expect(find.text('Secure device sessions'), findsOneWidget);
  });

  testWidgets('saved starter projects remain available after startup checks',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'author_studio.starter_project':
          '{"id":"saved-project","title":"Hidden Draft","genre":"Fantasy","projectType":"Novel","wordGoal":80000,"acts":["Act I"],"chapters":[{"title":"Chapter 1","prompt":"Intro"}],"characterSheets":[{"name":"Hero","role":"Main"}],"beatChecklist":["Opening"],"firstSceneTitle":"Opening Scene"}',
      'author_studio.onboarding_complete': true,
    });

    const store = OnboardingStore();
    final loaded = await store.loadProject();

    expect(loaded, isNotNull);
    expect(loaded!.title, 'Hidden Draft');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('author_studio.onboarding_complete'), isTrue);
    expect(prefs.getString('author_studio.starter_project'), isNotNull);
  });
}
