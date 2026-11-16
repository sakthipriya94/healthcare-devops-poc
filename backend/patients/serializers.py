from rest_framework import serializers

from .models import Patient


class PatientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Patient
        fields = ["id", "mrn", "first_name", "last_name", "date_of_birth", "created_at"]
        read_only_fields = ["id", "created_at"]

    def validate_mrn(self, value):
        # The default UniqueValidator would query through the router as well;
        # this keeps the message simple and explicit.
        qs = Patient.objects.filter(mrn=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("A patient with this MRN already exists.")
        return value
