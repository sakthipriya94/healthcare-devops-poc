"""Resolve the tenant for each request and bind it to the request context."""
import logging

from django.conf import settings
from django.http import JsonResponse

from .context import reset_current_tenant, set_current_tenant

logger = logging.getLogger(__name__)

# Endpoints that must work without a tenant (load balancer / container probes).
TENANT_EXEMPT_PATHS = ("/api/live/", "/api/health/")


def resolve_tenant(request):
    """Return the Tenant for this request, or None.

    1. Subdomain of the Host header (hospital-a.example.com -> "hospital-a").
       Exact host entries from the mapping file also match.
    2. X-Tenant-ID header, only when ALLOW_TENANT_HEADER is enabled (dev only).
    """
    tenants = settings.TENANTS.values()
    host = request.get_host().split(":")[0].lower()

    for t in tenants:
        if host in (h.lower() for h in t.hosts):
            return t
    sub = host.split(".")[0]
    for t in tenants:
        if t.subdomain == sub:
            return t

    if settings.ALLOW_TENANT_HEADER:
        wanted = request.headers.get("X-Tenant-ID", "").strip().lower()
        for t in tenants:
            if wanted in (t.id, t.subdomain):
                return t
    return None


class TenantMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path in TENANT_EXEMPT_PATHS:
            return self.get_response(request)

        tenant = resolve_tenant(request)
        if tenant is None:
            logger.warning("Unknown tenant for host=%s path=%s", request.get_host(), request.path)
            return JsonResponse({"detail": "Unknown tenant."}, status=404)

        request.tenant = tenant
        token = set_current_tenant(tenant)
        try:
            return self.get_response(request)
        finally:
            reset_current_tenant(token)
