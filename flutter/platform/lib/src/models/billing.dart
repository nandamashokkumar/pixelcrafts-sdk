/// Subscription status from the auth gateway.
/// Returned by `GET /billing/status`.
class PCSubscription {
  final String? planId;
  final String? planName;
  final String status; // 'active', 'cancelled', 'expired', 'trialing', etc.
  final DateTime? expiresAt;
  final DateTime? trialEndsAt;
  final bool willRenew;
  final String? billingProvider;

  const PCSubscription({
    this.planId,
    this.planName,
    required this.status,
    this.expiresAt,
    this.trialEndsAt,
    this.willRenew = false,
    this.billingProvider,
  });

  factory PCSubscription.fromJson(Map<String, dynamic> json) => PCSubscription(
        planId: json['planId'] as String? ?? json['plan'] as String?,
        planName: json['planName'] as String?,
        status: json['status'] as String? ?? 'unknown',
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
        trialEndsAt: json['trialEndsAt'] != null
            ? DateTime.tryParse(json['trialEndsAt'] as String)
            : null,
        willRenew: json['willRenew'] as bool? ?? false,
        billingProvider: json['billingProvider'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (planId != null) 'planId': planId,
        if (planName != null) 'planName': planName,
        'status': status,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (trialEndsAt != null) 'trialEndsAt': trialEndsAt!.toIso8601String(),
        'willRenew': willRenew,
        if (billingProvider != null) 'billingProvider': billingProvider,
      };
}

/// Entitlements from the auth gateway.
/// Returned by `GET /billing/entitlements`.
class PCEntitlements {
  final List<String> entitlements;

  const PCEntitlements({required this.entitlements});

  factory PCEntitlements.fromJson(Map<String, dynamic> json) => PCEntitlements(
        entitlements: (json['entitlements'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'entitlements': entitlements,
      };
}
