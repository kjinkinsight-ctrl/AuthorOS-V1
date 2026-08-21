import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A locally stored AuthorOS profile.
///
/// The startup flow lets an author keep several writing identities on one
/// machine. Whichever profile is selected is mirrored onto the long-standing
/// `author_studio.profile.*` keys, so every existing reader -- the dashboard,
/// manuscript export, release destinations -- keeps working untouched.
@immutable
class AuthorProfile {
  const AuthorProfile({
    required this.id,
    required this.displayName,
    this.penName = '',
    this.email = '',
    this.genres = '',
    this.goals = '',
    this.region = '',
    this.avatarPath = '',
    this.lastActiveAt,
  });

  final String id;
  final String displayName;
  final String penName;
  final String email;
  final String genres;
  final String goals;
  final String region;
  final String avatarPath;
  final DateTime? lastActiveAt;

  /// The line shown under the name on the selection card.
  String get subtitle => penName.trim().isNotEmpty ? penName.trim() : email;

  String get initials {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed.split(RegExp(r'\s+')).first[0].toUpperCase();
  }

  AuthorProfile copyWith({DateTime? lastActiveAt}) => AuthorProfile(
    id: id,
    displayName: displayName,
    penName: penName,
    email: email,
    genres: genres,
    goals: goals,
    region: region,
    avatarPath: avatarPath,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'penName': penName,
    'email': email,
    'genres': genres,
    'goals': goals,
    'region': region,
    'avatarPath': avatarPath,
    'lastActiveAt': lastActiveAt?.toIso8601String(),
  };

  static AuthorProfile fromJson(Map<String, Object?> json) {
    final rawLastActive = json['lastActiveAt'];
    return AuthorProfile(
      id: (json['id'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      penName: (json['penName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      genres: (json['genres'] as String?) ?? '',
      goals: (json['goals'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      avatarPath: (json['avatarPath'] as String?) ?? '',
      lastActiveAt: rawLastActive is String
          ? DateTime.tryParse(rawLastActive)
          : null,
    );
  }
}

/// Reads and writes the local profile roster.
///
/// This is a thin view over the existing `SharedPreferences` storage rather
/// than a new persistence layer: the roster lives in one extra key, and the
/// selected profile continues to populate the keys the rest of the app reads.
class AuthorProfileStore {
  const AuthorProfileStore();

  static const profilesKey = 'author_studio.profiles';

  // Mirrors of the active profile, read across the existing application.
  static const nameKey = 'author_studio.profile.name';
  static const emailKey = 'author_studio.profile.email';
  static const avatarKey = 'author_studio.profile.avatar_path';

  /// Every profile on this machine, most recently active first.
  ///
  /// An install that predates the roster still has a single profile in the
  /// legacy keys; it is adopted rather than discarded.
  Future<List<AuthorProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(profilesKey);

    if (raw == null || raw.trim().isEmpty) {
      final legacy = _legacyProfile(prefs);
      return legacy == null ? const [] : [legacy];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final profiles =
        decoded
            .whereType<Map<String, Object?>>()
            .map(AuthorProfile.fromJson)
            .where((profile) => profile.id.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final aTime = a.lastActiveAt;
            final bTime = b.lastActiveAt;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
    return profiles;
  }

  /// Adopts a pre-roster install so its author is not stranded at login.
  AuthorProfile? _legacyProfile(SharedPreferences prefs) {
    final name = (prefs.getString(nameKey) ?? '').trim();
    if (name.isEmpty) return null;
    return AuthorProfile(
      id: 'legacy',
      displayName: name,
      email: (prefs.getString(emailKey) ?? '').trim(),
      avatarPath: (prefs.getString(avatarKey) ?? '').trim(),
    );
  }

  /// Appends [profile] to the roster and makes it the active profile.
  Future<AuthorProfile> createProfile(
    AuthorProfile profile, {
    DateTime? now,
  }) async {
    final stamped = profile.copyWith(lastActiveAt: now ?? DateTime.now());
    final existing = await loadProfiles();
    final roster = [
      ...existing.where((entry) => entry.id != stamped.id),
      stamped,
    ];
    await _writeRoster(roster);
    await markActive(stamped, now: now);
    return stamped;
  }

  /// Records [profile] as the one entering the workspace.
  Future<void> markActive(AuthorProfile profile, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(nameKey, profile.displayName);
    await prefs.setString(emailKey, profile.email);
    if (profile.avatarPath.isNotEmpty) {
      await prefs.setString(avatarKey, profile.avatarPath);
    }

    final roster = await loadProfiles();
    final stamped = profile.copyWith(lastActiveAt: now ?? DateTime.now());
    final updated = [
      stamped,
      ...roster.where((entry) => entry.id != profile.id),
    ];
    await _writeRoster(updated);
  }

  Future<void> _writeRoster(List<AuthorProfile> roster) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      profilesKey,
      jsonEncode(roster.map((profile) => profile.toJson()).toList()),
    );
  }
}

/// "Today", "Yesterday", "3 days ago" -- the last-active line on a profile card.
String formatLastActive(DateTime? lastActive, {DateTime? now}) {
  if (lastActive == null) return 'Not opened yet';
  final today = now ?? DateTime.now();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(lastActive.year, lastActive.month, lastActive.day))
      .inDays;
  return switch (days) {
    <= 0 => 'Today',
    1 => 'Yesterday',
    _ => '$days days ago',
  };
}
