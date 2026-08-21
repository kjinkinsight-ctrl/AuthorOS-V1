import 'supabase_service.dart';

/// The remote sign-in routes offered on the login screen.
enum StartupAuthMethod { email, password }

extension StartupAuthMethodLabel on StartupAuthMethod {
  String get label => switch (this) {
    StartupAuthMethod.email => 'Continue with Email',
    StartupAuthMethod.password => 'Use Password',
  };
}

/// What happened when an author chose a remote sign-in route.
enum StartupAuthStatus {
  /// No backend is configured for this route yet.
  unavailable,

  /// The route completed and a session exists.
  signedIn,
}

class StartupAuthResult {
  const StartupAuthResult(this.status, {this.message = ''});

  final StartupAuthStatus status;

  /// Shown to the author when a route cannot proceed.
  final String message;

  bool get isSignedIn => status == StartupAuthStatus.signedIn;
}

/// The boundary between the startup UI and remote authentication.
///
/// AuthorOS ships local profiles only. Email and password sign-in are real
/// entry points in the interface, but there is no backend behind them yet, so
/// this gateway reports them as unavailable rather than simulating a session.
/// When an authentication service does exist, it is implemented here and the
/// startup screens need no change.
class StartupAuthGateway {
  const StartupAuthGateway();

  Future<StartupAuthResult> begin(StartupAuthMethod method) async {
    if (!AppSupabase.hasCredentials) {
      return const StartupAuthResult(
        StartupAuthStatus.unavailable,
        message:
            'Online accounts are not connected in this build. Choose a local '
            'profile, or create one, to keep writing on this device.',
      );
    }

    // Supabase is reachable, but no email or password flow is wired to it yet.
    // Saying so is the honest answer; pretending to sign in is not.
    return StartupAuthResult(
      StartupAuthStatus.unavailable,
      message:
          '${method.label} is not available yet. Your work stays on this '
          'device with a local profile until online accounts arrive.',
    );
  }
}
