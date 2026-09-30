/**
 * Theme mode (dark default, persisted) — zishu keeps a topbar dark/light
 * toggle; light tokens live in styles.css under html[data-theme='light'].
 */

export type ThemeMode = 'dark' | 'light';

const KEY = 'purelive.theme.v1';

export function readTheme(): ThemeMode {
  try {
    return localStorage.getItem(KEY) === 'light' ? 'light' : 'dark';
  } catch {
    return 'dark';
  }
}

export function applyTheme(mode: ThemeMode): void {
  document.documentElement.dataset.theme = mode;
  try {
    localStorage.setItem(KEY, mode);
  } catch {
    // storage unavailable — theme stays session-local
  }
}

export function toggleTheme(mode: ThemeMode): ThemeMode {
  const next: ThemeMode = mode === 'dark' ? 'light' : 'dark';
  applyTheme(next);
  return next;
}
