from django.conf import settings
from django.db import connections
from django.http import JsonResponse


def live(request):
    """Liveness: the process is up. Used by Docker HEALTHCHECK and the ALB."""
    return JsonResponse({"status": "ok"})


def health(request):
    """Readiness: checks connectivity to every tenant database.

    Returns 503 if any database is unreachable. Used by the post-deployment
    health check and monitoring. Only reports up/down - never connection details.
    """
    results = {}
    for tenant in settings.TENANTS.values():
        try:
            with connections[tenant.alias].cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
            results[tenant.id] = "up"
        except Exception:  # noqa: BLE001 - report any failure as 'down'
            results[tenant.id] = "down"
    ok = all(v == "up" for v in results.values())
    return JsonResponse(
        {"status": "ok" if ok else "degraded", "databases": results},
        status=200 if ok else 503,
    )


def current_tenant(request):
    t = request.tenant
    return JsonResponse({"id": t.id, "name": t.name, "region": t.region})
