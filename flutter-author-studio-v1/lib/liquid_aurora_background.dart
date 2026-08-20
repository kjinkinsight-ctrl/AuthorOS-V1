import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Test seam in the spirit of Flutter's own `debugDisable*` switches.
///
/// The aurora drives an endless ticker, which leaves `pumpAndSettle` waiting
/// for a frame that never stops coming. Widget tests flip this to `true` so
/// the background paints one static frame instead.
bool debugDisableAuroraAnimation = false;

/// Frame the aurora rests on when its motion is switched off.
const double _restingFrame = 0.32;

/// One morphing blob of the aurora.
@immutable
class AuroraBlob {
  const AuroraBlob({
    required this.color,
    required this.alignment,
    required this.diameter,
    required this.cycles,
    this.phase = 0,
  }) : assert(cycles > 0, 'A blob must complete at least one cycle.');

  /// Core colour, faded towards transparent at the blob's rim.
  final Color color;

  /// Where the blob sits relative to the painted area. Values beyond the
  /// -1..1 box are intentional: half-offscreen blobs read as a wash of light
  /// rather than a recognisable shape.
  final Alignment alignment;

  /// Blob width and height as a fraction of the shortest screen edge.
  final double diameter;

  /// Whole morph cycles per master period. Whole numbers keep the loop
  /// seamless when the shared controller wraps back to zero.
  final int cycles;

  /// Offset into the cycle, in turns, so the blobs never move in lockstep.
  final double phase;
}

const List<AuroraBlob> _defaultBlobs = <AuroraBlob>[
  AuroraBlob(
    color: Color(0xFF6C4BF6),
    alignment: Alignment(-0.85, -0.7),
    diameter: 0.95,
    cycles: 3,
  ),
  AuroraBlob(
    color: Color(0xFF17B8C4),
    alignment: Alignment(0.9, -0.2),
    diameter: 0.8,
    cycles: 4,
    phase: 0.35,
  ),
  AuroraBlob(
    color: Color(0xFFD4AF37),
    alignment: Alignment(-0.15, 0.95),
    diameter: 0.85,
    cycles: 2,
    phase: 0.7,
  ),
];

/// A slow field of blurred, morphing colour used as a full-bleed backdrop.
///
/// Each blob rotates a full turn, breathes between 1.0 and 1.1 scale, and
/// melts between two asymmetric corner-radius sets, all behind a heavy blur.
/// Motion stops when the platform asks for reduced animation.
class LiquidAuroraBackground extends StatefulWidget {
  const LiquidAuroraBackground({
    super.key,
    this.blobs = _defaultBlobs,
    this.baseColor = const Color(0xFF070A16),
    this.blurSigma = 64,
    this.period = const Duration(seconds: 60),
    this.child,
  });

  final List<AuroraBlob> blobs;

  /// Painted under the blobs so the blur never composites onto nothing, and
  /// so light text stays legible wherever the aurora thins out.
  final Color baseColor;

  final double blurSigma;

  /// Master loop. Every blob divides it by its own `cycles`.
  final Duration period;

  /// Painted over the aurora, if the caller wants content in the same widget.
  final Widget? child;

  @override
  State<LiquidAuroraBackground> createState() => _LiquidAuroraBackgroundState();
}

class _LiquidAuroraBackgroundState extends State<LiquidAuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
    value: _restingFrame,
  );

  bool get _shouldAnimate =>
      !debugDisableAuroraAnimation &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(LiquidAuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _controller.duration = widget.period;
      if (_controller.isAnimating) _controller.repeat();
    }
  }

  void _syncTicker() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
      _controller.value = _restingFrame;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: widget.baseColor),
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
              tileMode: TileMode.decal,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortestSide = constraints.biggest.shortestSide;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final blob in widget.blobs)
                        _MorphingBlob(
                          blob: blob,
                          extent: shortestSide * blob.diameter,
                          t: (_controller.value * blob.cycles + blob.phase) %
                              1.0,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _MorphingBlob extends StatelessWidget {
  const _MorphingBlob({
    required this.blob,
    required this.extent,
    required this.t,
  });

  final AuroraBlob blob;
  final double extent;

  /// Position within this blob's own cycle, 0..1.
  final double t;

  /// Corner radii at the start and end of a cycle, as fractions of the box.
  /// Taken from the CSS keyframes: `60% 40% 30% 70% / 60% 30% 70% 40%`.
  static BorderRadius _radiiA(double e) => BorderRadius.only(
        topLeft: Radius.elliptical(e * 0.60, e * 0.60),
        topRight: Radius.elliptical(e * 0.40, e * 0.30),
        bottomRight: Radius.elliptical(e * 0.30, e * 0.70),
        bottomLeft: Radius.elliptical(e * 0.70, e * 0.40),
      );

  /// The midpoint keyframe: `40% 60% 70% 30% / 40% 70% 30% 60%`.
  static BorderRadius _radiiB(double e) => BorderRadius.only(
        topLeft: Radius.elliptical(e * 0.40, e * 0.40),
        topRight: Radius.elliptical(e * 0.60, e * 0.70),
        bottomRight: Radius.elliptical(e * 0.70, e * 0.30),
        bottomLeft: Radius.elliptical(e * 0.30, e * 0.60),
      );

  @override
  Widget build(BuildContext context) {
    // 0 -> 1 -> 0 across the cycle, mirroring the CSS midpoint keyframe.
    final swell = math.sin(math.pi * t);

    return Align(
      alignment: blob.alignment,
      child: Transform.rotate(
        angle: t * 2 * math.pi,
        child: Transform.scale(
          scale: 1 + 0.1 * swell,
          child: Container(
            width: extent,
            height: extent,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.lerp(_radiiA(extent), _radiiB(extent), swell),
              gradient: RadialGradient(
                colors: [
                  blob.color.withValues(alpha: 0.85),
                  blob.color.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
