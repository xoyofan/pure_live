import { useEffect, useRef } from 'react';
import mpegts from 'mpegts.js';
import Hls from 'hls.js';
import type { Protocol } from '../api/types';

export interface PlaybackSource {
  url: string;
  protocol: Protocol;
  /** Bumped to force a player rebuild with the same URL (retry). */
  nonce: number;
}

interface Props {
  source: PlaybackSource | null;
  /** Fatal player error -> room shows a retryable banner. */
  onError: (message: string) => void;
  /** Buffering stall -> room may auto re-fetch play-urls once (streams expire). */
  onStall: () => void;
  /** Playback actually started -> room cancels the pending auto re-fetch. */
  onPlaying: () => void;
  /** Fires on loadedmetadata/resize with the video orientation. */
  onOrientation?: (orientation: 'landscape' | 'portrait') => void;
}

/**
 * Playback for one resolved source. The player engine is chosen by the
 * contract `protocol` field and rebuilt whenever url/protocol/nonce changes,
 * so quality switches swap the source without a page reload.
 */
export default function Player({ source, onError, onStall, onPlaying, onOrientation }: Props) {
  const videoRef = useRef<HTMLVideoElement | null>(null);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !source) return;

    let disposed = false;
    let mpegtsPlayer: mpegts.Player | null = null;
    let hls: Hls | null = null;
    const cleanupFns: Array<() => void> = [];

    const tryPlay = () => {
      // Autoplay with sound can be rejected by browser policy; fall back to muted.
      video.play().catch(() => {
        video.muted = true;
        video.play().catch(() => {
          /* user can press play via native controls */
        });
      });
    };

    const reportOrientation = () => {
      if (!onOrientation || video.videoWidth === 0) return;
      onOrientation(video.videoHeight > video.videoWidth ? 'portrait' : 'landscape');
    };

    const bindMediaEvents = () => {
      const onWaiting = () => onStall();
      const onStalled = () => onStall();
      const onPlayingEvt = () => onPlaying();
      video.addEventListener('loadedmetadata', reportOrientation);
      video.addEventListener('resize', reportOrientation);
      video.addEventListener('waiting', onWaiting);
      video.addEventListener('stalled', onStalled);
      video.addEventListener('playing', onPlayingEvt);
      cleanupFns.push(() => {
        video.removeEventListener('loadedmetadata', reportOrientation);
        video.removeEventListener('resize', reportOrientation);
        video.removeEventListener('waiting', onWaiting);
        video.removeEventListener('stalled', onStalled);
        video.removeEventListener('playing', onPlayingEvt);
      });
    };

    const attachPlainVideo = () => {
      video.src = source.url;
      video.addEventListener('error', () => {
        if (!disposed) onError('视频加载失败,可能播放地址已过期');
      });
      cleanupFns.push(() => {
        video.removeAttribute('src');
        video.load();
      });
      tryPlay();
    };

    const attachMpegts = () => {
      if (!mpegts.getFeatureList().mseLivePlayback) {
        onError('当前浏览器不支持 MSE 直播播放');
        return;
      }
      mpegtsPlayer = mpegts.createPlayer(
        { type: 'flv', isLive: true, url: source.url },
        { enableStashBuffer: false, liveBufferLatencyChasing: true, autoCleanupSourceBuffer: true },
      );
      mpegtsPlayer.attachMediaElement(video);
      mpegtsPlayer.load();
      mpegtsPlayer.on(mpegts.Events.ERROR, (errorType, detail, info) => {
        if (disposed) return;
        const reason =
          info && typeof info === 'object' && 'msg' in info && typeof info.msg === 'string'
            ? info.msg
            : String(detail ?? errorType);
        onError(`直播流播放出错(${reason}),可能地址已过期`);
      });
      cleanupFns.push(() => {
        try {
          mpegtsPlayer?.pause();
          mpegtsPlayer?.unload();
          mpegtsPlayer?.detachMediaElement();
          mpegtsPlayer?.destroy();
        } catch {
          /* player already torn down */
        }
      });
      tryPlay();
    };

    const attachHls = () => {
      if (Hls.isSupported()) {
        hls = new Hls({ lowLatencyMode: true, backBufferLength: 30 });
        hls.attachMedia(video);
        hls.loadSource(source.url);
        hls.on(Hls.Events.ERROR, (_event, data) => {
          if (!disposed && data.fatal) {
            onError(`HLS 播放出错(${data.details}),可能地址已过期`);
          }
        });
        cleanupFns.push(() => {
          hls?.destroy();
          hls = null;
        });
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        // Safari / native HLS.
        video.src = source.url;
        video.addEventListener('error', () => {
          if (!disposed) onError('HLS 播放出错,可能地址已过期');
        });
        cleanupFns.push(() => {
          video.removeAttribute('src');
          video.load();
        });
      } else {
        onError('当前浏览器不支持 HLS 播放');
        return;
      }
      tryPlay();
    };

    bindMediaEvents();
    if (source.protocol === 'flv') attachMpegts();
    else if (source.protocol === 'hls') attachHls();
    else attachPlainVideo(); // mp4 / unknown

    return () => {
      disposed = true;
      for (const fn of cleanupFns) fn();
      cleanupFns.length = 0;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [source?.url, source?.protocol, source?.nonce]);

  if (!source) return null;
  return (
    <div className="player-box">
      <video ref={videoRef} autoPlay playsInline className="player-video" />
    </div>
  );
}
