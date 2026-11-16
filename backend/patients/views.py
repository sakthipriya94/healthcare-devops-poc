from rest_framework import viewsets

from .models import Patient
from .serializers import PatientSerializer


class PatientViewSet(viewsets.ModelViewSet):
    # No tenant filter here on purpose: the router sends the query to the
    # current tenant's database, so only that tenant's rows can ever be seen.
    queryset = Patient.objects.all()
    serializer_class = PatientSerializer
