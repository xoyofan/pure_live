import { useCallback, useEffect, useRef, useState } from 'react';
import { getPlayUrls, getQualities, resolveRoom, toPlaybackUrl } from '../api/client';
import { isApiError } from '../api/types';
import type { PlayUrls, Quality, Room } from '../api/types';
import { useDanmaku } from '../hooks/useDanmaku';
import DanmakuCanvas from '../components/DanmakuCanvas';
import Player, { type PlaybackSource } from '../components/Player';

interface Props {
  platform: string;
  roomId: string;
  onLeave: () => void;
}

type ResolvePhase =
  | { kind: 'loading' }
  | { kind: 'error'; message: string }
  | { kind: 'ok'; room: Room };

/** Stall duration before the single automatic play-urls re-fetch kicks in. */
const AUTO_RECOVER_DELAY_MS = 5_000;

function describeApiError(err: unknown, fallback: string): string {
  if (isApiError(err)) {
    switch (err.code) {
      case 'NETWORK':
        return '无法连接解析服务,请确认解析服务已启动';
      case 'ROOM_NOT_FOUND':
        return '房间不存在,请检查房间号';
      case 'ROOM_CLOSED':
        return '房间已下线或被封禁';
      case 'PLATFORM_UNSUPPORTED':
        return '暂不支持该平台';
      case 'UNAUTHORIZED':
        return '服务端鉴权失败';
      case 'BAD_REQUEST':
        return '请求参数错误';
      case 'UPSTREAM_ERROR':
      case 'UPSTREAM_TIMEOUT':
        return '上游平台响应异常,请稍后重试';
      case 'INTERNAL':
      case 'PARSE':
        return '服务内部异常,请稍后重试';
      default:
        return err.message || fallback;
    }
  }
  return fallback;
}

function liveStatusText(liveStatus: Room['liveStatus']): string | null {
  switch (liveStatus) {
    case 'offline':
      return '主播当前未开播';
    case 'banned':
      return '房间已被封禁';
    case 'replay':
      return '当前为回放状态,暂不支持观看';
    default:
      return null; // live / unknown: try to play
  }
}

function formatViewers(value: number): string {
  if (value >= 10000) return `${(value / 10000).toFixed(1)}万`;
  return String(Math.round(value));
}

function danmakuStatusText(status: ReturnType<typeof useDanmaku>['status']): string | null {
  switch (status) {
    case 'idle':
      return null;
    case 'connecting':
      return '弹幕连接中';
    case 'connected':
      return '弹幕已连接';
    case 'reconnecting':
      return '弹幕重连中…';
    case 'closed':
      return '弹幕连接已关闭';
    case 'error':
      return '弹幕连接异常';
    default:
      return null;
  }
}

export default function RoomPage({ platform, roomId, onLeave }: Props) {
  const [phase, setPhase] = useState<ResolvePhase>({ kind: 'loading' });
  const [qualities, setQualities] = useState<Quality[]>([]);
  const [currentQuality, setCurrentQuality] = useState<string | null>(null);
  const [play, setPlay] = useState<PlayUrls | null>(null);
  const [playLoading, setPlayLoading] = useState(false);
  const [playError, setPlayError] = useState<string | null>(null);
  const [playbackError, setPlaybackError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [danmakuMuted, setDanmakuMuted] = useState(false);

  const playSeqRef = useRef(0);
  const resolveSeqRef = useRef(0);
  const autoRecoveryUsedRef = useRef(false);
  const qualityRef = useRef<string | null>(null);
  const currentQualityIdRef = useRef<string | null>(null);
  const autoRecoverTimerRef = useRef<number | null>(null);

  // --- resolve -------------------------------------------------------------
  useEffect(() => {
    const seq = ++resolveSeqRef.current;
    setPhase({ kind: 'loading' });
    setQualities([]);
    setCurrentQuality(null);
    currentQualityIdRef.current = null;
    qualityRef.current = null;
    setPlay(null);
    setPlayError(null);
    setPlaybackError(null);
    setNonce(0);
    autoRecoveryUsedRef.current = false;

    let disposed = false;
    resolveRoom(platform, roomId)
      .then((res) => {
        if (disposed || seq !== resolveSeqRef.current) return;
        setPhase({ kind: 'ok', room: res.room });
      })
      .catch((err: unknown) => {
        if (disposed || seq !== resolveSeqRef.current) return;
        const message = describeApiError(err, '房间信息获取失败');
        setPhase({ kind: 'error', message });
      });
    return () => {
      disposed = true;
    };
  }, [platform, roomId]);

  // --- qualities + default play-urls once the room is live -----------------
  const room = phase.kind === 'ok' ? phase.room : null;
  const playable = room !== null && liveStatusText(room.liveStatus) === null;

  const loadPlayUrls = useCallback(
    async (qualityId: string | null, mode: 'manual' | 'auto') => {
      const seq = ++playSeqRef.current;
      setPlayLoading(true);
      setPlayError(null);
      setPlaybackError(null);
      if (mode === 'manual') autoRecoveryUsedRef.current = false;
      try {
        const res = await getPlayUrls(platform, {
          roomId,
          quality: qualityId ?? undefined,
          withHeaders: true,
        });
        if (seq !== playSeqRef.current) return;
        setPlay(res);
        setCurrentQuality(res.quality);
        currentQualityIdRef.current = res.quality;
        setNonce((n) => n + 1);
        if (mode === 'auto') autoRecoveryUsedRef.current = true;
      } catch (err: unknown) {
        if (seq !== playSeqRef.current) return;
        setPlay(null);
        setPlayError(describeApiError(err, '获取播放地址失败'));
      } finally {
        if (seq === playSeqRef.current) setPlayLoading(false);
      }
    },
    [platform, roomId],
  );

  useEffect(() => {
    if (!playable) return;
    let disposed = false;
    getQualities(platform, roomId)
      .then((res) => {
        if (disposed) return;
        const list = res.qualities ?? [];
        setQualities(list);
        const remembered = qualityRef.current;
        const preferred =
          remembered && list.some((q) => q.selectionId === remembered)
            ? remembered
            : list[0]?.selectionId ?? null;
        qualityRef.current = preferred;
        void loadPlayUrls(preferred, 'manual');
      })
      .catch(() => {
        if (disposed) return;
        // Qualities are optional for playback: fall back to default quality.
        void loadPlayUrls(null, 'manual');
      });
    return () => {
      disposed = true;
    };
  }, [playable, platform, roomId, loadPlayUrls]);

  const selectQuality = (selectionId: string) => {
    if (selectionId === currentQualityIdRef.current) return;
    qualityRef.current = selectionId;
    setCurrentQuality(selectionId);
    void loadPlayUrls(selectionId, 'manual');
  };

  // --- stream expiry: one automatic re-fetch on persistent stall -----------
  const clearAutoRecoverTimer = () => {
    if (autoRecoverTimerRef.current !== null) {
      window.clearTimeout(autoRecoverTimerRef.current);
      autoRecoverTimerRef.current = null;
    }
  };

  const handlePlaying = useCallback(() => {
    clearAutoRecoverTimer();
  }, []);

  const handleStall = useCallback(() => {
    if (autoRecoveryUsedRef.current) return;
    if (autoRecoverTimerRef.current !== null) return;
    autoRecoverTimerRef.current = window.setTimeout(() => {
      autoRecoverTimerRef.current = null;
      if (!autoRecoveryUsedRef.current) {
        void loadPlayUrls(currentQualityIdRef.current, 'auto');
      }
    }, AUTO_RECOVER_DELAY_MS);
  }, [loadPlayUrls]);

  useEffect(() => clearAutoRecoverTimer, []);

  const handlePlayerError = useCallback((message: string) => {
    clearAutoRecoverTimer();
    setPlaybackError(message);
  }, []);

  // --- danmaku --------------------------------------------------------------
  const danmaku = useDanmaku(playable ? platform : null, playable ? roomId : null);

  const viewerText =
    danmaku.onlineValue !== null
      ? formatViewers(danmaku.onlineValue)
      : room?.watching || '';

  const source: PlaybackSource | null =
    play !== null && playable
      ? (() => {
          const url = toPlaybackUrl(play);
          return url ? { url, protocol: play.protocol, nonce } : null;
        })()
      : null;

  // --- render ----------------------------------------------------------------
  const coverNode = (
    <div className="cover">
      {room?.cover ? (
        <img
          src={room.cover}
          alt="直播间封面"
          onError={(e) => {
            e.currentTarget.style.display = 'none';
          }}
        />
      ) : null}
      <div className="cover-placeholder">暂无封面</div>
    </div>
  );

  return (
    <div className="room">
      <div className="room-topbar">
        <button type="button" className="btn-ghost" onClick={onLeave}>
          ← 返回
        </button>
        {room && <span className="room-crumb">{room.title || `${platform} ${roomId}`}</span>}
      </div>

      {phase.kind === 'loading' && <p className="banner">正在获取房间信息…</p>}

      {phase.kind === 'error' && (
        <div className="room-state">
          <p className="banner banner-error">{phase.message}</p>
          <button type="button" className="btn-primary" onClick={onLeave}>
            返回首页
          </button>
        </div>
      )}

      {phase.kind === 'ok' && room && (
        <div className="room-grid">
          <div className="player-col">
            <div className="player-stage">
              {coverNode}
              {source && <Player source={source} onError={handlePlayerError} onStall={handleStall} onPlaying={handlePlaying} />}
              {room && !playable && (
                <div className="player-state">
                  <p className="banner banner-state">{liveStatusText(room.liveStatus)}</p>
                </div>
              )}
            </div>

            {playLoading && <p className="banner">正在获取播放地址…</p>}
            {playError && (
              <div className="banner banner-error">
                <span>{playError}</span>
                <button
                  type="button"
                  className="btn-small"
                  onClick={() => void loadPlayUrls(currentQuality ?? currentQualityIdRef.current, 'manual')}
                >
                  重试
                </button>
              </div>
            )}
            {playbackError && (
              <div className="banner banner-error">
                <span>{playbackError}</span>
                <button
                  type="button"
                  className="btn-small"
                  onClick={() => setNonce((n) => n + 1)}
                >
                  重新加载
                </button>
                <button
                  type="button"
                  className="btn-small"
                  onClick={() => void loadPlayUrls(currentQualityIdRef.current, 'manual')}
                >
                  重新获取地址
                </button>
              </div>
            )}

            {qualities.length > 0 && (
              <div className="quality-bar">
                <span className="quality-label">清晰度</span>
                {qualities.map((q) => (
                  <button
                    key={q.selectionId}
                    type="button"
                    className={`btn-chip${q.selectionId === currentQuality ? ' active' : ''}`}
                    onClick={() => selectQuality(q.selectionId)}
                  >
                    {q.label}
                  </button>
                ))}
              </div>
            )}
          </div>

          <aside className="danmaku-col">
            <div className="room-meta">
              {room.avatar ? <img className="avatar" src={room.avatar} alt="" /> : null}
              <div>
                <p className="nick">{room.nick || '未知主播'}</p>
                <p className="watching">
                  {viewerText ? `观看 ${viewerText}` : ''}
                  {liveStatusText(room.liveStatus) ? ' · 未开播' : ''}
                </p>
              </div>
            </div>

            <div className="danmaku-toolbar">
              <span className={`dot dot-${danmaku.status}`} />
              <span className="danmaku-status">
                {danmakuStatusText(danmaku.status)}
                {danmaku.statusMessage ? `(${danmaku.statusMessage})` : ''}
              </span>
              <button
                type="button"
                className="btn-chip"
                onClick={() => setDanmakuMuted((m) => !m)}
              >
                {danmakuMuted ? '弹幕已屏蔽' : '弹幕开启'}
              </button>
            </div>

            <div className="danmaku-panel">
              {playable ? (
                <DanmakuCanvas chatQueueRef={danmaku.chatQueueRef} muted={danmakuMuted} />
              ) : (
                <p className="danmaku-empty">房间未开播,弹幕服务未连接</p>
              )}
            </div>
          </aside>
        </div>
      )}
    </div>
  );
}
