import { http } from "../core/http";
import { Endpoints } from "../core/endpoints";
import type { ApiResult } from "../core/result";

export const ai = {
  complete(body: {
    model: string;
    messages: Array<{ role: string; content: string; toolCallId?: string; name?: string }>;
    temperature?: number;
    topP?: number;
    maxTokens?: number;
    stop?: string[];
    jsonMode?: boolean;
    seed?: number;
    stream?: boolean;
    reasoningEnabled?: boolean;
    reasoningBudgetTokens?: number;
    webSearchEnabled?: boolean;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.aiTextCompletion, body);
  },

  /** Raw streaming completion. Returns the Response for SSE consumption. */
  streamCompletion(body: {
    model: string;
    messages: Array<{ role: string; content: string }>;
    temperature?: number;
    maxTokens?: number;
  }): Promise<Response | null> {
    return http.postRaw(Endpoints.aiTextCompletion, { ...body, stream: true });
  },

  listModels(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.aiModels);
  },

  getUsage(query?: { period?: string; from?: string; to?: string }): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.aiUsage, query);
  },

  getBalance(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.aiBalance);
  },
};
