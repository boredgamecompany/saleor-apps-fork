ARG NODE_VERSION=22

# 1. Alpine image
FROM node:${NODE_VERSION}-alpine AS alpine

RUN apk update
RUN apk add --no-cache libc6-compat build-base \
gcc autoconf automake zlib-dev libpng-dev \
nasm vips-dev


# 2. Base image
FROM alpine AS base

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

RUN corepack enable pnpm

RUN pnpm config set store-dir /pnpm/store
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm fetch


# 3. Build the project
FROM base AS builder
ARG PROJECT

WORKDIR /workspace

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

COPY ./packages/ ./packages/
COPY ./apps/${PROJECT}/ ./apps/${PROJECT}/

RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --filter=saleor-app-$PROJECT... --frozen-lockfile --prefer-offline
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm --filter=saleor-app-$PROJECT build --no-lint


FROM base AS runner
ARG PROJECT
ARG VERSION

# Install nginx and supervisor
RUN apk add --no-cache nginx supervisor

RUN addgroup --system --gid 1001 nextjs
RUN adduser --system --uid 1001 nextjs

ENV NODE_ENV=production

WORKDIR /workspace

COPY --from=builder --chown=nextjs:nextjs /workspace/apps/${PROJECT}/.next/standalone ./
COPY --from=builder --chown=nextjs:nextjs /workspace/apps/${PROJECT}/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nextjs /workspace/apps/${PROJECT}/public ./public

# Copy and setup nginx configuration
RUN mkdir -p /etc/nginx/sites-enabled
COPY ./docker/nginx.conf /etc/nginx/http.d/default.conf

# Copy supervisor template and generate actual config using bash
RUN mkdir -p /etc/supervisor/conf.d
COPY ./docker/supervisord.conf.tpl /tmp/supervisord.conf.tpl
RUN sed "s/{{PROJECT}}/${PROJECT}/g; s/{{NODE_ENV}}/${NODE_ENV}/g; s/{{VERSION}}/${VERSION}/g" \
    /tmp/supervisord.conf.tpl > /etc/supervisor/conf.d/supervisord.conf

# RUN pnpx @sentry/cli sourcemaps inject --release $VERSION ./build

RUN echo "VERSION=$VERSION" > ./.env
RUN echo "PUBLIC_VERSION=$VERSION" >> ./.env
RUN echo "NODE_ENV=${NODE_ENV}" >> ./.env
RUN echo "PUBLIC_NODE_ENV=${NODE_ENV}" >> ./.env

# Fix permissions
RUN chown -R nextjs:nextjs /workspace
RUN chmod -R 755 /workspace/.next/static /workspace/public

EXPOSE 8081

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
