import { http } from "../core/http";
import { Endpoints } from "../core/endpoints";
import type { ApiResult } from "../core/result";

export const metering = {
  getBudget(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.meteringBudget);
  },

  getUsage(query?: { period?: string }): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.meteringUsage, query);
  },
};
