/// The two things AuthorOS can be doing before the workspace appears: opening,
/// or explaining why it could not.
///
/// Both are drawn on the same doorway artwork, in the same dark palette, with
/// the same gold ornament as the login and profile screens, so an author moving
/// between them never crosses a visual seam. The HTML startup screen in
/// `web/index.html` restates the same composition for the seconds before any
/// Dart is running; between the three of them the opening of AuthorOS reads as
/// one continuous place rather than a relay of loading screens.
library;

import 'package:flutter/material.dart';

import 'startup_backdrop.dart';

/// Shown while AuthorOS is reading the author's theme and workspace.
///
/// This is deliberately not a bare spinner on a default background. On the web
/// it takes over from the HTML startup screen at the exact moment Flutter
/// paints its first frame, and a grey Material scaffold appearing there would
/// undo the handoff the browser side works to make invisible.
class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({
    super.key,
    this.message = 'Opening your workspace…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);

    return StartupBackdrop(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StartupWordmark(eyebrow: 'Welcome to'),
            const SizedBox(height: 22),
            const StartupOrnament(),
            const SizedBox(height: 22),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.onSurface.withValues(alpha: 0.72),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                color: palette.gold,
                backgroundColor: palette.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when AuthorOS cannot open the workspace.
///
/// The author is told what happened in a sentence and given two ways forward.
/// The underlying exception is not swallowed: it stays available behind
/// "Technical details" and is reported to the framework's error handlers, so a
/// graceful surface never costs the diagnosis.
class StartupFailureScreen extends StatefulWidget {
  const StartupFailureScreen({
    super.key,
    required this.onRetry,
    required this.onReturnToStart,
    this.message =
        'We couldn’t open your workspace. Your writing is safe — it '
        'stays on this device.',
    this.detail,
  });

  /// Tries the failed step again, without discarding anything.
  final VoidCallback onRetry;

  /// Goes back to the opening screen, the way out when a retry keeps failing.
  final VoidCallback onReturnToStart;

  final String message;

  /// The developer-facing exception text, if there is one to show.
  final String? detail;

  @override
  State<StartupFailureScreen> createState() => _StartupFailureScreenState();
}

class _StartupFailureScreenState extends State<StartupFailureScreen> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);
    final diagnostic = widget.detail?.trim();
    final muted = palette.onSurface.withValues(alpha: 0.45);

    return StartupBackdrop(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StartupWordmark(eyebrow: 'Welcome to'),
          const SizedBox(height: 22),
          const StartupOrnament(),
          const SizedBox(height: 22),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.onSurface.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          StartupButton(
            key: const Key('startup-retry'),
            label: 'Try Again',
            emphasised: true,
            onPressed: widget.onRetry,
          ),
          const SizedBox(height: 10),
          StartupButton(
            key: const Key('startup-return-to-start'),
            label: 'Return to Start',
            onPressed: widget.onReturnToStart,
          ),
          if (diagnostic != null && diagnostic.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('startup-failure-details'),
                onPressed: () => setState(() => _showDetail = !_showDetail),
                icon: Icon(
                  _showDetail
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: muted,
                ),
                label: Text(
                  'Technical details',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ),
            if (_showDetail)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.panel,
                  border: Border.all(color: palette.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  diagnostic,
                  style: TextStyle(
                    color: palette.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The AuthorOS wordmark as the startup screens set it.
///
/// Extracted so the loading screen, the failure screen, and the login screen
/// all render the name identically rather than each restating the type.
class StartupWordmark extends StatelessWidget {
  const StartupWordmark({super.key, this.eyebrow});

  /// The small line above the name, e.g. "Welcome back to".
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);
    final above = eyebrow;

    return Column(
      children: [
        if (above != null)
          Text(
            above,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 17,
              color: palette.gold.withValues(alpha: 0.85),
            ),
          ),
        const SizedBox(height: 2),
        Text(
          'AuthorOS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: palette.gold,
          ),
        ),
      ],
    );
  }
}
