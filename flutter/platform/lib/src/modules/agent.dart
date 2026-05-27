import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Agent module — workflow validation, templates, execution, runs.
class AgentModule {
  const AgentModule();

  Future<ApiResult<Map<String, dynamic>>> validate(Map<String, dynamic> definition) =>
      HttpClient.instance.postMap(ApiEndpoints.agentValidate, body: definition);

  Future<ApiResult<Map<String, dynamic>>> getTemplates() =>
      HttpClient.instance.getMap(ApiEndpoints.agentTemplates);

  Future<ApiResult<Map<String, dynamic>>> execute(Map<String, dynamic> body) =>
      HttpClient.instance.postMap(ApiEndpoints.agentExecute, body: body);

  Future<ApiResult<List<dynamic>>> listRuns() =>
      HttpClient.instance.getRawList(ApiEndpoints.agentRuns);

  Future<ApiResult<Map<String, dynamic>>> getRun(String id) =>
      HttpClient.instance.getMap(ApiEndpoints.agentRunDetail(id));
}
