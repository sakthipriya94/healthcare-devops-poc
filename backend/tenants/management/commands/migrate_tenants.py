from django.conf import settings
from django.core.management import call_command
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Run migrations against every tenant database (or one with --tenant)."

    def add_arguments(self, parser):
        parser.add_argument("--tenant", help="Only migrate this tenant id")

    def handle(self, *args, **opts):
        ids = [opts["tenant"]] if opts["tenant"] else list(settings.TENANTS)
        for tenant_id in ids:
            if tenant_id not in settings.TENANTS:
                raise SystemExit(f"Unknown tenant: {tenant_id}")
            self.stdout.write(f"Migrating tenant {tenant_id} ...")
            call_command("migrate", database=tenant_id, interactive=False, verbosity=0)
            self.stdout.write(self.style.SUCCESS(f"  {tenant_id}: done"))
