import { useEffect, useRef } from 'react';
import type { MutableRefObject } from 'react';
import type { DanmakuChatItem } from '../hooks/useDanmaku';

interface ActiveItem {
  text: string;
  x: number;
  y: number;
  /** Total px to cross (container width at spawn + text width); speed is
   * derived per frame so duration changes rescale in-flight items too. */
  travel: number;
  width: number;
  color: string;
}

interface Props {
  /** Live queue produced by useDanmaku; drained every animation frame. */
  chatQueueRef: MutableRefObject<DanmakuChatItem[]>;
  /** When true no new danmaku is spawned (existing ones scroll out). */
  muted: boolean;
  /** Seconds for a message to cross the canvas. */
  durationSec?: number;
  /** Multiplier on the 20px base font size (1 = unchanged). */
  fontSizeScale?: number;
  /** Overall overlay opacity, 0.2 ~ 1 (1 = unchanged). */
  opacity?: number;
  /** Fraction of the canvas height used by tracks (0.25 ~ 1); messages render in the top band only. */
  areaRatio?: number;
  /** Dark text outline; false renders plain colored text. */
  stroke?: boolean;
}

const ROW_HEIGHT = 34;
const MAX_SPAWN_PER_FRAME = 3;
const TRACK_GAP_PX = 24;
/** Small horizontal jitter so simultaneous messages do not look machine-stacked. */
const JITTER_PX = 40;

const TEXT_COLORS = ['#ffffff', '#ffe082', '#80d8ff', '#ccff90', '#f8bbd0', '#b388ff'];

/**
 * Canvas overlay rendering scrolling chat comments (right -> left).
 * Messages whose text would collide with the previous one in every track are
 * dropped, which together with the queue cap bounds memory and paint cost.
 */
export default function DanmakuCanvas({
  chatQueueRef,
  muted,
  durationSec = 9,
  fontSizeScale = 1,
  opacity = 1,
  areaRatio = 1,
  stroke = true,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mutedRef = useRef(muted);
  mutedRef.current = muted;
  // Latest-value refs for the preference props: slider changes take effect on
  // the next frame without restarting the effect, which would wipe in-flight
  // messages (item speed is derived from travel / duration each frame, so a
  // duration change rescales everything already on screen).
  const durationRef = useRef(durationSec);
  durationRef.current = durationSec;
  const fontScaleRef = useRef(fontSizeScale);
  fontScaleRef.current = fontSizeScale;
  const opacityRef = useRef(opacity);
  opacityRef.current = opacity;
  const areaRatioRef = useRef(areaRatio);
  areaRatioRef.current = areaRatio;
  const strokeRef = useRef(stroke);
  strokeRef.current = stroke;

  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width = container.clientWidth;
    let height = container.clientHeight;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);

    const resize = () => {
      width = container.clientWidth;
      height = container.clientHeight;
      canvas.width = Math.max(1, Math.round(width * dpr));
      canvas.height = Math.max(1, Math.round(height * dpr));
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(container);

    const items: ActiveItem[] = [];
    let raf = 0;
    let last = performance.now();
    let colorIndex = 0;

    // Track count follows the visible band (canvas height x areaRatio) and is
    // read per frame, so the area slider takes effect without restarting the
    // effect (which would wipe in-flight messages).
    const activeTrackCount = () =>
      Math.max(1, Math.floor((height * areaRatioRef.current) / ROW_HEIGHT));
    // Right edge of the newest item per track; a track is free when there is
    // room for a new message between it and the right side of the canvas.
    const trackTailX: number[] = [];
    trackTailX.length = activeTrackCount();
    trackTailX.fill(Number.POSITIVE_INFINITY);

    const spawn = (item: DanmakuChatItem) => {
      const label =
        item.text.length > 40 ? `${item.text.slice(0, 40)}…` : item.text;
      const fontSize = 20 * fontScaleRef.current;
      ctx.font = `${fontSize}px system-ui, "Microsoft YaHei", sans-serif`;
      const textWidth = ctx.measureText(label).width;
      const trackCount = activeTrackCount();
      const freeTracks: number[] = [];
      for (let t = 0; t < trackCount; t++) {
        // Free if the previous message has already cleared enough of the right side.
        if ((trackTailX[t] ?? Number.POSITIVE_INFINITY) + TRACK_GAP_PX <= width) freeTracks.push(t);
      }
      if (freeTracks.length === 0) return; // all tracks busy -> drop this message
      const track = freeTracks[Math.floor(Math.random() * freeTracks.length)];
      const x = width + Math.random() * JITTER_PX;
      items.push({
        text: label,
        x,
        y: track * ROW_HEIGHT + ROW_HEIGHT / 2 + 6,
        travel: width + textWidth,
        width: textWidth,
        color: TEXT_COLORS[colorIndex],
      });
      trackTailX[track] = x + textWidth;
      colorIndex = (colorIndex + 1) % TEXT_COLORS.length;
    };

    const frame = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.1);
      last = now;

      // Consume at most MAX_SPAWN_PER_FRAME messages per frame so a large
      // backlog (capped by the hook) does not produce a burst of identical-x rows.
      if (!mutedRef.current) {
        for (let i = 0; i < MAX_SPAWN_PER_FRAME; i++) {
          const next = chatQueueRef.current.shift();
          if (!next) break;
          spawn(next);
        }
      }

      ctx.clearRect(0, 0, width, height);
      ctx.globalAlpha = opacityRef.current;
      ctx.font = `${20 * fontScaleRef.current}px system-ui, "Microsoft YaHei", sans-serif`;
      ctx.textBaseline = 'middle';
      ctx.lineWidth = 3;
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.55)';

      for (let i = items.length - 1; i >= 0; i--) {
        const item = items[i];
        item.x -= (item.travel / durationRef.current) * dt;
        if (item.x + item.width < 0) {
          items.splice(i, 1);
          continue;
        }
        // Shrinking the area retires in-flight messages below the new band.
        if (item.y > height * areaRatioRef.current) {
          items.splice(i, 1);
          continue;
        }
        if (strokeRef.current) ctx.strokeText(item.text, item.x, item.y);
        ctx.fillStyle = item.color;
        ctx.fillText(item.text, item.x, item.y);
      }

      // Recompute track tails from live items for accurate spawn decisions.
      const trackCount = activeTrackCount();
      trackTailX.length = trackCount;
      trackTailX.fill(Number.POSITIVE_INFINITY);
      for (const item of items) {
        const track = Math.min(trackCount - 1, Math.max(0, Math.floor((item.y - 6 - ROW_HEIGHT / 2) / ROW_HEIGHT)));
        trackTailX[track] = Math.min(trackTailX[track], item.x + item.width);
      }

      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(raf);
      observer.disconnect();
      items.length = 0;
      chatQueueRef.current = [];
    };
  }, [chatQueueRef]); // pref props flow through refs above, not this dep list

  return (
    <div ref={containerRef} className="danmaku-overlay" aria-hidden="true">
      <canvas ref={canvasRef} />
    </div>
  );
}
