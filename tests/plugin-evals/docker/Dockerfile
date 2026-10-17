# A Linux box for `claude plugin eval`. On macOS the eval sandbox stops Apple's git wrapper, so a
# review never gets a diff; here git is the real binary. Built and run by run.sh beside this file.
FROM node:22-bookworm-slim
ARG CLAUDE_CODE_VERSION=2.1.299
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates python3 bubblewrap socat \
 && rm -rf /var/lib/apt/lists/*
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && mkdir -p /work && chown node /work
USER node
# Identity for the scaffolds' commits comes from the environment, not a global config file.
ENV GIT_AUTHOR_NAME="keel plugin evals" GIT_AUTHOR_EMAIL="evals@keel.invalid" \
    GIT_COMMITTER_NAME="keel plugin evals" GIT_COMMITTER_EMAIL="evals@keel.invalid"
WORKDIR /work
