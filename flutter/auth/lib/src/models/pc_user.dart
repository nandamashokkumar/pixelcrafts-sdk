/// The platform user — the identity that survives sign-in.
///
/// The gateway's `/auth/token` response carries only `{ id, email }`.
/// The SDK enriches with:
///   - [role]        — derived from the platform JWT `entitlements` claim
///                     ("admin" if "admin" is present, else "user")
///   - [provider]    — hardcoded "firebase" (every gateway path goes
///                     through Firebase today; will widen if the gateway
///                     ever adds native providers)
///   - [displayName] — read from the Firebase user object client-side
///   - [photoUrl]    — same
///
/// All fields are immutable. To refresh after profile edits, sign out
/// and sign in again — the gateway re-mints the JWT with current claims.
class PCUser {
  const PCUser({
    required this.id,
    required this.email,
    this.role,
    this.provider,
    this.displayName,
    this.photoUrl,
  });

  /// Platform user ID — the gateway's `sub` claim. Stable across logins.
  final String id;

  /// Email address. Verified by the underlying Firebase account.
  final String email;

  /// Coarse role bucket derived from the JWT's `entitlements` claim.
  /// "admin" | "user". For finer-grained checks, decode the JWT and
  /// inspect `entitlements` directly.
  final String? role;

  /// Hardcoded "firebase" today.
  final String? provider;

  /// Display name from the Firebase user object (Google / Apple supply
  /// this; email-only sign-ups may not have one).
  final String? displayName;

  /// Avatar URL from the Firebase user object.
  final String? photoUrl;

  PCUser copyWith({
    String? id,
    String? email,
    String? role,
    String? provider,
    String? displayName,
    String? photoUrl,
  }) {
    return PCUser(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      provider: provider ?? this.provider,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        if (role != null) 'role': role,
        if (provider != null) 'provider': provider,
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  factory PCUser.fromJson(Map<String, dynamic> json) => PCUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String?,
        provider: json['provider'] as String?,
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PCUser && other.id == id && other.email == email);

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'PCUser(id: $id, email: $email, role: $role)';
}
