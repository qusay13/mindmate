import hashlib, secrets
from accounts.models import User, UserSession
from django.utils import timezone

u = User.objects.get(email='patient_depression@mindmate.test')
raw = secrets.token_hex(32)
token_hash = hashlib.sha256(raw.encode()).hexdigest()
UserSession.objects.filter(user=u).delete()
UserSession.objects.create(user=u, token=token_hash, expires_at=timezone.now() + timezone.timedelta(days=7))
print(raw)
