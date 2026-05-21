import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const auth = {
  syncUser(body?: { name?: string; pictureUrl?: string; timezone?: string }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.authSync, body);
  },
  getMe(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.authMe);
  },
  logout(): Promise<ApiResult<null>> {
    return http.deleteVoid(Endpoints.authLogout);
  },
  reactivate(): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.authReactivate);
  },
  getSettings(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.userSettings);
  },
  updateSettings(settings: Record<string, unknown>): Promise<ApiResult<Record<string, unknown>>> {
    return http.putMap(Endpoints.userSettings, settings);
  },
  deleteAccount(): Promise<ApiResult<null>> {
    return http.deleteVoid(Endpoints.userAccount, { confirm: "true" });
  },
  exportData(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.userExport);
  },
};
