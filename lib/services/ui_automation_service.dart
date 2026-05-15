/// Dart bridge to the native UI Automation MethodChannel.
///
/// Provides typed wrappers for all ui_* methods. All methods return a
/// `Map<String, dynamic>` and never throw — PlatformExceptions are caught and
/// returned as `{'error': true, 'code': ..., 'message': ...}`.
library;

import 'package:flutter/services.dart';

class UiAutomationService {
  static const _channel = MethodChannel('ai.flutterclaw/ui_automation');

  /// Check whether the Accessibility Service is enabled (Android) or return
  /// {granted: false, platform: "ios"} on iOS.
  Future<Map<String, dynamic>> checkPermission() =>
      _invoke('ui_check_permission');

  /// Open the accessibility settings page on Android so the user can enable
  /// the service. Returns {launched_settings: bool}.
  Future<Map<String, dynamic>> requestPermission() =>
      _invoke('ui_request_permission');

  /// Tap at screen coordinates (x, y) in pixels.
  Future<Map<String, dynamic>> tap(double x, double y) =>
      _invoke('ui_tap', {'x': x, 'y': y});

  /// Swipe from (x1, y1) to (x2, y2). durationMs controls speed (default 300).
  Future<Map<String, dynamic>> swipe(
    double x1,
    double y1,
    double x2,
    double y2, {
    int durationMs = 300,
  }) => _invoke('ui_swipe', {
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
    'duration_ms': durationMs,
  });

  /// Type text into the currently focused input field.
  Future<Map<String, dynamic>> typeText(String text) =>
      _invoke('ui_type_text', {'text': text});

  /// List all interactive elements on screen, optionally filtered by [query]
  /// and [by] ('all'|'text'|'id'|'description'|'class').
  Future<Map<String, dynamic>> findElements({
    String? query,
    String by = 'all',
  }) => _invoke('ui_find_elements', {'query': query, 'by': by});

  /// Find an element matching [query] (searched by [by]) and click it.
  Future<Map<String, dynamic>> clickElement(String query, String by) =>
      _invoke('ui_click_element', {'query': query, 'by': by});

  /// Capture the screen as a PNG. Returns {data: base64, mimeType: 'image/png'}.
  Future<Map<String, dynamic>> screenshot() => _invoke('ui_screenshot');

  /// Perform a global device action.
  /// [action] must be one of: back, home, recents, notifications, quick_settings.
  Future<Map<String, dynamic>> globalAction(String action) =>
      _invoke('ui_global_action', {'action': action});

  /// Get device info: manufacturer, brand, model, Android version, screen size.
  Future<Map<String, dynamic>> deviceInfo() => _invoke('ui_device_info');

  /// Launch an app by package name or search by label.
  Future<Map<String, dynamic>> launchApp({String? package_, String? search}) {
    final args = <String, dynamic>{};
    if (package_ != null) args['package'] = package_;
    if (search != null) args['search'] = search;
    return _invoke('ui_launch_app', args);
  }

  /// Fire an Android intent with optional action, URI, type, package, extras.
  Future<Map<String, dynamic>> launchIntent({
    String? action,
    String? uri,
    String? type,
    String? package_,
    Map<String, dynamic>? extras,
  }) {
    final args = <String, dynamic>{};
    if (action != null) args['action'] = action;
    if (uri != null) args['uri'] = uri;
    if (type != null) args['type'] = type;
    if (package_ != null) args['package'] = package_;
    if (extras != null) args['extras'] = extras;
    return _invoke('ui_launch_intent', args);
  }

  /// List exported activities and intent filters of a specific app.
  Future<Map<String, dynamic>> appIntents(String package_) =>
      _invoke('ui_app_intents', {'package': package_});

  /// List installed apps, optionally filtered by search and launchable-only.
  Future<Map<String, dynamic>> listApps({
    bool launchableOnly = true,
    String? search,
  }) {
    final args = <String, dynamic>{'launchable_only': launchableOnly};
    if (search != null) args['search'] = search;
    return _invoke('ui_list_apps', args);
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _invoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        method,
        args,
      );
      return result ?? {};
    } on PlatformException catch (e) {
      return {
        'error': true,
        'code': e.code,
        'message': e.message ?? 'Unknown error',
      };
    }
  }
}
