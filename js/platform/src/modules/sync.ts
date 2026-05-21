import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const sync = {
  getStatus(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.syncStatus);
  },
  push(data: Record<string, unknown>): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.syncPush, data);
  },
  pull(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.syncPull);
  },
  getAllData(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.syncData);
  },
  getDataKey(key: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.syncDataKey(key));
  },
  putDataKey(key: string, data: Record<string, unknown>): Promise<ApiResult<Record<string, unknown>>> {
    return http.putMap(Endpoints.syncDataKey(key), data);
  },
  patchDataKey(key: string, body: { merge?: Record<string, unknown>; remove?: string[] }): Promise<ApiResult<Record<string, unknown>>> {
    return http.patchMap(Endpoints.syncDataKey(key), body);
  },
  deleteDataKey(key: string): Promise<ApiResult<null>> {
    return http.deleteVoid(Endpoints.syncDataKey(key));
  },
};
