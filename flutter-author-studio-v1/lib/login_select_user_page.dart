import 'package:flutter/material.dart';

import 'author_profile_store.dart';
import 'startup_authentication.dart';
import 'startup_backdrop.dart';

/// The cold-start screen: choose who enters the world of AuthorOS.
class LoginSelectUserPage extends StatefulWidget {
  const LoginSelectUserPage({
    super.key,
    required this.profiles,
    required this.onContinue,
    required this.onAddNewUser,
    required this.onReset,
    this.authGateway = const StartupAuthGateway(),
  });

  /// Local profiles on this machine, most recently active first.
  final List<AuthorProfile> profiles;

  /// Enters the workspace as the selected profile.
  final void Function(AuthorProfile profile) onContinue;

  /// Opens profile creation.
  final VoidCallback onAddNewUser;

  /// Clears local startup state. Carried over from the previous gate.
  final Future<void> Function() onReset;

  final StartupAuthGateway authGateway;

  @override
  State<LoginSelectUserPage> createState() => _LoginSelectUserPageState();
}

class _LoginSelectUserPageState extends State<LoginSelectUserPage> {
  String? selectedId;

  @override
  void initState() {
    super.initState();
    // The most recently active profile starts selected so a returning author
    // can press Continue immediately.
    if (widget.profiles.isNotEmpty) {
      selectedId = widget.profiles.first.id;
    }
  }

  AuthorProfile? get _selected {
    final id = selectedId;
    if (id == null) return null;
    for (final profile in widget.profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Future<void> _beginRemoteAuth(StartupAuthMethod method) async {
    final result = await widget.authGateway.begin(method);
    if (!mounted) return;

    if (result.isSignedIn) {
      final profile = _selected;
      if (profile != null) widget.onContinue(profile);
      return;
    }

    final palette = StartupPalette.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('startup-auth-notice'),
        backgroundColor: palette.panel,
        title: Text(
          method.label,
          style: TextStyle(fontFamily: 'Merriweather', color: palette.gold),
        ),
        content: Text(
          result.message,
          style: TextStyle(color: palette.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: palette.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);
    final selected = _selected;
    // Nobody has been here before, so the copy welcomes rather than welcomes
    // back, and creating the first profile becomes the primary action.
    final firstRun = widget.profiles.isEmpty;

    return StartupBackdrop(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            firstRun ? 'Welcome to' : 'Welcome Back to',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 17,
              color: palette.gold.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Author OS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 12),
          const StartupOrnament(),
          const SizedBox(height: 14),
          Text(
            firstRun
                ? 'Your story starts here.\nCreate your first profile to begin.'
                : 'Your stories await.\nPick up where you left off.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 14,
              height: 1.5,
              color: palette.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 26),
          StartupOrnament(
            label: firstRun ? 'Your First Profile' : 'Select a User',
          ),
          const SizedBox(height: 14),
          if (widget.profiles.isEmpty)
            _EmptyRoster(palette: palette)
          else
            for (final profile in widget.profiles) ...[
              _ProfileCard(
                profile: profile,
                selected: profile.id == selectedId,
                onTap: () => setState(() => selectedId = profile.id),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 6),
          StartupButton(
            key: const Key('startup-continue'),
            label: 'Continue',
            emphasised: true,
            trailingIcon: Icons.arrow_forward,
            onPressed: selected == null
                ? null
                : () => widget.onContinue(selected),
          ),
          const SizedBox(height: 10),
          StartupButton(
            key: const Key('startup-add-user'),
            label: firstRun ? 'Create Your Profile' : 'Add New User',
            icon: Icons.add,
            emphasised: firstRun,
            onPressed: widget.onAddNewUser,
          ),
          const SizedBox(height: 20),
          const StartupOrnament(label: 'or'),
          const SizedBox(height: 14),
          Text(
            'Log In Options',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 14,
              color: palette.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          StartupButton(
            key: const Key('startup-email-auth'),
            label: StartupAuthMethod.email.label,
            icon: Icons.mail_outline,
            onPressed: () => _beginRemoteAuth(StartupAuthMethod.email),
          ),
          const SizedBox(height: 10),
          StartupButton(
            key: const Key('startup-password-auth'),
            label: StartupAuthMethod.password.label,
            icon: Icons.key_outlined,
            onPressed: () => _beginRemoteAuth(StartupAuthMethod.password),
          ),
          const SizedBox(height: 14),
          TextButton(
            key: const Key('startup-forgot-password'),
            onPressed: () => _beginRemoteAuth(StartupAuthMethod.password),
            child: Text(
              'Forgot password?',
              style: TextStyle(color: palette.gold),
            ),
          ),
          TextButton(
            key: const Key('startup-reset'),
            onPressed: widget.onReset,
            child: Text(
              'Reset app state',
              style: TextStyle(
                color: palette.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster({required this.palette});

  final StartupPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.outline),
      ),
      child: Text(
        'No profiles on this device yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.onSurface.withValues(alpha: 0.7),
          height: 1.5,
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final AuthorProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);
    final lastActive = formatLastActive(profile.lastActiveAt);

    return Semantics(
      button: true,
      selected: selected,
      label: '${profile.displayName}, last active $lastActive',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('startup-profile-${profile.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          focusColor: palette.gold.withValues(alpha: 0.16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.panel.withValues(alpha: selected ? 0.85 : 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? palette.gold : palette.outline,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.background,
                    border: Border.all(
                      color: palette.gold.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    profile.initials,
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 18,
                      color: palette.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 17,
                          color: palette.onSurface,
                        ),
                      ),
                      if (profile.subtitle.isNotEmpty)
                        Text(
                          profile.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.gold.withValues(alpha: 0.85),
                          ),
                        ),
                      Text(
                        'Last active: $lastActive',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: palette.gold.withValues(alpha: selected ? 1 : 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
