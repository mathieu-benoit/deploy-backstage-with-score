# Stage 1: prepare packages
FROM --platform=$BUILDPLATFORM demonstrationorg/dhi-node:24-alpine3.23-sfw-dev_backstage@sha256:d857c21f05b1088e6e2c05ba308d3e4afcffb055cecb8e8ab947cae2d0dfecdd AS packages
WORKDIR /app
COPY backstage.json package.json yarn.lock ./
COPY .yarn ./.yarn
COPY .yarnrc.yml ./
COPY packages packages
COPY plugins plugins
RUN find packages \! -name "package.json" -mindepth 2 -maxdepth 2 -exec rm -rf {} \+

# Stage 2: build the packages
FROM --platform=$BUILDPLATFORM demonstrationorg/dhi-node:24-alpine3.23-sfw-dev_backstage@sha256:d857c21f05b1088e6e2c05ba308d3e4afcffb055cecb8e8ab947cae2d0dfecdd AS build-packages
ENV PYTHON=/opt/python/bin/python3
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
FROM --platform=$BUILDPLATFORM demonstrationorg/dhi-node:24-alpine3.23-sfw-dev_backstage@sha256:d857c21f05b1088e6e2c05ba308d3e4afcffb055cecb8e8ab947cae2d0dfecdd AS build-app
ENV PYTHON=/opt/python/bin/python3
WORKDIR /app
COPY --from=build-packages --chown=node:node /app/.yarn ./.yarn
COPY --from=build-packages --chown=node:node /app/.yarnrc.yml  ./
COPY --from=build-packages --chown=node:node /app/backstage.json ./
COPY --from=build-packages --chown=node:node /app/yarn.lock /app/package.json /app/packages/backend/dist/skeleton/ ./
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn workspaces focus --all --production && rm -rf "$(yarn cache clean)"

# Final Stage: create the runtime image
FROM demonstrationorg/dhi-node:24-alpine3.23_backstage@sha256:fb53c36dbc891459e0f430db9cd9193035a5d815b64a0f7236153e60f4c102b8
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
