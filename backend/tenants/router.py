"""Database router: every query is sent to the current tenant's database.

If no tenant is bound the router raises instead of silently using a shared
database, so a bug can never leak or mix tenant data (fail closed).
"""
from django.conf import settings

from .context import get_current_tenant


class TenantNotBound(RuntimeError):
    """A tenant-scoped query was attempted with no tenant in context."""


class TenantRouter:
    def _alias(self):
        tenant = get_current_tenant()
        if tenant is None:
            raise TenantNotBound("No tenant bound to the current context")
        return tenant.alias

    def db_for_read(self, model, **hints):
        return self._alias()

    def db_for_write(self, model, **hints):
        return self._alias()

    def allow_relation(self, obj1, obj2, **hints):
        return obj1._state.db == obj2._state.db

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        # Tenant apps are migrated into every tenant database, never into default.
        return db in settings.TENANTS
