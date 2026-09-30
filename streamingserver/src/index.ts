/**
 * Pure Live Streaming Server — entry point.
 *
 * HTTP/WS contract: see ../../contracts/api.md (authoritative).
 * M1: bilibili + douyin resolution, /proxy, bilibili danmaku WS.
 */
import express from 'express';
import cors from 'cors';
import type { Server } from 'node:http';

import { registry } from './backends/types.js';
import { BilibiliBackend, buvidState, exportedWbiSign } from './backends/bilibili.js';
import { DouyinBackend } from './backends/douyin.js';
import { createDartSidecarBackends } from './backends/dart_sidecar.js';
import { BilibiliDanmakuSource, bindBilibiliHelpers } from './danmaku/bilibili.js';
import { createRestRouter, errorMiddleware } from './routes/rest.js';
import { registerProxyRoute } from './routes/proxy.js';
import { attachDanmakuWs } from './routes/danmaku.js';
import { sm3SelfTest } from './sign/sm3.js';

const PORT = Number(process.env.PORT ?? 8787);
const TOKEN = process.env.STREAMING_SERVER_TOKEN ?? '';

// Fail fast if the SM3 primitive used by the a_bogus signer regressed.
if (!sm3SelfTest()) {
  console.error('[streaming-server] SM3 self test failed; aborting');
  process.exit(1);
}

/* ------------------------------- registration -------------------------------- */

const bilibiliBackend = new BilibiliBackend();
const douyinBackend = new DouyinBackend();
registry.registerBackend(bilibiliBackend);
registry.registerBackend(douyinBackend);

// Dart sidecar backends override their TS twins when the exe exists: the
// Flutter app and this server then run the SAME lib/core parsing sources.
// STREAMING_PARSER=ts forces the pure-TS path (comparison / fallback).
const sidecarRegistration = createDartSidecarBackends(['bilibili', 'douyin']);
if (sidecarRegistration) {
  for (const backend of sidecarRegistration.backends) {
    registry.registerBackend(backend);
  }
  console.log(`[streaming-server] dart sidecar active for: ${sidecarRegistration.backends.map((b) => b.id).join(', ')}`);
  process.on('exit', () => sidecarRegistration.process.dispose());
} else {
  console.log('[streaming-server] dart sidecar not found; using TS resolvers (build it via tool/sidecar)');
}

bindBilibiliHelpers(exportedWbiSign, buvidState);
registry.registerDanmakuSource(bilibiliBackend.id, new BilibiliDanmakuSource());

/* --------------------------------- express ----------------------------------- */

const app = express();
app.use(cors({ origin: ['http://localhost:5173', 'http://127.0.0.1:5173'] }));
app.use(express.json({ limit: '64kb' }));

// Optional shared-token guard; disabled when no token configured.
if (TOKEN) {
  app.use((req, res, next) => {
    if (req.path === '/api/v1/health') return next();
    if (req.header('X-Server-Token') !== TOKEN) {
      return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'token mismatch' } });
    }
    return next();
  });
}

app.use('/api/v1', createRestRouter());
registerProxyRoute(app);

app.use((_req, res) => {
  res.status(404).json({ error: { code: 'BAD_REQUEST', message: `unknown route ${_req.method} ${_req.path}` } });
});

app.use(errorMiddleware);

const server: Server = app.listen(PORT, '127.0.0.1', () => {
  console.log(`[streaming-server] listening on http://127.0.0.1:${PORT}/api/v1`);
});
attachDanmakuWs(server, TOKEN);

/* ------------------------------ graceful shutdown ----------------------------- */

function shutdown(): void {
  console.log('[streaming-server] shutting down');
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 2000).unref();
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
