/// PixelCrafts Platform SDK
///
/// Unified API client for all PixelCrafts apps. Copy this folder into
/// your app's `packages/` directory and add a path dependency in pubspec.yaml.
///
/// ```yaml
/// dependencies:
///   pixelcrafts_platform:
///     path: packages/pixelcrafts_platform
/// ```
///
/// ```dart
/// import 'package:pixelcrafts_platform/pixelcrafts_platform.dart';
///
/// final pc = PixelCraftsPlatform(
///   appId: 'verbloom',
///   apiKey: 'pk_...',
///   baseUrl: 'https://auth.pixelcrafts.app/v1',
///   tokenProvider: () => authService.getIdToken(),
/// );
///
/// final status = await pc.billing.getStatus();
/// ```
library;

export 'src/platform.dart';
export 'src/core/config.dart';
export 'src/core/result.dart';
