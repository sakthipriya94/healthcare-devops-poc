"""Django settings for the multi-tenant healthcare POC.

All environment-specific values and every secret come from environment
variables. Nothing sensitive lives in this repository.

Tenancy model: one PostgreSQL database per tenant. The non-secret
tenant -> database mapping lives in a JSON file (see tenants/registry.py);
passwords are read from environment variables named in that file.
"""
import os
from pathlib import Path

from tenants.registry import build_databases, load_tenants

BASE_DIR = Path(__file__).resolve().parent.parent


def env_bool(name, default=False):
    return os.environ.get(name, str(default)).strip().lower() in ("1", "true", "yes")


DEBUG = env_bool("DJANGO_DEBUG", False)

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "")
if not SECRET_KEY:
    if DEBUG:
        SECRET_KEY = "insecure-dev-only-key"
    else:
        raise RuntimeError("DJANGO_SECRET_KEY must be set when DJANGO_DEBUG is false")

ALLOWED_HOSTS = [
    h.strip()
    for h in os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,.localhost").split(",")
    if h.strip()
]

# Tenant identification ------------------------------------------------------
# Subdomain based (hospital-a.example.com). The X-Tenant-ID header is a
# convenience for local development / curl only and MUST stay off in prod,
# otherwise a client could pick any tenant.
ALLOW_TENANT_HEADER = env_bool("ALLOW_TENANT_HEADER", False)
TENANTS_FILE = os.environ.get("TENANTS_FILE", str(BASE_DIR / "tenants.json"))
TENANTS = load_tenants(TENANTS_FILE)

INSTALLED_APPS = [
    "django.contrib.staticfiles",
    "rest_framework",
    "tenants",
    "patients",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.common.CommonMiddleware",
    "tenants.middleware.TenantMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

# Every tenant gets its own database alias. "default" is intentionally unusable
# in real deployments so a missing tenant can never fall through to some
# shared database.
DATABASES = build_databases(
    TENANTS,
    engine=os.environ.get("TENANT_DB_ENGINE", "postgres"),
)
DATABASE_ROUTERS = ["tenants.router.TenantRouter"]

REST_FRAMEWORK = {
    # POC: no end-user auth. Production would add per-tenant authentication
    # (e.g. OIDC / JWT with a tenant claim checked against the resolved tenant).
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.AllowAny"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "UNAUTHENTICATED_USER": None,
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
USE_TZ = True
TIME_ZONE = "UTC"
STATIC_URL = "static/"

# Security hardening when running behind the reverse proxy / ALB over HTTPS
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env_bool("DJANGO_SECURE_SSL_REDIRECT", False)
SECURE_REDIRECT_EXEMPT = [r"^api/live/$"]  # health probes arrive over plain HTTP
SECURE_CONTENT_TYPE_NOSNIFF = True
SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "plain": {"format": "%(asctime)s %(levelname)s %(name)s tenant=%(tenant)s %(message)s"},
    },
    "filters": {"tenant": {"()": "tenants.logging.TenantLogFilter"}},
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "plain", "filters": ["tenant"]},
    },
    "root": {"handlers": ["console"], "level": os.environ.get("LOG_LEVEL", "INFO")},
}
