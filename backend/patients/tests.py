"""Tenant isolation tests. Run with TENANT_DB_ENGINE=sqlite (no Postgres needed)."""
import datetime

from django.conf import settings
from django.test import TransactionTestCase, override_settings
from rest_framework.test import APIClient

from patients.models import Patient
from tenants.context import tenant_context
from tenants.router import TenantNotBound

HOST_A = "hospital-a.localhost"
HOST_B = "hospital-b.localhost"


class TenantIsolationTests(TransactionTestCase):
    databases = "__all__"

    def setUp(self):
        self.client = APIClient()
        self.a = settings.TENANTS["hospital_a"]
        self.b = settings.TENANTS["hospital_b"]

    def _create(self, host, mrn, last="Test"):
        return self.client.post(
            "/api/patients/",
            {"mrn": mrn, "first_name": "T", "last_name": last, "date_of_birth": "1980-01-01"},
            format="json",
            HTTP_HOST=host,
        )

    def test_tenant_endpoint_identifies_tenant_from_subdomain(self):
        self.assertEqual(self.client.get("/api/tenant/", HTTP_HOST=HOST_A).json()["id"], "hospital_a")
        self.assertEqual(self.client.get("/api/tenant/", HTTP_HOST=HOST_B).json()["id"], "hospital_b")

    def test_data_is_stored_in_the_tenants_own_database(self):
        self.assertEqual(self._create(HOST_A, "A-1").status_code, 201)
        self.assertEqual(Patient.objects.using("hospital_a").count(), 1)
        self.assertEqual(Patient.objects.using("hospital_b").count(), 0)

    def test_tenant_b_cannot_list_tenant_a_data(self):
        self._create(HOST_A, "A-1", last="OnlyInA")
        listing = self.client.get("/api/patients/", HTTP_HOST=HOST_B).json()
        self.assertEqual(len(listing), 0)
        listing_a = self.client.get("/api/patients/", HTTP_HOST=HOST_A).json()
        self.assertEqual([p["last_name"] for p in listing_a], ["OnlyInA"])

    def test_tenant_b_cannot_fetch_update_or_delete_tenant_a_record_by_id(self):
        pid = self._create(HOST_A, "A-1").json()["id"]
        url = f"/api/patients/{pid}/"
        self.assertEqual(self.client.get(url, HTTP_HOST=HOST_B).status_code, 404)
        self.assertEqual(
            self.client.patch(url, {"last_name": "Hacked"}, format="json", HTTP_HOST=HOST_B).status_code,
            404,
        )
        self.assertEqual(self.client.delete(url, HTTP_HOST=HOST_B).status_code, 404)
        # still intact for the owner
        self.assertEqual(self.client.get(url, HTTP_HOST=HOST_A).json()["last_name"], "Test")

    def test_same_mrn_allowed_in_different_tenants(self):
        self.assertEqual(self._create(HOST_A, "SAME").status_code, 201)
        self.assertEqual(self._create(HOST_B, "SAME").status_code, 201)

    def test_unknown_host_is_rejected(self):
        resp = self.client.get("/api/patients/", HTTP_HOST="hospital-c.localhost")
        self.assertEqual(resp.status_code, 404)

    def test_tenant_header_is_ignored_unless_explicitly_enabled(self):
        resp = self.client.get("/api/patients/", HTTP_HOST="localhost", HTTP_X_TENANT_ID="hospital_a")
        self.assertEqual(resp.status_code, 404)
        with override_settings(ALLOW_TENANT_HEADER=True):
            resp = self.client.get("/api/patients/", HTTP_HOST="localhost", HTTP_X_TENANT_ID="hospital_a")
            self.assertEqual(resp.status_code, 200)

    def test_header_cannot_override_subdomain(self):
        with override_settings(ALLOW_TENANT_HEADER=True):
            self._create(HOST_A, "A-1")
            resp = self.client.get("/api/patients/", HTTP_HOST=HOST_B, HTTP_X_TENANT_ID="hospital_a")
            self.assertEqual(resp.json(), [])

    def test_query_without_tenant_fails_closed(self):
        with self.assertRaises(TenantNotBound):
            list(Patient.objects.all())

    def test_orm_context_manager_scopes_queries(self):
        with tenant_context(self.a):
            Patient.objects.create(
                mrn="X", first_name="a", last_name="b", date_of_birth=datetime.date(2000, 1, 1)
            )
            self.assertEqual(Patient.objects.count(), 1)
        with tenant_context(self.b):
            self.assertEqual(Patient.objects.count(), 0)


class HealthTests(TransactionTestCase):
    databases = "__all__"

    def test_live_needs_no_tenant(self):
        # Nginx rewrites Host to "localhost" for probe paths, so no tenant host is needed.
        self.assertEqual(APIClient().get("/api/live/", HTTP_HOST="localhost").status_code, 200)

    def test_health_reports_every_tenant_database(self):
        resp = APIClient().get("/api/health/", HTTP_HOST="localhost")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()["databases"], {"hospital_a": "up", "hospital_b": "up"})
