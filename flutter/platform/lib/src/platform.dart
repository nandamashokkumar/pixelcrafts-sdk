import 'modules/auth.dart';
import 'modules/billing.dart';
import 'modules/support.dart';
import 'modules/sync.dart';
import 'modules/legal.dart';
import 'modules/push.dart';
import 'modules/storage.dart';
import 'modules/ai.dart';
import 'modules/agent.dart';
import 'modules/context.dart';
import 'modules/metering.dart';
import 'modules/queue.dart';
import 'core/config.dart';

/// PixelCrafts Platform SDK — unified API client.
///
/// Initialize once (single backend):
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
/// Initialize once (split auth + api backends):
/// ```dart
/// PixelCraftsPlatform.init(
///   appId: 'verbloom',
///   apiKey: 'pk_...',
///   authBaseUrl: 'https://auth.pixelcrafts.app/v1',
///   apiBaseUrl: 'https://api.pixelcrafts.app/api/v1',
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
  ///
  /// For split backends pass [authBaseUrl] + [apiBaseUrl].
  /// For a single backend pass [baseUrl] only.
  static void init({
    required String appId,
    required String apiKey,
    String? baseUrl,
    String? authBaseUrl,
    String? apiBaseUrl,
    String? aiBaseUrl,
    required Future<String?> Function() tokenProvider,
    Future<String?> Function()? tokenForceRefresher,
    void Function()? onSessionExpired,
  }) => PixelCraftsConfig.init(
    appId: appId,
    apiKey: apiKey,
    baseUrl: baseUrl,
    authBaseUrl: authBaseUrl,
    apiBaseUrl: apiBaseUrl,
    aiBaseUrl: aiBaseUrl,
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
  final ai = const AiModule();
  final agent = const AgentModule();
  final context = const ContextModule();
  final metering = const MeteringModule();
  final queue = const QueueModule();
}
