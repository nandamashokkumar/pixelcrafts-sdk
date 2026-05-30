import { http } from "../core/http";
import { Endpoints } from "../core/endpoints";
import type { ApiResult } from "../core/result";

export const billing = {
  getStatus(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.billingStatus);
  },
  getEntitlements(): Promise<ApiResult<Record<string, unknown>>> {
    return http.getMap(Endpoints.billingEntitlements);
  },
  // The gateway returns { data: [ ...plans ] } — an array, so getList.
  getPlans(): Promise<ApiResult<unknown[]>> {
    return http.getList(Endpoints.billingPlans);
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
  cancelSubscription(body: {
    razorpaySubscriptionId: string;
    cancelAtCycleEnd?: boolean;
  }): Promise<ApiResult<Record<string, unknown>>> {
    return http.postMap(Endpoints.billingCancel, body);
  },
};
