import uuid

from django.db import models


class Patient(models.Model):
    """Minimal sample record. Lives in the tenant's own database, so it carries
    no tenant foreign key: isolation comes from the database, not from a filter
    that a developer could forget to apply."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    mrn = models.CharField("Medical record number", max_length=32, unique=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    date_of_birth = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["last_name", "first_name"]

    def __str__(self):
        return f"{self.mrn} {self.last_name}, {self.first_name}"
