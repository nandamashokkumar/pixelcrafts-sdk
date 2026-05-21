import { init, type PlatformConfig } from "./core/config";
import { http } from "./core/http";
import { auth } from "./modules/auth";
import { billing } from "./modules/billing";
import { support } from "./modules/support";
import { sync } from "./modules/sync";
import { legal } from "./modules/legal";
import { push } from "./modules/push";

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

  /** Refresh the platform JWT manually.
   *  Apps that make authenticated requests outside the SDK (e.g. to their
   *  own backend API) can call this on 401 and retry with the new token.
   *  Returns the new token, or null if the user session has expired. */
  static async refreshToken(): Promise<string | null> {
    return http.refreshToken();
  }
}
