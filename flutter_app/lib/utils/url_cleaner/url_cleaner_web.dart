import 'package:web/web.dart' as web;

void cleanOAuthUrl() {
  try {
    web.window.history.replaceState(null, '', '/');
  } catch (_) {
    // Ignore cleanup failures; OAuth state is already handled before this runs.
  }
}
