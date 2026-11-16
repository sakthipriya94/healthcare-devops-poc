"""Request-scoped 'current tenant' using contextvars (safe across threads/async)."""
from contextlib import contextmanager
from contextvars import ContextVar

_current = ContextVar("current_tenant", default=None)


def get_current_tenant():
    return _current.get()


def set_current_tenant(tenant):
    return _current.set(tenant)


def reset_current_tenant(token):
    _current.reset(token)


@contextmanager
def tenant_context(tenant):
    token = set_current_tenant(tenant)
    try:
        yield tenant
    finally:
        reset_current_tenant(token)
