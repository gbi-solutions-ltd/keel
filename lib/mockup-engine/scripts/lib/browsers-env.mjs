/**
 * browsers-env.mjs: imported first by every script that launches a browser, before playwright,
 * which reads PLAYWRIGHT_BROWSERS_PATH once when it loads. In an installed toolchain (a copy of the
 * engine with its own browsers/ folder beside scripts/, toolchain.mjs --install) the browser is
 * that folder's, the one the install verified, never the machine's shared cache. Anywhere else
 * (the engine's own repository) nothing changes. A path set by the caller wins.
 */
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const own = fileURLToPath(new URL('../../browsers', import.meta.url));
if (!process.env.PLAYWRIGHT_BROWSERS_PATH && existsSync(own)) process.env.PLAYWRIGHT_BROWSERS_PATH = own;
