import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const context = {
  recall(body: {
    userId: string;
    projectId?: string | null;
    query: string;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.contextRecall, body);
  },

  store(body: {
    userId: string;
    projectId?: string | null;
    fact: string;
    category?: string;
    importance?: number;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.contextStore, body);
  },

  listMemories(query: { userId: string; projectId?: string }): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.contextMemories, query);
  },

  deleteMemory(id: string, query: { userId: string }): Promise<ApiResult<null>> {
    return http.deleteVoid(Endpoints.contextMemoryDetail(id), query);
  },

  getMessages(query: { conversationId: string; limit?: string }): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.contextMessages, query);
  },
};
