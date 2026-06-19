/// Auth profile model for multi-credential rotation.
///
/// Mirrors OpenClaw's agents/auth-profiles/types.ts.
/// Each profile holds credentials for one provider and tracks usage stats
/// so the router can skip profiles that are cooling down after failures.
library;

enum CooldownReason { rateLimited, overloaded, serverError }

int _intOrDefault(Object? value, int defaultValue) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return defaultValue;
}

class AuthProfile {
  final String id;

  /// Provider key matching [FlutterClawConfig.providerCredentials] keys.
  final String provider;

  /// Human-readable label shown in the Credentials settings screen.
  final String displayName;

  /// Whether this profile is enabled.
  bool enabled;

  /// Seconds epoch of when this profile's cooldown expires (0 = no cooldown).
  int cooldownUntilMs;

  CooldownReason? cooldownReason;

  int errorCount;

  /// Milliseconds since epoch of last successful use.
  int lastUsedMs;

  AuthProfile({
    required this.id,
    required this.provider,
    required this.displayName,
    this.enabled = true,
    this.cooldownUntilMs = 0,
    this.cooldownReason,
    this.errorCount = 0,
    this.lastUsedMs = 0,
  });

  bool get isOnCooldown =>
      cooldownUntilMs > 0 &&
      DateTime.now().millisecondsSinceEpoch < cooldownUntilMs;

  bool get isEligible => enabled && !isOnCooldown;

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    'displayName': displayName,
    'enabled': enabled,
    if (cooldownUntilMs > 0) 'cooldownUntilMs': cooldownUntilMs,
    if (cooldownReason != null) 'cooldownReason': cooldownReason!.name,
    if (errorCount > 0) 'errorCount': errorCount,
    if (lastUsedMs > 0) 'lastUsedMs': lastUsedMs,
  };

  factory AuthProfile.fromJson(Map<String, dynamic> json) => AuthProfile(
    id: json['id'] as String,
    provider: json['provider'] as String,
    displayName: json['displayName'] as String? ?? json['id'] as String,
    enabled: json['enabled'] as bool? ?? true,
    cooldownUntilMs: _intOrDefault(json['cooldownUntilMs'], 0),
    cooldownReason: json['cooldownReason'] != null
        ? CooldownReason.values
              .where((r) => r.name == json['cooldownReason'])
              .firstOrNull
        : null,
    errorCount: _intOrDefault(json['errorCount'], 0),
    lastUsedMs: _intOrDefault(json['lastUsedMs'], 0),
  );
}
