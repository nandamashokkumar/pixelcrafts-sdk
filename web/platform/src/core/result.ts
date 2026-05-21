export type ApiResult<T> =
  | { success: true; data: T; error: null }
  | { success: false; data: null; error: string };
