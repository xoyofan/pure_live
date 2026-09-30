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
import { buvidState, exportedWbiSign } from './backends/bilibili.js';
import { createDartSidecarBackends } from './backends/dart_sidecar.js';
import { BilibiliDanmakuSource, bindBilibiliHelpers } from './danmaku/bilibili.js';
import { SidecarPushDanmakuSource } from './danmaku/sidecar.js';
import { createRestRouter, errorMiddleware } from './routes/rest.js';
import { registerProxyRoute } from './routes/proxy.js';
import { attachDanmakuWs } from './routes/danmaku.js';

const PORT = Number(process.env.PORT ?? 8787);
const TOKEN = process.env.STREAMING_SERVER_TOKEN ?? '';

/* ------------------------------- registration -------------------------------- */

// Resolution runs through the Dart sidecar (the SAME lib/core sources the
// Flutter app uses). Without the exe the registry has no resolvers and room
// routes answer PLATFORM_UNSUPPORTED — build it via tool/sidecar.
const sidecarRegistration = createDartSidecarBackends(['bilibili', 'douyin', 'huya', 'douyu']);
if (sidecarRegistration) {
  for (const backend of sidecarRegistration.backends) {
    registry.registerBackend(backend);
  }
  console.log(`[streaming-server] dart sidecar active for: ${sidecarRegistration.backends.map((b) => b.id).join(', ')}`);
  process.on('exit', () => sidecarRegistration.process.dispose());
} else {
  console.error('[streaming-server] dart sidecar exe missing (build via tool/sidecar); resolution disabled');
}

bindBilibiliHelpers(exportedWbiSign, buvidState);
registry.registerDanmakuSource('bilibili', new BilibiliDanmakuSource());
// Douyin/huya/douyu danmaku ride the sidecar (same lib/core implementations
// as the app); bilibili keeps its host-side TS source.
if (sidecarRegistration) {
  const sidecarDanmaku = new SidecarPushDanmakuSource(sidecarRegistration.process, ['douyin', 'huya', 'douyu']);
  for (const platform of ['douyin', 'huya', 'douyu']) {
    registry.registerDanmakuSource(platform, sidecarDanmaku);
  }
}

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
