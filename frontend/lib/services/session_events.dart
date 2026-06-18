import 'dart:async';

/// Fired when the API rejects the session and token refresh fails.
final sessionExpiredController = StreamController<void>.broadcast();
