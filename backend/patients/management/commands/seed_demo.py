import datetime

from django.conf import settings
from django.core.management.base import BaseCommand

from patients.models import Patient
from tenants.context import tenant_context

# Deliberately different data per tenant so isolation is easy to see.
DEMO = {
    "hospital_a": [
        ("A-1001", "Asha", "Raman", datetime.date(1985, 3, 14)),
        ("A-1002", "Vikram", "Iyer", datetime.date(1972, 11, 2)),
    ],
    "hospital_b": [
        ("B-2001", "Meera", "Nair", datetime.date(1990, 7, 21)),
        ("B-2002", "Karthik", "Reddy", datetime.date(1964, 1, 30)),
    ],
}


class Command(BaseCommand):
    help = "Insert fictional demo patients into each tenant database (idempotent)."

    def handle(self, *args, **opts):
        for tenant_id, rows in DEMO.items():
            tenant = settings.TENANTS.get(tenant_id)
            if tenant is None:
                continue
            with tenant_context(tenant):
                for mrn, first, last, dob in rows:
                    Patient.objects.get_or_create(
                        mrn=mrn,
                        defaults={"first_name": first, "last_name": last, "date_of_birth": dob},
                    )
            self.stdout.write(self.style.SUCCESS(f"Seeded {tenant_id}"))
