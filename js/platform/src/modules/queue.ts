import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const queue = {
  enqueue(body: {
    queueName: string;
    payload?: Record<string, unknown>;
    priority?: number;
    delaySec?: number;
    retries?: number;
    retryDelaySec?: number;
    timeoutSec?: number;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.queueEnqueue, body);
  },

  getStatus(id: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.queueStatus(id));
  },

  listJobs(query?: { queueName?: string; state?: string }): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.queueJobs, query);
  },
};
