# syntax=docker/dockerfile:1
# Build context: repository root.

# ---- Stage 1: build the React bundle ----
FROM node:22-alpine AS build
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

# ---- Stage 2: serve static files with unprivileged nginx ----
FROM nginxinc/nginx-unprivileged:1.31-alpine AS runtime
# Pull in fixed OS packages that landed after the base image was built (keeps the Trivy gate green).
USER root
RUN apk upgrade --no-cache
USER 101
COPY nginx/frontend.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/ >/dev/null || exit 1
