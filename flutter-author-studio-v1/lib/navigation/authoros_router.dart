/// Wires AuthorOS to the browser's address bar.
///
/// The shell already knew which section it was showing; nothing outside it did.
/// That made the address bar a constant, so an author could not bookmark their
/// manuscript, send someone a link to a character, or use browser back to
/// return to the studio they came from — and a refresh only remembered that
/// they were signed in, not where they were.
///
/// This is Flutter's own Router API rather than a routing package. AuthorOS
/// has one shell and a flat list of sections; a nested-navigator framework
/// would be more machinery than that shape needs, and would put a second
/// navigation model beside the one the shell already owns.
///
/// Off the web the whole thing is inert in the way that matters: there is no
/// address bar to read or write, so [AuthorOsRouterDelegate] simply holds the
/// current section the way the shell used to.
library;

import 'package:flutter/material.dart';

import '../main.dart' show StudioSection;
import 'authoros_route.dart';

/// Translates between the browser's URL and an [AuthorOsRoute].
class AuthorOsRouteParser extends RouteInformationParser<AuthorOsRoute> {
  const AuthorOsRouteParser();

  @override
  Future<AuthorOsRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async =>
      AuthorOsRoute.fromLocation(routeInformation.uri.toString());

  @override
  RouteInformation? restoreRouteInformation(AuthorOsRoute configuration) =>
      RouteInformation(uri: Uri.parse(configuration.location));
}

/// Holds where the author is, and keeps the address bar saying the same thing.
class AuthorOsRouterDelegate extends RouterDelegate<AuthorOsRoute>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AuthorOsRoute> {
  AuthorOsRouterDelegate({required this.builder});

  /// Builds the application for the current route.
  ///
  /// The delegate deliberately knows nothing about startup screens, profiles,
  /// or studios. It owns one thing — which section is current — and hands that
  /// to the app, which decides what an author in that state should see.
  final Widget Function(BuildContext context, AuthorOsRouterDelegate delegate)
      builder;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  AuthorOsRoute _route = const AuthorOsRoute.startup();

  /// The section the URL is pointing at, or null at the startup gate.
  StudioSection? get section => _route.section;

  /// The section an author asked for before they had signed in.
  ///
  /// Opening `/manuscript` cold still has to pass the startup gate, and losing
  /// the request there would make every deep link resolve to the same default
  /// section — which is the same as not having deep links. So the request is
  /// held here and honoured once the workspace opens.
  StudioSection? pendingSection;

  @override
  AuthorOsRoute get currentConfiguration => _route;

  @override
  Future<void> setNewRoutePath(AuthorOsRoute configuration) async {
    _route = configuration;
    if (configuration.section != null) {
      pendingSection = configuration.section;
    }
    notifyListeners();
  }

  /// Moves to [section] because the author chose it inside the app.
  ///
  /// Notifying the Router is what pushes the new URL into browser history, so
  /// back returns to the previous section rather than leaving AuthorOS.
  void goToSection(StudioSection section) {
    final next = AuthorOsRoute.section(section);
    if (_route == next) {
      return;
    }
    _route = next;
    pendingSection = section;
    notifyListeners();
  }

  /// Returns the address bar to the startup gate.
  ///
  /// Used when an author signs out: leaving `/manuscript` in the URL after
  /// that would offer a link back into a workspace they have just left.
  void returnToStartup() {
    pendingSection = null;
    if (_route.isStartup) {
      return;
    }
    _route = const AuthorOsRoute.startup();
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    // `MaterialApp.router` does not install a Navigator of its own -- the
    // delegate owns the whole subtree -- so this is where AuthorOS gets the one
    // every `showDialog` and `Navigator.of(context).pop` in the studios relies
    // on.
    //
    // There is a single page. Sections are not pages stacked on each other:
    // moving from the manuscript to the timeline replaces what the workspace is
    // showing, it does not bury it under something. Dialogs and route-based
    // pickers still push above this page in the ordinary way.
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
          key: const ValueKey('authoros-shell'),
          child: builder(context, this),
        ),
      ],
      onDidRemovePage: (page) {
        // The one page is never removed; anything above it is an imperative
        // route that manages its own removal.
      },
    );
  }
}
