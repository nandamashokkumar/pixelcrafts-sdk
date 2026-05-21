import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const legal = {
  getDocuments(): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.legalDocuments);
  },
  getDocument(type: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.legalDocumentByType(type));
  },
  accept(documentType: string, version: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.legalAccept, { documentType, version });
  },
  getAcceptanceStatus(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.legalAcceptanceStatus);
  },
};
