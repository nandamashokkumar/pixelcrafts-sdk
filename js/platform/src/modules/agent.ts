import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const agent = {
  validate(definition: unknown): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.agentValidate, definition);
  },

  getTemplates(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.agentTemplates);
  },

  execute(body: {
    userId: string;
    workflowRunId: string;
    definition: unknown;
    triggerInput: unknown;
    resumeStepKey?: string;
    resumeValue?: unknown;
    resumeContext?: Record<string, unknown>;
    executionTarget?: "handoff" | "platform";
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.agentExecute, body);
  },

  listRuns(): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.agentRuns);
  },

  getRun(id: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.agentRunDetail(id));
  },
};
