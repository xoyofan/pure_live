// Walk pure_live-internal imports from the two site roots; flag Flutter/GetX edges.
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Repo root (this file lives in tool/sidecar/); overridable for foreign checkouts.
const ROOT = process.env.PURE_LIVE_ROOT ?? resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const BAD = /package:(flutter|get\/|easy_localization|hive_ce|hive|window_manager|path_provider|flutter_smart_dialog|permission_handler|share_handler|flv_lzc)/;

const start = [
  'lib/core/site/bilibili/bilibili_site.dart',
  'lib/core/site/douyin/douyin_site.dart',
];

function importsOf(file) {
  const src = readFileSync(`${ROOT}/${file}`, 'utf8');
  const out = [];
  for (const m of src.matchAll(/import\s+'([^']+)'/g)) {
    const spec = m[1];
    if (spec.startsWith('dart:')) continue;
    if (spec.startsWith('package:pure_live/')) {
      out.push({ spec, path: 'lib/' + spec.slice('package:pure_live/'.length) });
    } else if (spec.startsWith('package:')) {
      out.push({ spec, external: true, bad: BAD.test(spec), pkg: spec.split(':')[1].split('/')[0] });
    } else {
      const base = resolve(dirname(`${ROOT}/${file}`), spec).replaceAll(String.fromCharCode(92), '/').slice(ROOT.length + 1);
      out.push({ spec, path: base });
    }
  }
  return out;
}

const seen = new Set();
const externalPkgs = new Map();
const badEdges = [];
const queue = [...start];
const localFiles = [];

while (queue.length) {
  const f = queue.shift();
  if (seen.has(f)) continue;
  seen.add(f);
  localFiles.push(f);
  let imps;
  try { imps = importsOf(f); } catch (e) { badEdges.push(`${f}: READ-ERROR ${e.message}`); continue; }
  for (const i of imps) {
    if (i.external) {
      externalPkgs.set(i.pkg, (externalPkgs.get(i.pkg) ?? 0) + 1);
      if (i.bad) badEdges.push(`${f} -> ${i.spec}`);
    } else {
      queue.push(i.path);
    }
  }
}

console.log(`LOCAL closure: ${localFiles.length} files`);
console.log('\nEXTERNAL packages:');
for (const [p, c] of [...externalPkgs].sort((a, b) => b[1] - a[1])) console.log(`  ${p} x${c}`);
console.log(`\nBAD edges (flutter/getx/...): ${badEdges.length}`);
for (const e of badEdges) console.log('  ' + e);
console.log('\nLOCAL files:');
for (const f of localFiles.sort()) console.log('  ' + f);
