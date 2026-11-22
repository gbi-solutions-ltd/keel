/**
 * sample-backend.test.mjs: the engine's backend template and static site: exact pins and image
 * digests, a lockfile, no dev routes in the base compose file, ports on 127.0.0.1 only, the static
 * site unprivileged. That each example backend runs the template unchanged, and passes its own
 * tests on Postgres, is held by the proof suite (proof/sample-backend.test.mjs in the engine's
 * proving repository).
 * Run: node --test test/sample-backend.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ENGINE = fileURLToPath(new URL('../..', import.meta.url));
const TEMPLATE = join(ENGINE, 'templates/sample-backend');

test('the template pins every dependency and image to an exact version', () => {
  const pkg = JSON.parse(readFileSync(join(TEMPLATE, 'package.json'), 'utf8'));
  for (const [name, v] of Object.entries(pkg.dependencies)) assert.match(v, /^\d+\.\d+\.\d+$/, name);
  const images = [...readFileSync(join(TEMPLATE, 'docker-compose.yml'), 'utf8').matchAll(/image: (\S+)/g), ...readFileSync(join(TEMPLATE, 'Dockerfile'), 'utf8').matchAll(/^FROM (\S+)/gm)].map((m) => m[1]);
  assert.ok(images.length >= 3);
  for (const i of images) assert.match(i, /:v?\d+\.\d+[^@]*@sha256:[0-9a-f]{64}$/, `${i} has an exact version and a digest`);
  assert.ok(existsSync(join(TEMPLATE, 'package-lock.json')), 'the template has a lockfile, so its image builds the same tree');
});

test('the base compose file has no dev routes: they are only in docker-compose.dev.yml', () => {
  assert.doesNotMatch(readFileSync(join(TEMPLATE, 'docker-compose.yml'), 'utf8'), /^\s*DEV/m);
  assert.match(readFileSync(join(TEMPLATE, 'docker-compose.dev.yml'), 'utf8'), /DEV: "1"/);
});

test('the static site (an app on its own origin) pins its image and publishes on 127.0.0.1 only', () => {
  const compose = readFileSync(join(ENGINE, 'templates/static-site/docker-compose.yml'), 'utf8');
  const images = [...compose.matchAll(/image: (\S+)/g)].map((m) => m[1]);
  assert.equal(images.length, 1);
  assert.match(images[0], /:\d+\.\d+\.\d+[^@]*@sha256:[0-9a-f]{64}$/);
  const ports = [...compose.matchAll(/^\s*ports:.*$/gm)].flatMap((l) => [...l[0].matchAll(/"([^"]*:\d+)"/g)].map((m) => m[1]));
  assert.ok(ports.length >= 1);
  for (const p of ports) assert.match(p, /^127\.0\.0\.1:/, p);
  assert.match(readFileSync(join(ENGINE, 'templates/static-site/nginx.conf'), 'utf8'), /include \/etc\/nginx\/headers\.conf;[\s\S]*include \/etc\/nginx\/headers\.conf;/, 'headers in every location (add_header there replaces the server\'s)');
});

test('the static site runs unprivileged: no capabilities, no new privileges, not as root, read only', () => {
  const compose = readFileSync(join(ENGINE, 'templates/static-site/docker-compose.yml'), 'utf8');
  assert.match(compose, /^\s*cap_drop: \[ALL\]\s*$/m, 'every capability dropped');
  assert.doesNotMatch(compose, /cap_add/, 'none added back: it listens above 1024 and never switches user');
  assert.match(compose, /^\s*security_opt: \["no-new-privileges:true"\]\s*$/m);
  const user = compose.match(/^\s*user: "(\d+):(\d+)"\s*$/m);
  assert.ok(user && user[1] !== '0', 'a numeric user that is not root');
  assert.match(compose, /^\s*read_only: true\s*$/m);
  assert.match(readFileSync(join(ENGINE, 'templates/static-site/nginx.conf'), 'utf8'), /listen 8080;/, 'a port an unprivileged user may bind');
});

test('the API-only override serves no build: no mount, no static folder, no headers file', () => {
  const o = readFileSync(join(TEMPLATE, 'docker-compose.api-only.yml'), 'utf8');
  assert.match(o, /volumes: !reset \[\]/);
  assert.match(o, /STATIC_DIR: ""/);
  assert.match(o, /HEADERS_FILE: ""/);
});

test('the template publishes every port on 127.0.0.1 only', () => {
  const ports = [...readFileSync(join(TEMPLATE, 'docker-compose.yml'), 'utf8').matchAll(/"([^"]*:\d+)"/g)].map((m) => m[1]);
  assert.ok(ports.length >= 4);
  for (const p of ports) assert.match(p, /^127\.0\.0\.1:/, p);
});
