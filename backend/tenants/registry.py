"""Tenant registry: loads the tenant -> database mapping.

The mapping file (database/tenants/tenants.json in the repo) holds only
NON-secret information: tenant id, subdomain, database name, database user,
and the *name* of the environment variable that holds the password.
Passwords are injected at runtime (local .env, or AWS Secrets Manager on the
server) and are never written to the repository.
"""
import json
import os
from dataclasses import dataclass, field
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured


@dataclass(frozen=True)
class Tenant:
    id: str
    name: str
    subdomain: str
    region: str = "ap-south-1"
    hosts: tuple = field(default_factory=tuple)

    @property
    def alias(self):
        """Django database alias for this tenant."""
        return self.id


def load_tenants(path):
    p = Path(path)
    if not p.exists():
        raise ImproperlyConfigured(f"Tenant mapping file not found: {p}")
    data = json.loads(p.read_text())
    tenants = {}
    for item in data["tenants"]:
        t = Tenant(
            id=item["id"],
            name=item["name"],
            subdomain=item["subdomain"],
            region=item.get("region", "ap-south-1"),
            hosts=tuple(item.get("hosts", [])),
        )
        t_db = item["db"]
        # Keep raw db config next to the tenant (not part of the dataclass so it
        # is never accidentally serialised into an API response).
        _DB_CONFIG[t.id] = t_db
        tenants[t.id] = t
    return tenants


_DB_CONFIG = {}


def build_databases(tenants, engine="postgres"):
    """Build Django's DATABASES dict with one alias per tenant."""
    if engine == "sqlite":
        # Used only by the automated tests / CI (no Postgres needed).
        databases = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}
        for t in tenants.values():
            databases[t.alias] = {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}
        return databases

    databases = {"default": {"ENGINE": "django.db.backends.dummy"}}
    for t in tenants.values():
        cfg = _DB_CONFIG[t.id]
        password = os.environ.get(cfg["password_env"], "")
        if not password:
            raise ImproperlyConfigured(
                f"Environment variable {cfg['password_env']} (DB password for tenant "
                f"{t.id}) is not set"
            )
        # Per-tenant host override makes regional databases possible: a tenant
        # in another region simply points host_env at a different variable.
        host = os.environ.get(cfg.get("host_env", "DB_HOST"), "")
        if not host:
            raise ImproperlyConfigured(
                f"Environment variable {cfg.get('host_env', 'DB_HOST')} is not set"
            )
        databases[t.alias] = {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": cfg["name"],
            "USER": cfg["user"],
            "PASSWORD": password,
            "HOST": host,
            "PORT": os.environ.get("DB_PORT", "5432"),
            "CONN_MAX_AGE": 60,
            "OPTIONS": {
                "sslmode": os.environ.get("DB_SSLMODE", "prefer"),
                "connect_timeout": 5,
            },
        }
    return databases
