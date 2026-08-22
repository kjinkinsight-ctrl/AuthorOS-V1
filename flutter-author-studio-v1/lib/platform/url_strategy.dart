/// How AuthorOS addresses itself in a browser.
///
/// Flutter defaults to hash URLs (`/#/manuscript`), which work anywhere but
/// read like a workaround. AuthorOS uses real paths (`/manuscript`) because it
/// already serves them: the Netlify redirect and `web/_redirects` rewrite every
/// path to `index.html`, so a refresh or a shared link reaches the app rather
/// than a 404.
///
/// Off the web this is a no-op -- a desktop window has no address bar -- so the
/// call site does not need to know which platform it is on.
library;

import 'url_strategy_io.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart' as impl;

/// Installs the URL strategy for this platform. Call once, before `runApp`.
void configureUrlStrategy() => impl.configureUrlStrategy();
