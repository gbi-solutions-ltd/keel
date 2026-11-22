# Static site

The app's production build served on its own origin by nginx, with the app's security headers on
every answer, for an app whose API is on another origin of the same site. How and when:
the engine's `skills/convert-mockup/references/api-integration.md`, "Another origin".

```bash
node scripts/headers.mjs <app>/security-headers.json --emit nginx \
  --env VITE_API_BASE_URL=<the API's base URL> > <somewhere>/headers.conf
APP_DIST=<app>/<build> HEADERS_CONF=<somewhere>/headers.conf docker compose -p <name> up -d
```

The container runs unprivileged: as nginx's own user (`101:101`), every capability dropped,
`no-new-privileges`, a read-only root with its writable paths on `tmpfs`. nginx then logs that the
`user` directive is ignored, which is harmless.
