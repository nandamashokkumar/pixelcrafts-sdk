import { init, type PlatformConfig } from "./core/config.js";
import { auth } from "./modules/auth.js";
import { billing } from "./modules/billing.js";
import { support } from "./modules/support.js";
import { sync } from "./modules/sync.js";
import { legal } from "./modules/legal.js";
import { push } from "./modules/push.js";
import { ai } from "./modules/ai.js";
import { agent } from "./modules/agent.js";
import { context } from "./modules/context.js";
import { metering } from "./modules/metering.js";
import { queue } from "./modules/queue.js";

/**
 * PixelCrafts Platform SDK — unified API client for web apps.
 *
 * ```ts
 * PixelCraftsPlatform.init({
 *   appId: "themeroid",
 *   apiKey: "pk_...",
 *   baseUrl: "https://auth.pixelcrafts.app/v1",
 *   tokenProvider: async () => localStorage.getItem("pc_token"),
 *   onSessionExpired: () => window.location.href = "/login",
 * });
 *
 * const status = await PixelCraftsPlatform.billing.getStatus();
 * ```
 */
export class PixelCraftsPlatform {
  static init(config: PlatformConfig): void {
    init(config);
  }

  static readonly auth = auth;
  static readonly billing = billing;
  static readonly support = support;
  static readonly sync = sync;
  static readonly legal = legal;
  static readonly push = push;
  static readonly ai = ai;
  static readonly agent = agent;
  static readonly context = context;
  static readonly metering = metering;
  static readonly queue = queue;
}
