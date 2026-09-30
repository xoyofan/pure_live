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
