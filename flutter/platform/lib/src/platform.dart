import 'modules/auth.dart';
import 'modules/billing.dart';
import 'modules/support.dart';
import 'modules/sync.dart';
import 'modules/legal.dart';
import 'modules/push.dart';
import 'modules/storage.dart';
import 'core/config.dart';

/// PixelCrafts Platform SDK — unified API client.
///
/// Initialize once:
/// ```dart
/// PixelCraftsPlatform.init(
///   appId: 'verbloom',
///   apiKey: 'pk_...',
///   baseUrl: 'https://auth.pixelcrafts.app/v1',
///   tokenProvider: () => authService.getIdToken(),
///   tokenForceRefresher: () => authService.getIdToken(forceRefresh: true),
///   onSessionExpired: () => router.go('/login'),
/// );
/// ```
///
/// Then use anywhere:
/// ```dart
/// final status = await PixelCraftsPlatform.instance.billing.getStatus();
/// final tickets = await PixelCraftsPlatform.instance.support.getTickets();
/// ```
class PixelCraftsPlatform {
  PixelCraftsPlatform._();
  static final PixelCraftsPlatform instance = PixelCraftsPlatform._();

  /// Initialize the SDK. Must be called before any API usage.
  static void init({
    required String appId,
    required String apiKey,
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    Future<String?> Function()? tokenForceRefresher,
    void Function()? onSessionExpired,
  }) => PixelCraftsConfig.init(
    appId: appId,
    apiKey: apiKey,
    baseUrl: baseUrl,
    tokenProvider: tokenProvider,
    tokenForceRefresher: tokenForceRefresher,
    onSessionExpired: onSessionExpired,
  );

  final auth = const AuthModule();
  final billing = const BillingModule();
  final support = const SupportModule();
  final sync = const SyncModule();
  final legal = const LegalModule();
  final push = const PushModule();
  final storage = const StorageModule();
}
