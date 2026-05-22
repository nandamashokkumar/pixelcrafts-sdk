export interface PlatformConfig {
  appId: string;
  apiKey: string;
  /** Legacy single base URL. Use `authBaseUrl` + `apiBaseUrl` for dual-routing. */
  baseUrl?: string;
  /** Gateway base URL for auth, billing, user, push, support, legal. */
  authBaseUrl?: string;
  /** API base URL for sync, learning, analytics, catalog. */
  apiBaseUrl?: string;
  tokenProvider: () => Promise<string | null>;
  tokenForceRefresher?: () => Promise<string | null>;
  onSessionExpired?: () => void;
}

let _config: PlatformConfig | null = null;

export function init(config: PlatformConfig): void {
  _config = config;
}

export function getConfig(): PlatformConfig {
  if (!_config)
    throw new Error(
      "PixelCraftsPlatform not initialized. Call PixelCraftsPlatform.init() first."
    );
  return _config;
}
