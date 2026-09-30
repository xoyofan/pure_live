/**
 * REST endpoints of contracts/api.md: 4.1 health, 4.2 platforms, 4.3 resolve,
 * 4.4 qualities, 4.5 play-urls. All non-2xx failures serialize through the
 * shared error middleware as {"error":{code,message}}.
 */
import { Router, type NextFunction, type Request, type RequestHandler, type Response } from 'express';
import { registry } from '../backends/types.js';
import { badRequest, platformUnsupported, toApiError } from '../errors.js';

const VERSION = '1.0.0';

/** Async handler wrapper that routes rejections to the error middleware. */
function handler(fn: (req: Request, res: Response) => Promise<void>): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res).catch(next);
  };
}

function requireRoomId(value: unknown): string {
  const roomId = typeof value === 'string' ? value.trim() : '';
  if (!roomId) throw badRequest('roomId is required');
  return roomId;
}

function getBackend(platform: string) {
  const backend = registry.getBackend(platform);
  if (!backend) throw platformUnsupported(platform);
  return backend;
}

export function createRestRouter(): Router {
  const router = Router();

  // 4.1 GET /health
  router.get('/health', (_req, res) => {
    res.json({
      ok: true,
      version: VERSION,
      platforms: registry.listPlatforms().map((platform) => platform.id),
      uptimeSec: Math.round(process.uptime()),
    });
  });

  // 4.2 GET /platforms
  router.get('/platforms', (_req, res) => {
    res.json({ platforms: registry.listPlatforms() });
  });

  // 4.3 POST /rooms/{platform}/resolve
  router.post(
    '/rooms/:platform/resolve',
    handler(async (req, res) => {
      const backend = getBackend(req.params.platform ?? '');
      const roomId = requireRoomId(req.body?.roomId);
      const room = await backend.resolveRoom(roomId);
      res.json({ room });
    }),
  );

  // 4.4 GET /rooms/{platform}/qualities?roomId=
  router.get(
    '/rooms/:platform/qualities',
    handler(async (req, res) => {
      const backend = getBackend(req.params.platform ?? '');
      const roomId = requireRoomId(req.query.roomId);
      const qualities = await backend.getQualities(roomId);
      res.json({ qualities });
    }),
  );

  // 4.5 POST /rooms/{platform}/play-urls
  router.post(
    '/rooms/:platform/play-urls',
    handler(async (req, res) => {
      const backend = getBackend(req.params.platform ?? '');
      const roomId = requireRoomId(req.body?.roomId);
      const quality = typeof req.body?.quality === 'string' && req.body.quality.trim() ? req.body.quality.trim() : undefined;
      const withHeaders = req.body?.withHeaders !== false;
      const result = await backend.getPlayUrls(roomId, quality);
      registry.notePlayUrlHosts(result.urls);
      if (!withHeaders) result.headers = {};
      res.json(result);
    }),
  );

  return router;
}

/** Express error middleware producing the contract error model. */
export function errorMiddleware(err: unknown, _req: Request, res: Response, _next: NextFunction): void {
  const apiError = toApiError(err);
  if (apiError.status >= 500) {
    console.error(`[streaming-server] ${apiError.code}: ${apiError.message}`);
  }
  res.status(apiError.status).json({ error: { code: apiError.code, message: apiError.message } });
}
