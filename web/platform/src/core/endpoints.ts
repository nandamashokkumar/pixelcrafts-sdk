export const Endpoints = {
  authSync: "/auth/sync",
  authMe: "/auth/me",
  authLogout: "/auth/logout",
  authReactivate: "/auth/reactivate",
  userSettings: "/auth/me/settings",
  userAccount: "/user/account",
  userExport: "/user/export",
  billingStatus: "/billing/status",
  billingEntitlements: "/billing/entitlements",
  billingPlans: "/billing/plans",
  billingSubscriptions: "/billing/subscriptions",
  billingSubscribe: "/billing/razorpay/subscriptions",
  billingVerify: "/billing/razorpay/subscriptions/verify",
  billingCancel: "/billing/razorpay/subscriptions/cancel",
  supportTickets: "/support/tickets",
  supportTicketDetail: (id: string) => `/support/tickets/${id}`,
  supportTicketMessages: (id: string) => `/support/tickets/${id}/messages`,
  supportTicketClose: (id: string) => `/support/tickets/${id}/close`,
  syncStatus: "/sync/status",
  syncPush: "/sync/push",
  syncPull: "/sync/pull",
  syncData: "/sync/data",
  syncDataKey: (key: string) => `/sync/data/${key}`,
  legalDocuments: "/legal/documents",
  legalDocumentByType: (type: string) => `/legal/documents/${type}`,
  legalAccept: "/legal/accept",
  legalAcceptanceStatus: "/legal/acceptance/status",
  pushRegister: "/push/register",
  pushUnregister: "/push/unregister",
  pushPreferences: "/push/preferences",

  // AI
  aiTextCompletion: "/jobs/text/completion",
  aiModels: "/jobs/models",
  aiUsage: "/jobs/usage",
  aiBalance: "/jobs/balance",

  // Metering
  meteringBudget: "/metering/budget",
  meteringUsage: "/metering/usage",

  // Context
  contextRecall: "/context/recall",
  contextStore: "/context/store",
  contextMemories: "/context/memories",
  contextMessages: "/context/messages",
  contextMemoryDetail: (id: string) => `/context/memories/${id}`,

  // Agent
  agentValidate: "/agent/validate",
  agentTemplates: "/agent/templates",
  agentExecute: "/agent/execute",
  agentRuns: "/agent/runs",
  agentRunDetail: (id: string) => `/agent/runs/${id}`,

  // Queue
  queueEnqueue: "/queue/enqueue",
  queueStatus: (id: string) => `/queue/status/${id}`,
  queueJobs: "/queue/jobs",
};
