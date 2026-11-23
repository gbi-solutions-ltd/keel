/**
 * serve.mjs: a read-only static server for a mockup folder on 127.0.0.1 and a free port, so pages
 * load over HTTP (fetch and localStorage behave as in a browser, unlike file://). Used by every
 * script that loads the mockup: visual-diff.mjs (every mode), check-behaviours.mjs,
 * quality-check.mjs, dom-oracle.mjs, inventory.mjs and spill-check.mjs. A malformed percent escape
 * in a URL is a 400.
 */
import { readFileSync, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { join, normalize, extname, resolve, sep } from 'node:path';

const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.woff2': 'font/woff2', '.woff': 'font/woff' };

/** Resolves to { server, base } once listening; base has no trailing slash. */
export function serveMockup(dir) {
  const root = resolve(dir);
  const server = createServer((req, res) => {
    let path;
    // A malformed escape (%zz) is that request's fault: 400, and the server keeps serving
    try { path = decodeURIComponent(new URL(req.url, 'http://x').pathname); } catch { res.writeHead(400).end(); return; }
    if (path.endsWith('/')) path += 'index.html';
    const file = normalize(join(root, path));
    if (!file.startsWith(root + sep) || !existsSync(file) || statSync(file).isDirectory()) { res.writeHead(404).end(); return; }
    res.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' }).end(readFileSync(file));
  });
  return new Promise((r) => server.listen(0, '127.0.0.1', () => r({ server, base: `http://127.0.0.1:${server.address().port}` })));
}
