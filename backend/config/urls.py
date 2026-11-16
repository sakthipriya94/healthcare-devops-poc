from django.urls import include, path

from tenants import views as tenant_views

urlpatterns = [
    path("api/live/", tenant_views.live, name="live"),
    path("api/health/", tenant_views.health, name="health"),
    path("api/tenant/", tenant_views.current_tenant, name="tenant"),
    path("api/", include("patients.urls")),
]
