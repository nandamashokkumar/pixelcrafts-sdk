import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const metering = {
  getBudget(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.meteringBudget);
  },

  getUsage(query?: { period?: string }): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.meteringUsage, query);
  },
};
