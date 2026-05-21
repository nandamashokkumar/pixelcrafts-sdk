import { http } from "../core/http";
import { Endpoints } from "../core/endpoints";
import type { ApiResult } from "../core/result";

export const support = {
  createTicket(body: {
    subject: string;
    message: string;
    category?: string;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.supportTickets, body);
  },
  getTickets(query?: {
    status?: string;
    page?: string;
    limit?: string;
  }): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.supportTickets, query);
  },
  getTicket(id: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.supportTicketDetail(id));
  },
  addMessage(
    ticketId: string,
    message: string
  ): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.supportTicketMessages(ticketId), { message });
  },
  closeTicket(id: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.patchMap(Endpoints.supportTicketClose(id));
  },
};
