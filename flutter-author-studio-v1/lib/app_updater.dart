import 'dart:convert';

import 'package:http/http.dart' as http;

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.updateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    this.releaseNotes,
  });

  final bool updateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String? releaseNotes;
}

class _VersionParts {
  const _VersionParts(this.parts);

  final List<int> parts;
}

class AppVersionChecker {
  AppVersionChecker({
    this.latestVersionUrl = _defaultLatestVersionUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  static const _defaultLatestVersionUrl =
      'https://example.com/author-studio/latest-version.json';

  final String latestVersionUrl;
  final http.Client _httpClient;

  Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) async {
    final current = currentVersion.trim();

    try {
      final response = await _httpClient
          .get(Uri.parse(latestVersionUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return AppUpdateCheckResult(
          updateAvailable: false,
          currentVersion: current,
          latestVersion: current,
        );
      }

      final decoded = jsonDecode(response.body);
      final latest = decoded is Map<String, dynamic>
          ? (decoded['version'] ?? decoded['latest_version'] ?? current)
          : decoded ?? current;
      final normalizedLatest = latest.toString().trim();
      final updateAvailable = _isNewerVersion(normalizedLatest, current);

      return AppUpdateCheckResult(
        updateAvailable: updateAvailable,
        currentVersion: current,
        latestVersion: normalizedLatest,
        releaseNotes: decoded is Map<String, dynamic>
            ? decoded['release_notes']?.toString()
            : null,
      );
    } catch (_) {
      return AppUpdateCheckResult(
        updateAvailable: false,
        currentVersion: current,
        latestVersion: current,
      );
    }
  }

  bool _isNewerVersion(String candidate, String current) {
    final candidateParts = _parseVersion(candidate);
    final currentParts = _parseVersion(current);

    if (candidateParts == null || currentParts == null) {
      return candidate.trim() != current.trim();
    }

    final maxLength = candidateParts.parts.length > currentParts.parts.length
        ? candidateParts.parts.length
        : currentParts.parts.length;

    for (var index = 0; index < maxLength; index++) {
      final candidateValue =
          index < candidateParts.parts.length ? candidateParts.parts[index] : 0;
      final currentValue =
          index < currentParts.parts.length ? currentParts.parts[index] : 0;

      if (candidateValue > currentValue) {
        return true;
      }
      if (candidateValue < currentValue) {
        return false;
      }
    }

    return false;
  }

  _VersionParts? _parseVersion(String version) {
    final numbers = RegExp(r'\d+').allMatches(version).map((match) {
      return int.parse(match.group(0)!);
    }).toList();

    return numbers.isEmpty ? null : _VersionParts(numbers);
  }
}
