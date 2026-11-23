/**
 * browsers.mjs: the pinned browser, checked rather than trusted. Playwright checks its browser
 * download only for size (DEPENDENCIES.md), so the toolchain records a SHA-256 of the extracted
 * headless shell per platform (browsers.json, next to scripts/), measured from Playwright's own
 * download, and an install compares against it. The hash is over every file of the browser folder
 * (sorted paths, each with its own SHA-256), not only the binary: its libraries load too.
 * Playwright's own markers (INSTALLATION_COMPLETE, DEPENDENCIES_VALIDATED) sit outside that folder.
 *
 * Import-safe: no side effects.
 */
import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

export const MANIFEST = fileURLToPath(new URL('../../browsers.json', import.meta.url));

/** This machine's platform as Playwright names the headless shell's folder: mac-arm64, linux64. */
export function platformKey(platform = process.platform, arch = process.arch) {
  if (platform === 'darwin') return arch === 'arm64' ? 'mac-arm64' : 'mac-x64';
  if (platform === 'linux') return arch === 'arm64' ? 'linux-arm64' : 'linux64';
  if (platform === 'win32') return 'win64';
  return `${platform}-${arch}`;
}

/** The headless shell's folder under a browsers path, for the manifest's revision and this platform. */
export function shellFolder(browsersPath, revision, key = platformKey()) {
  return join(browsersPath, `chromium_headless_shell-${revision}`, `chrome-headless-shell-${key}`);
}

/** SHA-256 over a folder: each file's path and hash, sorted, one per line. */
export function folderHash(dir) {
  const files = [];
  const walk = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.isFile()) files.push(p);
    }
  };
  walk(dir);
  const lines = files.map((f) => `${relative(dir, f).split('\\').join('/')} ${createHash('sha256').update(readFileSync(f)).digest('hex')}`).sort();
  return { files: lines.length, sha256: createHash('sha256').update(`${lines.join('\n')}\n`).digest('hex') };
}

/**
 * Whether the browser under browsersPath is the one recorded: 'verified', 'mismatch' (with what was
 * found), 'unrecorded' (no hash for this platform: it runs, and says so), or 'missing'.
 */
export function verifyBrowser(browsersPath, manifest = JSON.parse(readFileSync(MANIFEST, 'utf8')), key = platformKey()) {
  const shell = manifest['chromium-headless-shell'];
  const dir = shellFolder(browsersPath, shell.revision, key);
  if (!existsSync(dir) || !statSync(dir).isDirectory()) return { status: 'missing', dir };
  const want = shell.platforms[key];
  if (!want) return { status: 'unrecorded', dir, key };
  const got = folderHash(dir);
  return got.sha256 === want.sha256 && got.files === want.files ? { status: 'verified', dir, key } : { status: 'mismatch', dir, key, got, want };
}
