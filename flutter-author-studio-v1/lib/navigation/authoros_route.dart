/// Where an author is in AuthorOS, expressed as something a URL can carry.
///
/// AuthorOS has exactly two kinds of place: the startup gate -- signing in,
/// creating a profile, building a first workspace -- and a studio section
/// inside the workspace. The gate is deliberately not addressable: which of
/// its screens an author sees depends on what this device already holds, not
/// on what they typed, and a link to "the sign-in step" would be a link to a
/// screen that may not exist for the person opening it.
///
/// Sections are addressable, and that is the whole point: `/manuscript` is a
/// bookmark, a shared link, and what a refresh comes back to.
library;

import 'package:flutter/foundation.dart' show immutable;

import '../main.dart'
    show StudioSection, StudioSectionData, studioSectionForSlug;

@immutable
class AuthorOsRoute {
  /// The startup gate. Not a section, and addressed as the bare root.
  const AuthorOsRoute.startup() : section = null;

  /// A studio section inside the workspace.
  const AuthorOsRoute.section(StudioSection this.section);

  /// The section this route addresses, or null at the startup gate.
  final StudioSection? section;

  bool get isStartup => section == null;

  /// Reads a route out of a URL path.
  ///
  /// Anything unrecognised resolves to the startup gate rather than throwing or
  /// inventing a section: a stale bookmark should open AuthorOS, not an error.
  factory AuthorOsRoute.fromLocation(String? location) {
    final path = (location ?? '/').split('?').first.split('#').first;
    final segments =
        path.split('/').where((segment) => segment.isNotEmpty).toList();

    if (segments.length != 1) {
      return const AuthorOsRoute.startup();
    }

    final section = studioSectionForSlug(Uri.decodeComponent(segments.first));
    return section == null
        ? const AuthorOsRoute.startup()
        : AuthorOsRoute.section(section);
  }

  /// The URL path for this route.
  String get location {
    final current = section;
    return current == null ? '/' : '/${current.slug}';
  }

  @override
  bool operator ==(Object other) =>
      other is AuthorOsRoute && other.section == section;

  @override
  int get hashCode => section.hashCode;

  @override
  String toString() => 'AuthorOsRoute($location)';
}
