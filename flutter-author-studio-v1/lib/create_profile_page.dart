import 'package:flutter/material.dart';

import 'author_profile_store.dart';
import 'startup_backdrop.dart';

/// Reached from "Add New User" on the login screen: the doorway opening.
class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({
    super.key,
    required this.onStartAdventure,
    required this.onBack,
  });

  /// Called with a validated profile once the author commits.
  final void Function(AuthorProfile profile) onStartAdventure;

  /// Returns to the login screen without creating anything.
  final VoidCallback onBack;

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final displayNameController = TextEditingController();
  final penNameController = TextEditingController();
  final emailController = TextEditingController();
  final genresController = TextEditingController();
  final goalsController = TextEditingController();
  final regionController = TextEditingController();

  String? displayNameError;
  String? emailError;

  @override
  void dispose() {
    displayNameController.dispose();
    penNameController.dispose();
    emailController.dispose();
    genresController.dispose();
    goalsController.dispose();
    regionController.dispose();
    super.dispose();
  }

  /// Display name and email are the two fields the rest of the application
  /// already relies on, so they are the two this screen insists on.
  void _submit() {
    final displayName = displayNameController.text.trim();
    final email = emailController.text.trim();

    final nameProblem = displayName.isEmpty ? 'Enter a display name.' : null;
    final emailProblem = switch (email) {
      '' => 'Enter an email address.',
      _ when !_looksLikeEmail(email) => 'Enter a valid email address.',
      _ => null,
    };

    setState(() {
      displayNameError = nameProblem;
      emailError = emailProblem;
    });

    if (nameProblem != null || emailProblem != null) return;

    widget.onStartAdventure(
      AuthorProfile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        displayName: displayName,
        penName: penNameController.text.trim(),
        email: email,
        genres: genresController.text.trim(),
        goals: goalsController.text.trim(),
        region: regionController.text.trim(),
      ),
    );
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);

    return StartupBackdrop(
      panelWidth: 500,
      panelOpacity: 0.9,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('create-profile-back'),
              onPressed: widget.onBack,
              icon: Icon(Icons.arrow_back, size: 16, color: palette.gold),
              label: Text(
                'Back to sign in',
                style: TextStyle(color: palette.gold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create Your Profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 29,
              fontWeight: FontWeight.w700,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 12),
          const StartupOrnament(),
          const SizedBox(height: 14),
          Text(
            'Begin your journey as an author.\n'
            'Tell us a little about yourself.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 14,
              height: 1.5,
              color: palette.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          StartupField(
            fieldKey: const Key('profile-name-field'),
            label: 'Display Name',
            hint: 'What should we call you?',
            icon: Icons.person_outline,
            controller: displayNameController,
            errorText: displayNameError,
          ),
          const SizedBox(height: 12),
          StartupField(
            fieldKey: const Key('profile-pen-name-field'),
            label: 'Pen Name',
            hint: 'Your author name',
            icon: Icons.history_edu_outlined,
            controller: penNameController,
            optional: true,
          ),
          const SizedBox(height: 12),
          StartupField(
            fieldKey: const Key('profile-email-field'),
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.mail_outline,
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            errorText: emailError,
          ),
          const SizedBox(height: 12),
          StartupField(
            fieldKey: const Key('profile-genres-field'),
            label: 'Preferred Genres',
            hint: 'Fantasy, Sci-Fi, Mystery...',
            icon: Icons.menu_book_outlined,
            controller: genresController,
            optional: true,
          ),
          const SizedBox(height: 12),
          StartupField(
            fieldKey: const Key('profile-goals-field'),
            label: 'Your Writing Goals',
            hint: 'What do you hope to create?',
            icon: Icons.star_outline,
            controller: goalsController,
            optional: true,
          ),
          const SizedBox(height: 12),
          StartupField(
            fieldKey: const Key('profile-region-field'),
            label: 'Country / Region',
            hint: 'Where are you writing from?',
            icon: Icons.public_outlined,
            controller: regionController,
            optional: true,
          ),
          const SizedBox(height: 18),
          const StartupOrnament(),
          const SizedBox(height: 16),
          StartupButton(
            key: const Key('start-your-adventure'),
            label: 'Start Your Adventure',
            emphasised: true,
            trailingIcon: Icons.arrow_forward,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          Text(
            'You can change this anytime in settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 12,
              color: palette.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
