/**
 * GET /proxy?u=<encodeURIComponent(stream URL)>&h=<base64url(JSON headers)>
 * (contracts/api.md 4.7): pulls the upstream stream with the supplied request
 * headers and pipes it through. Only http(s) URLs whose host is a known CDN
 * host (static suffixes from backends + hosts seen in play-urls responses)
 * are allowed. Failures map to contract error codes.
 */
import type { Express, Request, Response } from 'express';
import http from 'node:http';
import https from 'node:https';
import { badRequest, isNetworkTimeout, upstreamError, upstreamTimeout } from '../errors.js';
import { UPSTREAM_TIMEOUT_MS } from '../http.js';
import { registry } from '../backends/types.js';

const MAX_REDIRECTS = 5;
/** Headers we never forward to the upstream CDN. */
const HOP_BY_HOP_HEADERS = new Set([
  'host',
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'content-length',
]);
/** Response headers worth forwarding to the player. */
const PASSTHROUGH_RESPONSE_HEADERS = [
  'content-type',
  'content-length',
  'accept-ranges',
  'content-range',
  'content-disposition',
  'cache-control',
  'last-modified',
];

interface ProxyHeaders {
  [key: string]: string;
}

function decodeHeaders(raw: string | undefined): ProxyHeaders {
  if (!raw) return {};
  const json = Buffer.from(raw.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
  const parsed: unknown = JSON.parse(json);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw badRequest('h must decode to a JSON object of headers');
  }
  const headers: ProxyHeaders = {};
  for (const [key, value] of Object.entries(parsed as Record<string, unknown>)) {
    const name = key.toLowerCase().trim();
    const text = String(value ?? '').trim();
    if (!text || HOP_BY_HOP_HEADERS.has(name)) continue;
    headers[name] = text;
  }
  return headers;
}

type ResponseHandler = (upstream: http.IncomingMessage, request: http.ClientRequest) => void;

function requestOnce(
  target: URL,
  headers: ProxyHeaders,
  onResponse: ResponseHandler,
  onFailure: (err: NodeError) => void,
): http.ClientRequest {
  const transport = target.protocol === 'https:' ? https : http;
  const request = transport.get(
    target,
    {
      headers: { ...headers, host: target.host },
      timeout: UPSTREAM_TIMEOUT_MS,
    },
    (upstream) => onResponse(upstream, request),
  );
  request.on('timeout', () => {
    request.destroy();
    onFailure(Object.assign(new Error(`upstream timed out after ${UPSTREAM_TIMEOUT_MS}ms`), { code: 'ETIMEDOUT' }));
  });
  request.on('error', onFailure);
  return request;
}

interface NodeError extends Error {
  code?: string;
}

export function registerProxyRoute(app: Express): void {
  app.get('/api/v1/proxy', (req: Request, res: Response) => {
    const rawUrl = typeof req.query.u === 'string' ? req.query.u.trim() : '';
    if (!rawUrl) throw badRequest('u (encoded stream URL) is required');

    let target: URL;
    try {
      target = new URL(rawUrl);
    } catch {
      throw badRequest('u is not a valid URL');
    }
    if (target.protocol !== 'http:' && target.protocol !== 'https:') {
      throw badRequest('only http(s) stream URLs are allowed');
    }
    if (!registry.isAllowedProxyHost(target.host)) {
      throw badRequest(`host "${target.host}" is not a known CDN host`);
    }

    const headers = decodeHeaders(typeof req.query.h === 'string' ? req.query.h : undefined);
    // The browser player may forward Range even when h omits it.
    const range = req.header('range');
    if (range && !headers['range']) headers['range'] = range;

    let settled = false;
    let upstreamRequest: http.ClientRequest | null = null;
    let activeUpstream: http.IncomingMessage | null = null;

    const failBeforeStream = (err: NodeError) => {
      if (settled) return;
      settled = true;
      const apiError = isNetworkTimeout(err)
        ? upstreamTimeout(err.message)
        : upstreamError(`CDN request failed: ${err.message}`);
      if (!res.headersSent) {
        res.status(apiError.status).json({ error: { code: apiError.code, message: apiError.message } });
      } else {
        res.destroy();
      }
    };

    const handleResponse = (upstream: http.IncomingMessage, request: http.ClientRequest, redirects: number) => {
      const status = upstream.statusCode ?? 502;
      const location = upstream.headers.location;

      if (status >= 300 && status < 400 && location) {
        upstream.destroy();
        if (redirects >= MAX_REDIRECTS) {
          failBeforeStream(Object.assign(new Error('too many redirects'), { code: 'EREDIRECTS' }));
          return;
        }
        let next: URL;
        try {
          next = new URL(location, target);
        } catch {
          failBeforeStream(Object.assign(new Error('invalid redirect target'), { code: 'EBADREDIRECT' }));
          return;
        }
        if (next.protocol !== 'http:' && next.protocol !== 'https:') {
          failBeforeStream(Object.assign(new Error('redirect to non-http target'), { code: 'EBADREDIRECT' }));
          return;
        }
        if (!registry.isAllowedProxyHost(next.host)) {
          failBeforeStream(
            Object.assign(new Error(`redirect host "${next.host}" is not a known CDN host`), { code: 'EBADHOST' }),
          );
          return;
        }
        target = next;
        upstreamRequest = requestOnce(target, headers, (u2, r2) => handleResponse(u2, r2, redirects + 1), failBeforeStream);
        return;
      }

      if (status < 200 || status >= 300) {
        upstream.destroy();
        failBeforeStream(
          Object.assign(new Error(`CDN responded with HTTP ${status}`), { code: `EUPSTREAM${status}` }),
        );
        return;
      }

      settled = true;
      activeUpstream = upstream;
      res.status(status);
      for (const name of PASSTHROUGH_RESPONSE_HEADERS) {
        const value = upstream.headers[name];
        if (value !== undefined) res.setHeader(name, value);
      }

      req.on('close', () => {
        upstream.destroy();
        request.destroy();
      });
      upstream.pipe(res);
      upstream.on('error', () => {
        // Mid-stream failure: nothing but tearing the socket down is possible.
        res.destroy();
      });
    };

    upstreamRequest = requestOnce(
      target,
      headers,
      (upstream, request) => handleResponse(upstream, request, 0),
      failBeforeStream,
    );

    res.on('close', () => {
      upstreamRequest?.destroy();
      activeUpstream?.destroy();
    });
  });
}
