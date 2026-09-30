/**
 * Contract error model: see contracts/api.md section 2.
 * Non-2xx responses always serialize as {"error":{"code","message"}}.
 */
export type ErrorCode =
  | 'BAD_REQUEST'
  | 'UNAUTHORIZED'
  | 'PLATFORM_UNSUPPORTED'
  | 'ROOM_NOT_FOUND'
  | 'ROOM_CLOSED'
  | 'UPSTREAM_ERROR'
  | 'UPSTREAM_TIMEOUT'
  | 'INTERNAL';

export class ApiError extends Error {
  readonly status: number;
  readonly code: ErrorCode;

  constructor(status: number, code: ErrorCode, message: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
  }
}

export function badRequest(message: string): ApiError {
  return new ApiError(400, 'BAD_REQUEST', message);
}

export function platformUnsupported(platform: string): ApiError {
  return new ApiError(404, 'PLATFORM_UNSUPPORTED', `platform "${platform}" is not supported`);
}

export function roomNotFound(message: string): ApiError {
  return new ApiError(404, 'ROOM_NOT_FOUND', message);
}

export function roomClosed(message: string): ApiError {
  return new ApiError(410, 'ROOM_CLOSED', message);
}

export function upstreamError(message: string): ApiError {
  return new ApiError(502, 'UPSTREAM_ERROR', message);
}

export function upstreamTimeout(message: string): ApiError {
  return new ApiError(504, 'UPSTREAM_TIMEOUT', message);
}

/** True when the error is an axios/network timeout worth mapping to 504. */
export function isNetworkTimeout(err: unknown): boolean {
  if (!err || typeof err !== 'object') return false;
  const code = (err as { code?: unknown }).code;
  const message = (err as { message?: unknown }).message;
  return (
    code === 'ECONNABORTED' ||
    code === 'ETIMEDOUT' ||
    (typeof message === 'string' && message.toLowerCase().includes('timeout'))
  );
}

/** Maps any thrown value to an ApiError per the contract error table. */
export function toApiError(err: unknown): ApiError {
  if (err instanceof ApiError) return err;
  if (isNetworkTimeout(err)) {
    const detail = err instanceof Error ? err.message : String(err);
    return upstreamTimeout(`upstream timed out: ${detail}`);
  }
  if (err && typeof err === 'object') {
    const withResp = err as { response?: { status?: number } };
    if (withResp.response && typeof withResp.response.status === 'number') {
      return upstreamError(`upstream responded with HTTP ${withResp.response.status}`);
    }
  }
  const detail = err instanceof Error ? err.message : String(err);
  return new ApiError(500, 'INTERNAL', detail || 'internal error');
}
