/**
 * Display formatting helpers — mirror the Flutter app's audience-number
 * rendering (万/亿 compaction) so cards read like the app.
 */

/** "18225374" -> "1822.5万"; "1.2万" passes through; non-numeric -> raw. */
export function formatWatching(watching: string): string {
  const raw = (watching ?? '').trim();
  if (!/^\d+(\.\d+)?$/.test(raw)) return raw;
  const n = Number(raw);
  if (!Number.isFinite(n)) return raw;
  if (n >= 1e8) return `${(n / 1e8).toFixed(1)}亿`;
  if (n >= 1e4) return `${(n / 1e4).toFixed(1)}万`;
  return String(Math.round(n));
}

/** Blank or all-zero count ("", "0", "0.00"): nothing worth displaying. */
function isBlankOrZero(raw: string): boolean {
  return raw === '' || /^0+(\.0+)?$/.test(raw);
}

/** Audience number to render plus its unit label (人气 = heat, 观看 = head count). */
export interface AudienceMetric {
  value: string;
  label: string;
}

/**
 * Pick the audience number for a room: totalViewers (cumulative head count)
 * wins over the legacy `watching`; the label follows the room's
 * audienceMetricType (viewer counts read 观看, the rest read 人气).
 * A blank or all-zero count ("0") means the platform supplies no real
 * head count — the value comes back '' so callers hide the metric.
 */
export function audienceDisplay(room: {
  watching?: string;
  totalViewers?: string;
  audienceMetricType?: string;
}): AudienceMetric {
  const totalViewers = (room.totalViewers ?? '').trim();
  const raw = totalViewers || (room.watching ?? '').trim();
  // totalViewers 有值即累计观看数,无条件读 观看(旧行为);其余按
  // audienceMetricType 判定。
  const label =
    totalViewers ||
    room.audienceMetricType === 'totalViewers' ||
    room.audienceMetricType === 'onlineViewers'
      ? '观看'
      : '人气';
  if (isBlankOrZero(raw)) return { value: '', label };
  return { value: formatWatching(raw), label };
}
