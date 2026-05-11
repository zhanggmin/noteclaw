import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsService {
  const AnalyticsService();

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {}

  Future<void> logTap({
    required String name,
    Map<String, Object>? parameters,
  }) async {}

  Future<void> logAction({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return const AnalyticsService();
});
