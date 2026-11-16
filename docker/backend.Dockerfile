# syntax=docker/dockerfile:1
# Build context: repository root.

# ---- Stage 1: build wheels (keeps compilers/caches out of the final image) ----
FROM python:3.13-slim AS builder
WORKDIR /build
COPY backend/requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ---- Stage 2: minimal runtime ----
FROM python:3.13-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Apply fixed OS packages released after the base image was built, and a current pip
# (keeps the Trivy HIGH/CRITICAL gate green without ignoring findings).
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir --upgrade pip

# Non-root user
RUN groupadd --system app && useradd --system --gid app --home /app --shell /usr/sbin/nologin app
WORKDIR /app

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* && rm -rf /wheels

COPY backend/ /app/
# Non-secret tenant -> database mapping (passwords come from env at runtime)
COPY database/tenants/tenants.json /app/tenants.json
COPY docker/backend-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && chown -R app:app /app

USER app
EXPOSE 8000

# Liveness only (does not depend on the database). Host header is "localhost"
# which is always in ALLOWED_HOSTS.
HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request as u; u.urlopen(u.Request('http://127.0.0.1:8000/api/live/', headers={'Host': 'localhost'}), timeout=2)" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--access-logfile", "-", "--error-logfile", "-"]
