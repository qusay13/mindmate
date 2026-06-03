import os
from celery import Celery

# Set default Django settings module for celery
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('mindmate')

# Load task config from Django settings
# Using namespace='CELERY' means all celery-related config keys must start with 'CELERY_'
app.config_from_object('django.conf:settings', namespace='CELERY')

# Automatically discover tasks in all installed apps (looks for tasks.py files)
app.autodiscover_tasks()
