import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const support = {
  createTicket(body: { subject: string; message: string; category?: string }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.supportTickets, body);
  },
  getTickets(query?: { status?: string; page?: string; limit?: string }): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.supportTickets, query);
  },
  getTicket(id: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.supportTicketDetail(id));
  },
  addMessage(ticketId: string, message: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.supportTicketMessages(ticketId), { message });
  },
  async closeTicket(id: string): Promise<ApiResult<null>> {
    const res = await fetch(`${http.baseUrl}${Endpoints.supportTicketClose(id)}`, {
      method: "PATCH",
      headers: await http.headers(),
    });
    if (!res.ok) return { success: false, data: null, error: "Failed to close ticket" };
    return { success: true, data: null, error: null };
  },
};
