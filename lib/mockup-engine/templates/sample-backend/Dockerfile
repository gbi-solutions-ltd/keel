# The backend's image: production dependencies only, run as the unprivileged node user.
FROM node:24.20-alpine@sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf
WORKDIR /app
COPY package.json package-lock.json ./
# The install's settings as flags, so the image reads no npm config file: no package code runs,
# and an untested Node refuses before anything installs.
RUN npm ci --omit=dev --ignore-scripts --engine-strict --no-audit --no-fund
# Everything but what .dockerignore leaves out (dependencies, tests, .env).
COPY . .
USER node
ENV NODE_ENV=production HOST=0.0.0.0 PORT=4300
EXPOSE 4300
HEALTHCHECK --interval=5s --timeout=3s --retries=10 CMD wget -qO- http://127.0.0.1:4300/healthz || exit 1  # supply-chain-scan: allow the container's own health check, against its loopback port
CMD ["node", "server.mjs"]
