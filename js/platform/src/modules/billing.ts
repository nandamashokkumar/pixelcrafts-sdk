import { http } from "../core/http.js";
import { Endpoints } from "../core/endpoints.js";
import type { ApiResult } from "../core/result.js";

export const billing = {
  getStatus(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.billingStatus);
  },
  getEntitlements(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.billingEntitlements);
  },
  getPlans(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.billingPlans);
  },
  /** All of the user's subscriptions (current + past), newest first. */
  listSubscriptions(): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.billingSubscriptions);
  },
  subscribe(planId: string): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.billingSubscribe, { planId });
  },
  verifyPayment(body: {
    razorpay_payment_id: string;
    razorpay_subscription_id: string;
    razorpay_signature: string;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.billingVerify, body);
  },
};
