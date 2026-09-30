import { useCallback, useEffect, useRef, useState } from 'react';
import { getPlayUrls, getQualities, getRecommendRooms, protocolOfUrl, resolveRoom, toPlaybackUrl } from '../api/client';
import { formatWatching } from '../lib/format';
import { isApiError } from '../api/types';
import type { PlayUrls, Quality, Room, RoomListItem } from '../api/types';
import { useDanmaku } from '../hooks/useDanmaku';
import DanmakuCanvas from '../components/DanmakuCanvas';
import Player, { type PlaybackSource } from '../components/Player';
import * as followStore from '../lib/followStore';
import type { FollowEntry } from '../lib/followStore';

interface Props {
  platform: string;
  roomId: string;
  onLeave: () => void;
  /** Open another room from the side-panel recommend list. */
  onOpenRoom: (platform: string, roomId: string) => void;
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

export default function RoomPage({ platform, roomId, onLeave, onOpenRoom }: Props) {
  const [phase, setPhase] = useState<ResolvePhase>({ kind: 'loading' });
  const [qualities, setQualities] = useState<Quality[]>([]);
  const [currentQuality, setCurrentQuality] = useState<string | null>(null);
  const [play, setPlay] = useState<PlayUrls | null>(null);
  const [playLoading, setPlayLoading] = useState(false);
  const [playError, setPlayError] = useState<string | null>(null);
  const [playbackError, setPlaybackError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [danmakuMuted, setDanmakuMuted] = useState(false);
  /** CDN line index within the current play.urls list (0-based). */
  const [line, setLine] = useState(0);
  /** Mirrors the video element state for the custom transport bar. */
  const [videoPaused, setVideoPaused] = useState(false);
  const [videoMuted, setVideoMuted] = useState(true);
  const [videoVolume, setVideoVolume] = useState(1);

  const playSeqRef = useRef(0);
  const resolveSeqRef = useRef(0);
  const autoRecoveryUsedRef = useRef(false);
  const qualityRef = useRef<string | null>(null);
  const currentQualityIdRef = useRef<string | null>(null);
  const autoRecoverTimerRef = useRef<number | null>(null);
  const stageRef = useRef<HTMLDivElement | null>(null);

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
        setLine(0);
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
          const url = toPlaybackUrl(play, line);
          return url ? { url, protocol: play.protocol, nonce } : null;
        })()
      : null;

  const [sideTab, setSideTab] = useState<'chat' | 'follow' | 'recommend' | 'settings'>('chat');
  const [sideCollapsed, setSideCollapsed] = useState(false);
  const [follows, setFollows] = useState<FollowEntry[]>(() => followStore.listFollows());
  const followed = followStore.isFollowed(platform, roomId);
  const superFollowed = follows.some((e) => e.platform === platform && e.roomId === roomId && e.isSpecial);
  const [recommendRooms, setRecommendRooms] = useState<RoomListItem[]>([]);
  const [recommendLoading, setRecommendLoading] = useState(false);
  const chatListRef = useRef<HTMLDivElement | null>(null);
  const chatStuckRef = useRef(true);

  // Follow the chat tail unless the user scrolled up to read history.
  useEffect(() => {
    const node = chatListRef.current;
    if (!node || sideTab !== 'chat') return;
    if (chatStuckRef.current) node.scrollTop = node.scrollHeight;
  }, [danmaku.chatList, sideTab]);

  // Recommend list loads once per room when its tab first opens. The guard is
  // a ref (not state): under StrictMode's double-mount the first run's
  // cleanup must not leave the second run deadlocked on a stale loading flag.
  const recommendFetchRef = useRef(false);
  useEffect(() => {
    setRecommendRooms([]);
    setRecommendLoading(false);
    recommendFetchRef.current = false;
  }, [platform, roomId]);

  useEffect(() => {
    if (sideTab !== 'recommend' || recommendFetchRef.current) return;
    recommendFetchRef.current = true;
    setRecommendLoading(true);
    getRecommendRooms(platform, 1, 20)
      .then((res) => {
        setRecommendRooms((res.rooms ?? []).filter((r) => r.roomId !== roomId));
      })
      .catch(() => {
        setRecommendRooms([]);
      })
      .finally(() => {
        recommendFetchRef.current = false;
        setRecommendLoading(false);
      });
  }, [sideTab, platform, roomId]);

  const reloadStream = () => setNonce((n) => n + 1);

  const videoOf = () => stageRef.current?.querySelector('video') ?? null;

  // Mirror the media element's play/pause + volume state so the transport
  // bar reflects reality even when the browser flips muted-autoplay.
  useEffect(() => {
    if (!source) return;
    const video = videoOf();
    if (!video) return;
    const sync = () => {
      setVideoPaused(video.paused);
      setVideoMuted(video.muted);
      setVideoVolume(video.volume);
    };
    sync();
    video.addEventListener('play', sync);
    video.addEventListener('pause', sync);
    video.addEventListener('volumechange', sync);
    return () => {
      video.removeEventListener('play', sync);
      video.removeEventListener('pause', sync);
      video.removeEventListener('volumechange', sync);
    };
  }, [source]);

  const togglePlay = () => {
    const video = videoOf();
    if (!video) return;
    if (video.paused) void video.play().catch(() => {});
    else video.pause();
  };

  const changeVolume = (value: number) => {
    const video = videoOf();
    if (!video) return;
    video.volume = value;
    video.muted = value === 0;
  };

  const toggleMute = () => {
    const video = videoOf();
    if (!video) return;
    video.muted = !video.muted;
  };

  const toggleFollow = () => {
    if (followed) setFollows(followStore.removeFollow(platform, roomId));
    else if (room) setFollows(followStore.addFollow({ ...room, platform, roomId }));
  };

  const toggleSuperFollow = () => {
    if (!followed && room) setFollows(followStore.addFollow({ ...room, platform, roomId }));
    setFollows(followStore.toggleSpecial(platform, roomId));
  };

  const toggleFullscreen = () => {
    const stage = stageRef.current;
    if (!stage) return;
    if (document.fullscreenElement) void document.exitFullscreen();
    else void stage.requestFullscreen().catch(() => {});
  };

  const togglePip = async () => {
    const video = stageRef.current?.querySelector('video');
    if (!video) return;
    try {
      if (document.pictureInPictureElement) await document.exitPictureInPicture();
      else await video.requestPictureInPicture();
    } catch {
      /* PiP unsupported or rejected */
    }
  };

  const coverNode = (
    <div className="cover">
      {room?.cover ? (
        <img
          src={room.cover}
          alt="直播间封面"
          referrerPolicy="no-referrer"
          onError={(e) => {
            e.currentTarget.style.display = 'none';
          }}
        />
      ) : null}
      <div className="cover-placeholder">暂无封面</div>
    </div>
  );

  // --- render ----------------------------------------------------------------
  return (
    <div className="room">
      <div className="play-header">
        <button type="button" className="btn-ghost" onClick={onLeave}>
          ← 返回
        </button>
        {room?.liveStatus === 'live' && <span className="live-flag">直播</span>}
        <span className="play-title">{room?.title || `${platform} ${roomId}`}</span>
        {phase.kind === 'ok' && (
          <button
            type="button"
            className="btn-ghost side-toggle"
            title={sideCollapsed ? '展开侧栏' : '收起侧栏'}
            onClick={() => setSideCollapsed((c) => !c)}
          >
            {sideCollapsed ? '«' : '»'}
          </button>
        )}
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
            <div className="player-stage" ref={stageRef}>
              {coverNode}
              {source && <Player source={source} onError={handlePlayerError} onStall={handleStall} onPlaying={handlePlaying} />}
              {playable && source && <DanmakuCanvas chatQueueRef={danmaku.chatQueueRef} muted={danmakuMuted} />}
              {room && !playable && (
                <div className="player-state">
                  <p className="banner banner-state">{liveStatusText(room.liveStatus)}</p>
                </div>
              )}
              {playable && source && (
                <div className="player-controls">
                  <div className="controls-group">
                    <button type="button" className="ctrl-btn" title={videoPaused ? '播放' : '暂停'} onClick={togglePlay}>
                      {videoPaused ? '▶' : '❚❚'}
                    </button>
                    <button
                      type="button"
                      className={`ctrl-btn${videoMuted || videoVolume === 0 ? ' off' : ''}`}
                      title={videoMuted || videoVolume === 0 ? '取消静音' : '静音'}
                      onClick={toggleMute}
                    >
                      声
                    </button>
                    <input
                      type="range"
                      className="volume-slider"
                      min={0}
                      max={1}
                      step={0.05}
                      value={videoMuted ? 0 : videoVolume}
                      onChange={(e) => changeVolume(Number(e.target.value))}
                      title="音量"
                    />
                    <span className="live-mini-badge">直播</span>
                  </div>
                  <div className="controls-group controls-spacer" />
                  <div className="controls-group">
                    <button type="button" className="ctrl-btn" title="刷新播放" onClick={reloadStream}>
                      ↻
                    </button>
                    <button
                      type="button"
                      className={`ctrl-btn${danmakuMuted ? ' off' : ''}`}
                      title={danmakuMuted ? '开启弹幕' : '关闭弹幕'}
                      onClick={() => setDanmakuMuted((m) => !m)}
                    >
                      弹
                    </button>
                    <button type="button" className="ctrl-btn" title="画中画" onClick={() => void togglePip()}>
                      画
                    </button>
                    <button type="button" className="ctrl-btn" title="网页全屏" onClick={toggleFullscreen}>
                      全
                    </button>
                  </div>
                </div>
              )}
            </div>

            {playable && (qualities.length > 0 || (play?.urls.length ?? 0) > 1) && (
              <div className="play-chips-row">
                {qualities.map((q) => (
                  <button
                    key={q.selectionId}
                    type="button"
                    className={`ctrl-chip${q.selectionId === currentQuality ? ' active' : ''}`}
                    onClick={() => selectQuality(q.selectionId)}
                  >
                    {q.label}
                  </button>
                ))}
                {(play?.urls ?? []).length > 1 &&
                  (play?.urls ?? []).map((_, index) => (
                    <button
                      key={`line${index}`}
                      type="button"
                      className={`ctrl-chip${index === line ? ' active' : ''}`}
                      onClick={() => setLine(index)}
                    >
                      {`线路${index + 1}${(() => {
                        const proto = protocolOfUrl(play?.urls[index] ?? '');
                        return proto === 'unknown' ? '' : ` ${proto.toUpperCase()}`;
                      })()}`}
                    </button>
                  ))}
              </div>
            )}

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
                <button type="button" className="btn-small" onClick={reloadStream}>
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
          </div>

          <aside className="play-side" hidden={sideCollapsed}>
            <div className="side-header">
              {room.avatar ? (
                <img className="avatar" src={room.avatar} alt="" referrerPolicy="no-referrer" />
              ) : (
                <div className="avatar placeholder" />
              )}
              <div className="side-header-info">
                <p className="nick">
                  <span className={`dot dot-${danmaku.status}`} title={danmakuStatusText(danmaku.status) ?? ''} />
                  {room.nick || '未知主播'}
                </p>
                <p className="watching">
                  {viewerText ? `${formatWatching(viewerText)} 人气` : ''}
                  {Number(room.followers ?? '') > 0 ? ` · ${formatWatching(room.followers ?? '')} 粉丝` : ''}
                  {liveStatusText(room.liveStatus) ? ' · 未开播' : ''}
                </p>
                {room.introduction ? (
                  <p className="side-intro" title={room.introduction.replace(/<[^>]*>/g, '')}>
                    {room.introduction.replace(/<[^>]*>/g, '')}
                  </p>
                ) : null}
              </div>
              <div className="side-follow-btns">
                <button
                  type="button"
                  className={`follow-btn${followed ? ' on' : ''}`}
                  onClick={toggleFollow}
                >
                  ♥ {followed ? '已关注' : '关注'}
                </button>
                <button
                  type="button"
                  className={`follow-btn super${superFollowed ? ' on' : ''}`}
                  onClick={toggleSuperFollow}
                >
                  超关
                </button>
              </div>
            </div>

            <div className="side-tabs">
              <button
                type="button"
                className={`side-tab${sideTab === 'chat' ? ' active' : ''}`}
                onClick={() => setSideTab('chat')}
              >
                聊天
              </button>
              <button
                type="button"
                className={`side-tab${sideTab === 'follow' ? ' active' : ''}`}
                onClick={() => setSideTab('follow')}
              >
                关注
              </button>
              <button
                type="button"
                className={`side-tab${sideTab === 'recommend' ? ' active' : ''}`}
                onClick={() => setSideTab('recommend')}
              >
                推荐
              </button>
              <button
                type="button"
                className={`side-tab${sideTab === 'settings' ? ' active' : ''}`}
                onClick={() => setSideTab('settings')}
              >
                设置
              </button>
            </div>

            {sideTab === 'chat' ? (
              <>
                <div className="chat-status-row">
                  <span className={`dot dot-${danmaku.status}`} />
                  <span className="chat-status-text">
                    {danmakuStatusText(danmaku.status) ?? '弹幕未连接'}
                  </span>
                  <button
                    type="button"
                    className="ctrl-btn ghost"
                    title="重新连接弹幕"
                    onClick={() => danmaku.reconnect?.()}
                  >
                    ↻
                  </button>
                </div>
                <div
                  className="chat-list"
                  ref={chatListRef}
                  onScroll={(e) => {
                    const node = e.currentTarget;
                    chatStuckRef.current = node.scrollHeight - node.scrollTop - node.clientHeight < 40;
                  }}
                >
                  {danmaku.chatList.length === 0 && (
                    <p className="danmaku-empty">
                      {playable ? '还没有弹幕,来说点什么…' : '房间未开播,弹幕服务未连接'}
                    </p>
                  )}
                  {danmaku.chatList.map((item, index) => (
                    <p key={index} className="chat-item">
                      <span className="chat-user">{item.userName}:</span>
                      <span className="chat-text">{item.text}</span>
                    </p>
                  ))}
                </div>
              </>
            ) : sideTab === 'follow' ? (
              <div className="recommend-list">
                {follows.length === 0 && <p className="danmaku-empty">还没有关注的直播间</p>}
                {follows.map((entry) => (
                  <button
                    key={`${entry.platform}:${entry.roomId}`}
                    type="button"
                    className="recommend-item"
                    onClick={() => onOpenRoom(entry.platform, entry.roomId)}
                  >
                    {entry.cover ? (
                      <img
                        src={entry.cover}
                        alt=""
                        loading="lazy"
                        referrerPolicy="no-referrer"
                        onError={(e) => {
                          e.currentTarget.style.visibility = 'hidden';
                        }}
                      />
                    ) : null}
                    <span className="recommend-item-info">
                      <span className="recommend-item-title">
                        {entry.isSpecial ? '★ ' : ''}
                        {entry.title || entry.nick}
                      </span>
                      <span className="recommend-item-meta">{entry.nick}</span>
                    </span>
                  </button>
                ))}
              </div>
            ) : sideTab === 'recommend' ? (
              <div className="recommend-list">
                {recommendLoading && <p className="danmaku-empty">正在获取推荐…</p>}
                {!recommendLoading && recommendRooms.length === 0 && (
                  <p className="danmaku-empty">暂时没有推荐房间</p>
                )}
                {recommendRooms.map((room) => (
                  <button
                    key={`${room.platform}:${room.roomId}`}
                    type="button"
                    className="recommend-item"
                    onClick={() => onOpenRoom(room.platform || platform, room.roomId)}
                  >
                    {room.cover ? (
                      <img
                        src={room.cover}
                        alt=""
                        loading="lazy"
                        referrerPolicy="no-referrer"
                        onError={(e) => {
                          e.currentTarget.style.visibility = 'hidden';
                        }}
                      />
                    ) : null}
                    <span className="recommend-item-info">
                      <span className="recommend-item-title">{room.title || room.nick}</span>
                      <span className="recommend-item-meta">
                        {room.nick}
                        {room.watching ? ` · ${room.watching}` : ''}
                      </span>
                    </span>
                  </button>
                ))}
              </div>
            ) : (
              <div className="side-settings">
                <label className="settings-row">
                  <span>弹幕</span>
                  <button
                    type="button"
                    className={`switch${danmakuMuted ? ' off' : ''}`}
                    onClick={() => setDanmakuMuted((m) => !m)}
                  >
                    {danmakuMuted ? '关闭' : '开启'}
                  </button>
                </label>
                <p className="settings-hint">弹幕状态:{danmakuStatusText(danmaku.status) ?? '未连接'}</p>
              </div>
            )}
          </aside>
        </div>
      )}
    </div>
  );
}
