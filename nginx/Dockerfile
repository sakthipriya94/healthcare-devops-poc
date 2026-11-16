# Reverse proxy in front of the frontend and backend containers.
# Build context: repository root.
FROM nginxinc/nginx-unprivileged:1.31-alpine
# Pull in fixed OS packages that landed after the base image was built (keeps the Trivy gate green).
USER root
RUN apk upgrade --no-cache
USER 101
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/nginx-health >/dev/null || exit 1
