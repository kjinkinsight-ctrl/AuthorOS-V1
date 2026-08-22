import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/navigation/authoros_route.dart';
import 'package:author_studio_v1/navigation/authoros_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A URL is a promise to an author: the link they bookmarked today has to open
/// the same place next month. These tests hold both halves of that -- the slugs
/// themselves, and the parsing that has to survive whatever a browser hands
/// back.
void main() {
  group('section slugs', () {
    test('every section is addressable', () {
      for (final section in StudioSection.values) {
        expect(section.slug, isNotEmpty,
            reason: '${section.name} has no address');
      }
    });

    test('no two sections share an address', () {
      final slugs = StudioSection.values.map((s) => s.slug).toList();
      expect(slugs.toSet(), hasLength(slugs.length));
    });

    test('slugs are URL-safe and stable in shape', () {
      final safe = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
      for (final section in StudioSection.values) {
        expect(safe.hasMatch(section.slug), isTrue,
            reason: '${section.slug} would need escaping in a URL');
      }
    });

    test('a slug round-trips back to its section', () {
      for (final section in StudioSection.values) {
        expect(studioSectionForSlug(section.slug), section);
      }
    });

    test('an unknown slug resolves to no section rather than throwing', () {
      expect(studioSectionForSlug('nonsense'), isNull);
      expect(studioSectionForSlug(''), isNull);
    });
  });

  group('AuthorOsRoute', () {
    test('the root is the startup gate', () {
      expect(const AuthorOsRoute.startup().location, '/');
      expect(AuthorOsRoute.fromLocation('/').isStartup, isTrue);
      expect(AuthorOsRoute.fromLocation('').isStartup, isTrue);
      expect(AuthorOsRoute.fromLocation(null).isStartup, isTrue);
    });

    test('a section path resolves to that section', () {
      expect(
        AuthorOsRoute.fromLocation('/manuscript').section,
        StudioSection.manuscript,
      );
      expect(
        AuthorOsRoute.fromLocation('/story-codex').section,
        StudioSection.codex,
      );
      expect(
        AuthorOsRoute.fromLocation('/world-board').section,
        StudioSection.worldBoard,
      );
    });

    test('a route round-trips through its own location', () {
      for (final section in StudioSection.values) {
        final route = AuthorOsRoute.section(section);
        expect(AuthorOsRoute.fromLocation(route.location), route);
      }
    });

    test('query strings and fragments are not part of the address', () {
      // Analytics tags and anchors ride along on shared links; they must not
      // turn a valid section into an unknown one.
      expect(
        AuthorOsRoute.fromLocation('/timeline?utm_source=newsletter').section,
        StudioSection.timeline,
      );
      expect(
        AuthorOsRoute.fromLocation('/timeline#act-two').section,
        StudioSection.timeline,
      );
    });

    test('a trailing slash addresses the same section', () {
      expect(
        AuthorOsRoute.fromLocation('/plot/').section,
        StudioSection.plot,
      );
    });

    test('an unknown or deeper path opens AuthorOS rather than failing', () {
      // A stale bookmark from an older build, or a hand-typed guess, should
      // land the author in the app -- not on an error, and not on a section
      // they did not ask for and cannot explain.
      expect(AuthorOsRoute.fromLocation('/nonsense').isStartup, isTrue);
      expect(
        AuthorOsRoute.fromLocation('/manuscript/chapter/3').isStartup,
        isTrue,
      );
    });

    test('routes compare by the place they name', () {
      expect(
        const AuthorOsRoute.section(StudioSection.plot),
        const AuthorOsRoute.section(StudioSection.plot),
      );
      expect(
        const AuthorOsRoute.section(StudioSection.plot),
        isNot(const AuthorOsRoute.section(StudioSection.notes)),
      );
      expect(
        const AuthorOsRoute.startup(),
        isNot(const AuthorOsRoute.section(StudioSection.dashboard)),
      );
    });
  });

  group('AuthorOsRouteParser', () {
    const parser = AuthorOsRouteParser();

    test('reads a route out of what the browser reports', () async {
      final route = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/characters')),
      );
      expect(route.section, StudioSection.characters);
    });

    test('writes a route back for the address bar', () {
      final information = parser.restoreRouteInformation(
        const AuthorOsRoute.section(StudioSection.analytics),
      );
      expect(information?.uri.toString(), '/analytics');
    });

    test('the startup gate restores as the bare root', () {
      final information =
          parser.restoreRouteInformation(const AuthorOsRoute.startup());
      expect(information?.uri.toString(), '/');
    });
  });

  group('AuthorOsRouterDelegate', () {
    AuthorOsRouterDelegate delegate() => AuthorOsRouterDelegate(
          builder: (_, __) => const SizedBox.shrink(),
        );

    test('starts at the gate with nothing pending', () {
      final router = delegate();
      expect(router.currentConfiguration.isStartup, isTrue);
      expect(router.section, isNull);
      expect(router.pendingSection, isNull);
    });

    test('a section chosen in the app becomes the current address', () {
      final router = delegate();
      var notified = 0;
      router.addListener(() => notified++);

      router.goToSection(StudioSection.timeline);

      expect(router.currentConfiguration.location, '/timeline');
      expect(router.section, StudioSection.timeline);
      expect(notified, 1, reason: 'the Router has to hear about it to push history');
    });

    test('re-choosing the current section adds no history entry', () {
      // Otherwise clicking the section you are already in stacks duplicates,
      // and browser back appears to do nothing.
      final router = delegate();
      router.goToSection(StudioSection.plot);

      var notified = 0;
      router.addListener(() => notified++);
      router.goToSection(StudioSection.plot);

      expect(notified, 0);
    });

    test('a deep link is remembered across the startup gate', () async {
      // The author opened /manuscript cold. They still have to sign in, and
      // the request has to outlive that.
      final router = delegate();
      await router.setNewRoutePath(
        const AuthorOsRoute.section(StudioSection.manuscript),
      );

      expect(router.pendingSection, StudioSection.manuscript);
    });

    test('leaving the workspace clears the address and the request', () {
      // Signing out must not leave a link straight back into the workspace.
      final router = delegate();
      router.goToSection(StudioSection.settings);

      router.returnToStartup();

      expect(router.currentConfiguration.isStartup, isTrue);
      expect(router.pendingSection, isNull);
    });

    test('leaving from the gate changes nothing', () {
      final router = delegate();
      var notified = 0;
      router.addListener(() => notified++);

      router.returnToStartup();

      expect(notified, 0);
    });
  });
}
