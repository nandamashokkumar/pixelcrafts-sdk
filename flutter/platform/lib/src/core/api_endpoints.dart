/// API endpoint path constants for the PixelCrafts gateway.
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ──
  static const String authSync = '/auth/sync';
  static const String authMe = '/auth/me';
  static const String authLogout = '/auth/logout';
  static const String authReactivate = '/auth/reactivate';

  // ── Billing ──
  static const String billingStatus = '/billing/status';
  static const String billingEntitlements = '/billing/entitlements';
  static const String billingPlans = '/billing/plans';

  // ── User ──
  static const String userProfile = '/user/profile';
  static const String userSettings = '/user/settings';
  static const String userAccount = '/user/account';
  static const String userExport = '/user/export';

  // ── Sync ──
  static const String syncData = '/sync/data';
  static String syncDataKey(String key) => '/sync/data/$key';
  static const String syncStatus = '/sync/status';
  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';

  // ── Push ──
  static const String pushRegister = '/push/register';
  static const String pushUnregister = '/push/unregister';
  static const String pushPreferences = '/push/preferences';

  // ── Support ──
  static const String supportTickets = '/support/tickets';
  static String supportTicketDetail(String id) => '/support/tickets/$id';
  static String supportTicketMessages(String id) => '/support/tickets/$id/messages';
  static String supportTicketClose(String id) => '/support/tickets/$id/close';

  // ── Storage ──
  static const String storageUpload = '/storage/upload';
  static const String storageUploadImage = '/storage/upload/image';
  static String storagePresignedUrl(String key) => '/storage/url/$key';
  static String storageFile(String key) => '/storage/$key';

  // ── Legal ──
  static const String legalDocuments = '/legal/documents';
  static String legalDocumentByType(String type) => '/legal/documents/$type';
  static const String legalAccept = '/legal/accept';
  static const String legalAcceptanceStatus = '/legal/acceptance-status';

  // ── AI ──
  static const String aiTextCompletion = '/jobs/text/completion';
  static const String aiModels = '/jobs/models';
  static const String aiUsage = '/jobs/usage';
  static const String aiBalance = '/jobs/balance';

  // ── Metering ──
  static const String meteringBudget = '/metering/budget';
  static const String meteringUsage = '/metering/usage';

  // ── Context ──
  static const String contextRecall = '/context/recall';
  static const String contextStore = '/context/store';
  static const String contextMemories = '/context/memories';
  static const String contextMessages = '/context/messages';
  static String contextMemoryDetail(String id) => '/context/memories/$id';

  // ── Agent ──
  static const String agentValidate = '/agent/validate';
  static const String agentTemplates = '/agent/templates';
  static const String agentExecute = '/agent/execute';
  static const String agentRuns = '/agent/runs';
  static String agentRunDetail(String id) => '/agent/runs/$id';

  // ── Queue ──
  static const String queueEnqueue = '/queue/enqueue';
  static String queueStatus(String id) => '/queue/status/$id';
  static const String queueJobs = '/queue/jobs';
}
