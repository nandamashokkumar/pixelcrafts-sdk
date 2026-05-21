/// Plan definition from the auth gateway.
/// Returned by `GET /billing/plans`.
class PCPlan {
  final String id;
  final String name;
  final String? description;
  final int price; // in smallest currency unit (e.g. cents, paise)
  final String currency;
  final String interval; // 'month' | 'year' | 'lifetime'
  final Map<String, dynamic> limits;
  final List<String> features;
  final String? entitlementId;
  final int sortOrder;

  const PCPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.interval,
    required this.limits,
    required this.features,
    this.entitlementId,
    required this.sortOrder,
  });

  factory PCPlan.fromJson(Map<String, dynamic> json) => PCPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: json['price'] as int,
        currency: json['currency'] as String,
        interval: json['interval'] as String,
        limits: (json['limits'] as Map<String, dynamic>?) ?? {},
        features: (json['features'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        entitlementId: json['entitlementId'] as String?,
        sortOrder: json['sortOrder'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'currency': currency,
        'interval': interval,
        'limits': limits,
        'features': features,
        'entitlementId': entitlementId,
        'sortOrder': sortOrder,
      };
}
