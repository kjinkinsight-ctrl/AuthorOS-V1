/// Browser implementation of [configureUrlStrategy].
///
/// See `url_strategy.dart` for why AuthorOS uses paths rather than hashes, and
/// what the deployment has to do to support them.
library;

import 'package:flutter_web_plugins/url_strategy.dart';

void configureUrlStrategy() => usePathUrlStrategy();
