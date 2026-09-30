// Generates a trimmed package_config for the parsing sidecar build:
// only the pure-Dart packages in the sidecar closure, no Flutter/native
// build-hook packages (dart compile refuses those).
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const src = JSON.parse(readFileSync('.dart_tool/package_config.json', 'utf8'));

// Sidecar closure external deps (+ their pure-Dart transitive deps).
const KEEP = new Set([
  'pure_live',
  'crypto',
  'dio',
  'meta',
  'web_socket_channel',
  'protobuf',
  'brotli',
  'logger',
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
]);

const packages = src.packages.filter((p) => KEEP.has(p.name));
const missing = [...KEEP].filter((n) => !packages.some((p) => p.name === n) && n !== 'source_span' && n !== 'term_glyph');
if (missing.length) console.log('note: not present in host config (ok if unused):', missing.join(', '));

mkdirSync('.dart_tool', { recursive: true });
writeFileSync('.dart_tool/sidecar_package_config.json', JSON.stringify({ ...src, packages }, null, 2));
console.log(`sidecar package_config: ${packages.length} packages -> .dart_tool/sidecar_package_config.json`);
for (const p of packages) console.log('  ' + p.name);
