export interface PlatformConfig {
  appId: string;
  apiKey: string;
  baseUrl: string;
  tokenProvider: () => Promise<string | null>;
  tokenForceRefresher?: () => Promise<string | null>;
  onSessionExpired?: () => void;
}

let _config: PlatformConfig | null = null;

export function init(config: PlatformConfig): void {
  _config = config;
}

export function getConfig(): PlatformConfig {
  if (!_config) throw new Error("PixelCraftsPlatform not initialized. Call PixelCraftsPlatform.init() first.");
  return _config;
}
