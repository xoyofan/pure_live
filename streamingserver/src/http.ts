/**
 * Shared upstream HTTP helpers with the contract's 12s default timeout.
 * Network failures map to contract error codes (504 UPSTREAM_TIMEOUT /
 * 502 UPSTREAM_ERROR) at the call sites via toApiError.
 */
import axios, { type AxiosRequestConfig } from 'axios';
import { isNetworkTimeout, upstreamError } from './errors.js';

export const UPSTREAM_TIMEOUT_MS = 12_000;

const client = axios.create({
  timeout: UPSTREAM_TIMEOUT_MS,
  maxRedirects: 4,
  // Upstream HTTP status failures become UPSTREAM_ERROR instead of raw axios throws.
  validateStatus: (status) => status >= 200 && status < 300,
  headers: { 'accept-encoding': 'gzip, deflate, br' },
});

function mapNetworkError(err: unknown, url: string): never {
  if (isNetworkTimeout(err)) throw err; // re-thrown; toApiError maps to 504
  const detail =
    err instanceof Error
      ? err.message
      : axios.isAxiosError(err) && err.response
        ? `HTTP ${err.response.status}`
        : String(err);
  throw upstreamError(`upstream request failed (${url}): ${detail}`);
}

export interface JsonOptions {
  params?: Record<string, string | number | undefined>;
  headers?: Record<string, string>;
  timeoutMs?: number;
}

/** GET and parse a JSON body. Throws on transport/HTTP failures. */
export async function getJson<T = unknown>(url: string, opts: JsonOptions = {}): Promise<T> {
  const config: AxiosRequestConfig = {
    params: opts.params,
    headers: opts.headers,
    timeout: opts.timeoutMs ?? UPSTREAM_TIMEOUT_MS,
    responseType: 'json',
  };
  try {
    const resp = await client.get<T>(url, config);
    return resp.data;
  } catch (err) {
    mapNetworkError(err, url);
  }
}

/** GET and return the response as text (HTML pages etc.). */
export async function getText(url: string, opts: JsonOptions = {}): Promise<string> {
  const config: AxiosRequestConfig = {
    headers: opts.headers,
    timeout: opts.timeoutMs ?? UPSTREAM_TIMEOUT_MS,
    responseType: 'text',
    transformResponse: [(data: string) => data],
  };
  try {
    const resp = await client.get<string>(url, config);
    return resp.data;
  } catch (err) {
    mapNetworkError(err, url);
  }
}

export interface TextResponse {
  text: string;
  setCookie: string[];
}

/** HEAD request; returns only the raw Set-Cookie list (douyin cookie discovery). */
export async function headSetCookies(url: string, opts: JsonOptions = {}): Promise<string[]> {
  const config: AxiosRequestConfig = {
    headers: opts.headers,
    timeout: opts.timeoutMs ?? UPSTREAM_TIMEOUT_MS,
  };
  try {
    const resp = await client.head(url, config);
    const setCookie = resp.headers['set-cookie'];
    return Array.isArray(setCookie) ? setCookie : [];
  } catch (err) {
    mapNetworkError(err, url);
  }
}


/** GET text plus the raw Set-Cookie list (douyin anonymous cookie discovery). */
export async function getTextWithCookies(url: string, opts: JsonOptions = {}): Promise<TextResponse> {
  const config: AxiosRequestConfig = {
    headers: opts.headers,
    timeout: opts.timeoutMs ?? UPSTREAM_TIMEOUT_MS,
    responseType: 'text',
    transformResponse: [(data: string) => data],
  };
  try {
    const resp = await client.get<string>(url, config);
    const setCookie = resp.headers['set-cookie'];
    return { text: resp.data, setCookie: Array.isArray(setCookie) ? setCookie : [] };
  } catch (err) {
    mapNetworkError(err, url);
  }
}
