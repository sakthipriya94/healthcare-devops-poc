import logging

from .context import get_current_tenant


class TenantLogFilter(logging.Filter):
    """Adds tenant=<id> to every log line so logs can be filtered per tenant."""

    def filter(self, record):
        t = get_current_tenant()
        record.tenant = t.id if t else "-"
        return True
