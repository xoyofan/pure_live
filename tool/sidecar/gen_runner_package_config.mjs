// Generates tool/sidecar/runner/.dart_tool/package_config.json for the
// standalone sidecar exe build: the pure-Dart closure only, with absolute
// rootUris so the runner directory needs no pub get.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const HOST_CONFIG = resolve('.dart_tool/package_config.json');
const hostDir = resolve(HOST_CONFIG, '..');
const src = JSON.parse(readFileSync(HOST_CONFIG, 'utf8'));

const KEEP = new Set([
  'pure_live',
  'crypto',
  'dio',
  'meta',
  'web_socket_channel',
  'web_socket',
  'protobuf',
  'brotli',
  'logger',
  'clock',
  'dart_sm',
  'pointycastle',
  'async',
  'collection',
  'convert',
  'http_parser',
  'string_scanner',
  'fixnum',
  'stream_channel',
  'typed_data',
  'path',
  'source_span',
  'term_glyph',
  'mime',
]);

function absoluteUri(rootUri) {
  // A rootUri without a trailing slash loses its last segment when resolved
  // against; always normalize to a directory URL first.
  const root = rootUri.startsWith('file:')
    ? new URL(rootUri)
    : new URL(rootUri, pathToFileURL(hostDir + '/').href);
  return root.href.endsWith('/') ? root.href : root.href + '/';
}

const packages = src.packages
  .filter((p) => KEEP.has(p.name))
  .map((p) => ({
    name: p.name,
    rootUri: absoluteUri(p.rootUri),
    packageUri: p.packageUri ?? 'lib/',
    languageVersion: p.languageVersion,
  }));

const missing = [...KEEP].filter((n) => !packages.some((p) => p.name === n));
if (missing.length) console.log('note: absent from host config:', missing.join(', '));

mkdirSync('tool/sidecar/runner/.dart_tool', { recursive: true });
writeFileSync(
  'tool/sidecar/runner/.dart_tool/package_config.json',
  JSON.stringify({ configVersion: 2, generator: 'pure_live-sidecar', packages }, null, 2),
);
console.log(`runner package_config: ${packages.length} packages`);
