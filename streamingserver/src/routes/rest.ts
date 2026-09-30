/**
 * REST endpoints of contracts/api.md: 4.1 health, 4.2 platforms, 4.3 resolve,
 * 4.3.1 live-status, 4.4 qualities, 4.5 play-urls. All non-2xx failures
 * serialize through the shared error middleware as {"error":{code,message}}.
 */
import { Router, type NextFunction, type Request, type RequestHandler, type Response } from 'express';
import { registry } from '../backends/types.js';
import type { SidecarProcess } from '../backends/dart_sidecar.js';
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

/** api.md 4.6: page is 1-based, pageSize defaults to 30 and caps at 50. */
function listQueryOf(query: Request['query']): { page: number; pageSize: number } {
  const page = Math.max(1, Number.parseInt(String(query.page ?? ''), 10) || 1);
  const pageSize = Math.min(50, Math.max(1, Number.parseInt(String(query.pageSize ?? ''), 10) || 30));
  return { page, pageSize };
}

/** True when the backend implements the 4.6 directory/search capability. */
function requireListBackend(platform: string) {
  const backend = getBackend(platform);
  if (!backend.getCategories || !backend.getRecommendRooms || !backend.getCategoryRooms || !backend.searchRooms) {
    throw platformUnsupported(platform);
  }
  return backend as Required<Pick<
    typeof backend,
    'getCategories' | 'getRecommendRooms' | 'getCategoryRooms' | 'searchRooms'
  >>;
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

  // 4.3.1 GET /rooms/{platform}/live-status?roomId=
  router.get(
    '/rooms/:platform/live-status',
    handler(async (req, res) => {
      const platform = req.params.platform ?? '';
      const backend = getBackend(platform);
      const roomId = requireRoomId(req.query.roomId);
      // Liveness rides the sidecar transport owned by the backend (sidecar
      // "liveStatus" -> lib/core LiveSite.getLiveStatus, upstream failures
      // already normalized to {"live":false} there). Non-sidecar backends
      // fall back to full room metadata (4.3 semantics).
      const sidecar = (backend as { sidecar?: SidecarProcess }).sidecar;
      if (sidecar) {
        const result = await sidecar.call<{ live?: boolean }>('liveStatus', { platform, roomId });
        res.json({ live: result.live === true });
        return;
      }
      const room = await backend.resolveRoom(roomId);
      res.json({ live: room.liveStatus === 'live' || room.status });
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

  // 4.6.1 GET /directory/{platform}/categories
  router.get(
    '/directory/:platform/categories',
    handler(async (req, res) => {
      const backend = requireListBackend(req.params.platform ?? '');
      const categories = await backend.getCategories(listQueryOf(req.query));
      res.json({ categories });
    }),
  );

  // 4.6.2 GET /directory/{platform}/recommend
  router.get(
    '/directory/:platform/recommend',
    handler(async (req, res) => {
      const backend = requireListBackend(req.params.platform ?? '');
      res.json(await backend.getRecommendRooms(listQueryOf(req.query)));
    }),
  );

  // 4.6.3 GET /directory/{platform}/categories/{areaId}/rooms
  router.get(
    '/directory/:platform/categories/:areaId/rooms',
    handler(async (req, res) => {
      const backend = requireListBackend(req.params.platform ?? '');
      const areaId = String(req.params.areaId ?? '').trim();
      if (!areaId) throw badRequest('areaId is required');
      const areaType = typeof req.query.areaType === 'string' && req.query.areaType ? req.query.areaType : undefined;
      const typeName = typeof req.query.typeName === 'string' && req.query.typeName ? req.query.typeName : undefined;
      const areaName = typeof req.query.areaName === 'string' && req.query.areaName ? req.query.areaName : undefined;
      res.json(
        await backend.getCategoryRooms({ areaId, areaType, typeName, areaName }, listQueryOf(req.query)),
      );
    }),
  );

  // 4.6.4 GET /search/{platform}
  router.get(
    '/search/:platform',
    handler(async (req, res) => {
      const backend = requireListBackend(req.params.platform ?? '');
      const keyword = typeof req.query.keyword === 'string' ? req.query.keyword.trim() : '';
      if (!keyword) throw badRequest('keyword is required');
      res.json(await backend.searchRooms(keyword, listQueryOf(req.query)));
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
