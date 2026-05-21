/// Result type returned by all API calls — never throws.
typedef ApiResult<T> = ({bool success, T? data, String? error});
