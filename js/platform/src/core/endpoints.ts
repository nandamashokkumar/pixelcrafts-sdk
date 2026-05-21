export const Endpoints = {
  // Auth
  authSync:        "/auth/sync",
  authMe:          "/auth/me",
  authLogout:      "/auth/logout",
  authReactivate:  "/auth/reactivate",

  // User
  userSettings:    "/auth/me/settings",
  userAccount:     "/user/account",
  userExport:      "/user/export",

  // Billing
  billingStatus:      "/billing/status",
  billingEntitlements: "/billing/entitlements",
  billingPlans:       "/billing/plans",
  billingSubscribe:   "/billing/razorpay/subscriptions",
  billingVerify:      "/billing/razorpay/subscriptions/verify",

  // Support
  supportTickets:       "/support/tickets",
  supportTicketDetail:  (id: string) => `/support/tickets/${id}`,
  supportTicketMessages: (id: string) => `/support/tickets/${id}/messages`,
  supportTicketClose:   (id: string) => `/support/tickets/${id}/close`,

  // Sync
  syncStatus:  "/sync/status",
  syncPush:    "/sync/push",
  syncPull:    "/sync/pull",
  syncData:    "/sync/data",
  syncDataKey: (key: string) => `/sync/data/${key}`,

  // Legal
  legalDocuments:       "/legal/documents",
  legalDocumentByType:  (type: string) => `/legal/documents/${type}`,
  legalAccept:          "/legal/accept",
  legalAcceptanceStatus: "/legal/acceptance/status",

  // Push
  pushRegister:     "/push/register",
  pushUnregister:   "/push/unregister",
  pushPreferences:  "/push/preferences",
};
