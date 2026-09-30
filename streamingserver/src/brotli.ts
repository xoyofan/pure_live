/**
 * brotli-wasm loader for Node.
 *
 * The package's ESM entry points route to the web bundle, which fetches its
 * wasm asset and fails under Node. The CJS entry (index.node.js) loads
 * synchronously and works, so we reach it via createRequire. Types come from
 * the package's own d.ts.
 */
import { createRequire } from 'node:module';

type BrotliWasm = typeof import('brotli-wasm');

const nodeRequire = createRequire(import.meta.url);

/* eslint-disable @typescript-eslint/no-explicit-any */
const brotli = nodeRequire('brotli-wasm') as BrotliWasm;

const MAX_DECOMPRESSED_BYTES = 16 * 1024 * 1024;

/** Decompress a brotli frame; throws on malformed input or oversized output. */
export function brotliDecompress(data: Uint8Array): Uint8Array {
  const out = brotli.decompress(data) as Uint8Array;
  if (out.byteLength > MAX_DECOMPRESSED_BYTES) {
    throw new Error(`brotli output exceeds ${MAX_DECOMPRESSED_BYTES} bytes`);
  }
  return out;
}
