import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding.dart';

class AppSupabase {
  static const _initializationTimeout = Duration(seconds: 5);
  static const String _defaultUrl = 'https://dzhfhypgkukvfliubykv.supabase.co';
  static const String _defaultAnonKey =
      'sb_publishable_-gYq0Uwtme6kexFgp4sG9g_DDtF7eBc';

  static String get resolvedUrl => const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: _defaultUrl,
      );

  static String get resolvedAnonKey => const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: _defaultAnonKey,
      );

  static bool _available = false;

  static bool get _isConfigured =>
      resolvedUrl.isNotEmpty && resolvedAnonKey.isNotEmpty;

  static bool get hasCredentials => _available;

  static Future<void> initialize() async {
    if (!_isConfigured) {
      debugPrint(
        'Supabase credentials are not configured. Falling back to local persistence until SUPABASE_URL and SUPABASE_ANON_KEY are provided.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: resolvedUrl,
        publishableKey: resolvedAnonKey,
      ).timeout(_initializationTimeout);
      _available = true;
    } catch (error) {
      _available = false;
      debugPrint(
        'Supabase initialization failed. Continuing with local persistence: $error',
      );
    }
  }

  static SupabaseClient get client {
    if (!hasCredentials) {
      throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY before using cloud persistence.',
      );
    }
    return Supabase.instance.client;
  }

  static bool get isSignedIn {
    if (!hasCredentials) {
      return false;
    }

    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> signInWithGoogle() async {
    if (!hasCredentials) {
      debugPrint(
        'Google sign-in is unavailable until Supabase credentials are configured.',
      );
      return false;
    }

    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      authScreenLaunchMode: LaunchMode.inAppWebView,
    );
  }

  static Future<void> signOut() async {
    if (!hasCredentials) {
      return;
    }
    await client.auth.signOut();
  }

  static Future<StarterProject?> loadCurrentProject() async {
    if (!hasCredentials || !isSignedIn) {
      return null;
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    final response = await client
        .from('projects')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final payload = response == null ? null : response['payload'];
    if (payload is! Map) {
      return null;
    }

    return StarterProject.fromJson(Map<String, dynamic>.from(payload));
  }

  static Future<List<StarterProject>> loadProjects() async {
    if (!hasCredentials || !isSignedIn) {
      return const [];
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const [];
    }

    final response = await client
        .from('projects')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    final rows = response as List<dynamic>? ?? const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((row) => row['payload'])
        .whereType<Map>()
        .map((payload) =>
            StarterProject.fromJson(Map<String, dynamic>.from(payload)))
        .toList();
  }

  static Future<void> saveProject(StarterProject project) async {
    if (!hasCredentials || !isSignedIn) {
      return;
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }

    final payload = jsonEncode(project.toJson());
    await client.from('projects').upsert({
      'user_id': userId,
      'project_id': project.id,
      'title': project.title,
      'payload': jsonDecode(payload),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,project_id');
  }

  /// Sync records changed at or after [since], oldest first.
  ///
  /// The read half of the sync protocol. Until this existed the app only ever
  /// wrote to `sync_records` and never looked at it, which is why a second
  /// device saw nothing.
  ///
  /// Ordered ascending by `updated_at` so the caller can advance a cursor as
  /// it goes, and bounded by [limit] so one very busy account cannot pull an
  /// unbounded page. Returns an empty list — never throws — when Supabase is
  /// unconfigured or the author is signed out, matching [loadProjects].
  static Future<List<Map<String, dynamic>>> loadSyncRecords({
    DateTime? since,
    int limit = 500,
  }) async {
    if (!hasCredentials || !isSignedIn) {
      return const [];
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const [];
    }

    var query = client.from('sync_records').select().eq('user_id', userId);
    if (since != null) {
      // At-or-after, not after: a record sharing the cursor's exact instant
      // would otherwise never be seen. Re-reading one row is harmless because
      // applying a record the device already has is a no-op.
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }

    final response =
        await query.order('updated_at', ascending: true).limit(limit);

    final rows = response as List<dynamic>? ?? const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<void> saveSyncRecord({
    required String recordType,
    required String recordId,
    required String action,
    required int baseRevision,
    required int revision,
    required Map<String, dynamic> payload,
    String? deviceId,
  }) async {
    if (!hasCredentials || !isSignedIn) {
      return;
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }

    await client.from('sync_records').upsert({
      'user_id': userId,
      'record_type': recordType,
      'record_id': recordId,
      'action': action,
      'base_revision': baseRevision,
      'revision': revision,
      'payload': payload,
      'device_id': deviceId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,record_type,record_id');
  }
}
