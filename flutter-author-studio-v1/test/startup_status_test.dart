import 'package:author_studio_v1/startup_backdrop.dart';
import 'package:author_studio_v1/startup_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opening AuthorOS in a browser can fail for reasons the author did not cause
/// and cannot see -- storage refused in a private window, a bundle that never
/// arrived. What they must never get is a blank page or a raw exception. These
/// tests hold that line, and hold the other half of the bargain too: the real
/// error stays available to whoever has to diagnose it.
void main() {
  Widget host(Widget child) => MaterialApp(home: child);

  group('StartupLoadingScreen', () {
    testWidgets('opens on the AuthorOS startup artwork, not a bare spinner',
        (tester) async {
      await tester.pumpWidget(host(const StartupLoadingScreen()));
      await tester.pump();

      expect(find.byType(StartupBackdrop), findsOneWidget);
      expect(find.text('AuthorOS'), findsOneWidget);
      expect(find.byType(StartupOrnament), findsOneWidget);
      expect(find.text('Opening your workspace…'), findsOneWidget);
    });

    testWidgets('announces itself to assistive technology', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const StartupLoadingScreen()));
      await tester.pump();

      // The panel is one live region, so a screen reader reads the whole
      // opening -- name and status together -- rather than announcing a
      // detached fragment.
      final node = tester.getSemantics(find.text('Opening your workspace…'));
      expect(node.label, contains('Opening your workspace…'));
      expect(node.label, contains('AuthorOS'));
      handle.dispose();
    });
  });

  group('StartupFailureScreen', () {
    testWidgets('says what happened and offers both ways forward',
        (tester) async {
      await tester.pumpWidget(host(
        StartupFailureScreen(onRetry: () {}, onReturnToStart: () {}),
      ));
      await tester.pump();

      expect(find.byType(StartupBackdrop), findsOneWidget);
      expect(find.text('AuthorOS'), findsOneWidget);
      expect(
        find.textContaining('We couldn’t open your workspace'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('startup-retry')), findsOneWidget);
      expect(find.byKey(const Key('startup-return-to-start')), findsOneWidget);
    });

    testWidgets('never shows raw exception text as the visible message',
        (tester) async {
      await tester.pumpWidget(host(
        StartupFailureScreen(
          detail: 'DatabaseException: unable to open database file (code 14)',
          onRetry: () {},
          onReturnToStart: () {},
        ),
      ));
      await tester.pump();

      // Collapsed by default: an author sees a sentence, not a stack trace.
      expect(find.textContaining('DatabaseException'), findsNothing);
      expect(find.text('Technical details'), findsOneWidget);
    });

    testWidgets('keeps the real error one tap away for diagnosis',
        (tester) async {
      await tester.pumpWidget(host(
        StartupFailureScreen(
          detail: 'DatabaseException: unable to open database file (code 14)',
          onRetry: () {},
          onReturnToStart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('startup-failure-details')));
      await tester.pumpAndSettle();

      expect(find.textContaining('DatabaseException'), findsOneWidget);
    });

    testWidgets('omits the details panel when there is nothing to show',
        (tester) async {
      await tester.pumpWidget(host(
        StartupFailureScreen(onRetry: () {}, onReturnToStart: () {}),
      ));
      await tester.pump();

      expect(find.text('Technical details'), findsNothing);
    });

    testWidgets('both actions are reachable and fire', (tester) async {
      var retried = 0;
      var returned = 0;
      await tester.pumpWidget(host(
        StartupFailureScreen(
          onRetry: () => retried++,
          onReturnToStart: () => returned++,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('startup-retry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('startup-return-to-start')));
      await tester.pumpAndSettle();

      expect(retried, 1);
      expect(returned, 1);
    });
  });

  group('StartupWordmark', () {
    testWidgets('sets the name the same way every startup screen does',
        (tester) async {
      await tester.pumpWidget(host(
        const StartupBackdrop(child: StartupWordmark(eyebrow: 'Welcome to')),
      ));
      await tester.pump();

      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.text('AuthorOS'), findsOneWidget);

      final wordmark = tester.widget<Text>(find.text('AuthorOS'));
      expect(wordmark.style?.fontFamily, 'Merriweather');
    });

    testWidgets('drops the eyebrow line when there is nothing above the name',
        (tester) async {
      await tester.pumpWidget(host(
        const StartupBackdrop(child: StartupWordmark()),
      ));
      await tester.pump();

      expect(find.text('AuthorOS'), findsOneWidget);
      expect(find.text('Welcome to'), findsNothing);
    });
  });
}
