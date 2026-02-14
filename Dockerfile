# Stage 1: prepare packages
FROM --platform=$BUILDPLATFORM dhi.io/node:24.13.1-alpine3.23-sfw-dev@sha256:57af8405bdcd14b746cb7f6c9a8edfacfa38e0504d1d6a87fe5da08aeeaeac44 AS packages
WORKDIR /app
COPY backstage.json package.json yarn.lock ./
COPY .yarn ./.yarn
COPY .yarnrc.yml ./
COPY packages packages
COPY plugins plugins
RUN find packages \! -name "package.json" -mindepth 2 -maxdepth 2 -exec rm -rf {} \+

# Stage 2: build the packages
FROM --platform=$BUILDPLATFORM dhi.io/node:24.13.1-alpine3.23-sfw-dev@sha256:57af8405bdcd14b746cb7f6c9a8edfacfa38e0504d1d6a87fe5da08aeeaeac44 AS build-packages
ENV PYTHON=/usr/bin/python3
RUN apk add --no-cache g++ make python3 sqlite-dev && rm -rf /var/lib/apk/lists/*
RUN apk add --no-cache sqlite-dev && rm -rf /var/lib/apk/lists/*
WORKDIR /app
COPY --from=packages --chown=node:node /app .
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn install --immutable
COPY --chown=node:node . .
RUN yarn tsc
RUN yarn --cwd packages/backend build
RUN mkdir packages/backend/dist/skeleton packages/backend/dist/bundle \
    && tar xzf packages/backend/dist/skeleton.tar.gz -C packages/backend/dist/skeleton \
    && tar xzf packages/backend/dist/bundle.tar.gz -C packages/backend/dist/bundle

# Stage 3: build the application
FROM --platform=$BUILDPLATFORM dhi.io/node:24.13.1-alpine3.23-sfw-dev@sha256:57af8405bdcd14b746cb7f6c9a8edfacfa38e0504d1d6a87fe5da08aeeaeac44 AS build-app
ENV PYTHON=/usr/bin/python3
RUN apk add --no-cache g++ make python3 && rm -rf /var/lib/apk/lists/*
RUN apk add --no-cache sqlite-dev && rm -rf /var/lib/apk/lists/*
WORKDIR /app
COPY --from=build-packages --chown=node:node /app/.yarn ./.yarn
COPY --from=build-packages --chown=node:node /app/.yarnrc.yml  ./
COPY --from=build-packages --chown=node:node /app/backstage.json ./
COPY --from=build-packages --chown=node:node /app/yarn.lock /app/package.json /app/packages/backend/dist/skeleton/ ./
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn workspaces focus --all --production && rm -rf "$(yarn cache clean)"

# Final Stage: create the runtime image
FROM demonstrationorg/dhi-node:24.13.1-alpine3.23_backstage2@sha256:d2cc5a3d8865c1d042b2c84884bc739b5dd08437449a671fb55dc96329a3afac
ENV PYTHON=/opt/python/bin/python3
WORKDIR /app
COPY --from=build-packages --chown=node:node /app/packages/backend/dist/bundle/ ./
COPY --from=build-app --chown=node:node /app/node_modules/ ./node_modules
COPY --chown=node:node app-config*.yaml ./
COPY --chown=node:node examples ./examples
ENV NODE_ENV=production
ENV NODE_OPTIONS="--no-node-snapshot"
USER node
CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
