import 'package:flutter/material.dart';

import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_definition.dart';
import 'theme/theme_registry.dart';
import 'theme/theme_tokens.dart';

/// Artwork behind both startup screens: a doorway opening onto the AuthorOS
/// world. Shared so login and profile creation read as one place.
const AssetImage startupDoorway = AssetImage('assets/startup-doorway.png');

/// The dark palette the startup screens paint with.
///
/// Startup is deliberately fixed to the AuthorOS dark palette regardless of
/// the light/dark choice made in settings: the panels sit on a night-time
/// illustration, and a light wash over it would be unreadable. The values are
/// not invented here. They are read from the Theme Engine's registered dark
/// theme, or from the enclosing [StudioThemeScope] once the shell installs one.
class StartupPalette {
  const StartupPalette({
    required this.background,
    required this.panel,
    required this.gold,
    required this.onSurface,
    required this.outline,
    required this.focusRing,
  });

  final Color background;
  final Color panel;
  final Color gold;
  final Color onSurface;
  final Color outline;
  final Color focusRing;

  factory StartupPalette.of(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    if (scope != null) {
      return StartupPalette(
        background: scope.color(ThemeColorRef.background),
        panel: scope.color(ThemeColorRef.surface),
        gold: scope.color(ThemeColorRef.primary),
        onSurface: scope.color(ThemeColorRef.onSurface),
        outline: scope.color(ThemeColorRef.outlineVariant),
        focusRing: scope.color(ThemeColorRef.focusRing),
      );
    }
    return engineDark;
  }

  /// The Theme Engine's dark palette, used until the shell installs a scope.
  static final StartupPalette engineDark = _readEngineDark();

  static StartupPalette _readEngineDark() {
    final palette = ThemeRegistry.standard()
        .byId('dark')
        .palettes[ThemeBrightness.dark]!;
    Color read(ThemeColorRef ref) => AuthorOsTheme.color(palette[ref]);
    return StartupPalette(
      background: read(ThemeColorRef.background),
      panel: read(ThemeColorRef.surface),
      gold: read(ThemeColorRef.primary),
      onSurface: read(ThemeColorRef.onSurface),
      outline: read(ThemeColorRef.outlineVariant),
      focusRing: read(ThemeColorRef.focusRing),
    );
  }
}

/// Full-bleed doorway artwork with the startup panel laid over it.
///
/// The image is cover-fitted so it never stretches, and the panel column keeps
/// a fixed width until the window is too narrow to afford it, at which point it
/// takes the full width rather than squeezing to an unusable strip.
class StartupBackdrop extends StatelessWidget {
  const StartupBackdrop({
    super.key,
    required this.child,
    this.panelWidth = 460,
    this.panelOpacity = 0.94,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  });

  final Widget child;

  /// Inset around the panel content.
  final EdgeInsets padding;

  /// Width of the panel column; the artwork fills whatever remains.
  final double panelWidth;

  /// How opaque the panel is over the artwork. Login uses a solid panel,
  /// profile creation lets a little of the room show through.
  final double panelOpacity;

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: startupDoorway,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: palette.background),
          ),
          // Deepens the left edge so panel text keeps its contrast wherever
          // the artwork happens to be bright behind it.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  palette.background,
                  palette.background.withValues(alpha: 0.15),
                ],
                stops: const [0.35, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < panelWidth + 120
                    ? constraints.maxWidth
                    : panelWidth;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: width,
                    height: double.infinity,
                    child: ColoredBox(
                      color: palette.background.withValues(alpha: panelOpacity),
                      // Content is centred while it fits and scrolls once it
                      // does not, so a short panel has no dead band beneath it
                      // and a tall one never clips its call to action.
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            // Full panel width, so stretched children keep
                            // filling the column rather than shrink-wrapping.
                            child: SizedBox(
                              width: double.infinity,
                              child: Padding(padding: padding, child: child),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The gold rule with a centred star used above and below startup content.
class StartupOrnament extends StatelessWidget {
  const StartupOrnament({super.key, this.label});

  /// Optional caption sitting inside the rule, e.g. "Select a User".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);
    final caption = label;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: palette.gold.withValues(alpha: 0.35),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: caption == null
              ? Icon(Icons.star, size: 12, color: palette.gold)
              : Text(
                  caption,
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 13,
                    color: palette.gold.withValues(alpha: 0.85),
                  ),
                ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: palette.gold.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

/// A labelled, icon-led startup input.
class StartupField extends StatelessWidget {
  const StartupField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.optional = false,
    this.keyboardType,
    this.errorText,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool optional;
  final TextInputType? keyboardType;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (optional)
                TextSpan(
                  text: '  (Optional)',
                  style: TextStyle(
                    color: palette.gold.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: palette.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: Icon(icon, size: 18, color: palette.gold),
            hintStyle: TextStyle(
              color: palette.onSurface.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: palette.panel.withValues(alpha: 0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.focusRing, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gold-outlined startup action, used for every button on both screens.
class StartupButton extends StatelessWidget {
  const StartupButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.emphasised = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;

  /// The primary call to action carries a brighter rule and a gold label.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);
    final enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: palette.panel.withValues(alpha: 0.55),
          foregroundColor: emphasised ? palette.gold : palette.onSurface,
          disabledForegroundColor: palette.onSurface.withValues(alpha: 0.35),
          side: BorderSide(
            color: enabled
                ? palette.gold.withValues(alpha: emphasised ? 0.9 : 0.35)
                : palette.outline,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 15,
                  fontWeight: emphasised ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 10),
              Icon(trailingIcon, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
