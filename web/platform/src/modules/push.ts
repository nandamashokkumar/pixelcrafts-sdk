import { http } from "../core/http";
import { Endpoints } from "../core/endpoints";
import type { ApiResult } from "../core/result";

export const push = {
  registerDevice(body: {
    fcmToken: string;
    platform: string;
    deviceId: string;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.pushRegister, body);
  },
  unregisterDevice(deviceId: string): Promise<ApiResult<null>> {
    return http.deleteVoid(Endpoints.pushUnregister, { deviceId });
  },
  getPreferences(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.pushPreferences);
  },
  updatePreferences(prefs: {
    enabled: boolean;
    reminders: boolean;
    updates: boolean;
    marketing: boolean;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.putMap(Endpoints.pushPreferences, prefs);
  },
};
