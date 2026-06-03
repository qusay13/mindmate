import json
import logging
from celery import shared_task
from django.core.mail import send_mail
from django.conf import settings
from accounts.models import User, Doctor
from .models import PushSubscription, NotificationDeliveryLog

logger = logging.getLogger(__name__)

# ============================================================
# CELERY TASK: EMAIL DISPATCH
# ============================================================

@shared_task(
    bind=True,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_kwargs={"max_retries": 5}
)
def send_notification_email_task(self, notification_uuid_str, user_id_str, role, title, body):
    """
    Sends a styled, premium HTML email notification to the target recipient asynchronously.
    Logs delivery status and errors to NotificationDeliveryLog.
    """
    recipient_email = None
    recipient_name = ""
    
    try:
        if role == 'user':
            u = User.objects.get(user_id=user_id_str)
            recipient_email = u.email
            recipient_name = u.full_name or "User"
        elif role == 'doctor':
            d = Doctor.objects.get(doctor_id=user_id_str)
            recipient_email = d.email
            recipient_name = d.full_name or "Doctor"
    except Exception as ex:
        NotificationDeliveryLog.objects.create(
            notification_uuid=notification_uuid_str,
            notification_role=role,
            channel='email',
            status='failed',
            error_message=f"Recipient user/doctor database lookup failed: {ex}"
        )
        return

    if not recipient_email:
        logger.warning(f"No email address found for {role} {user_id_str}")
        return

    # Premium dark-mode HTML branding
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                background-color: #0a0516;
                color: #cbd5e1;
                margin: 0;
                padding: 0;
            }}
            .container {{
                max-width: 600px;
                margin: 40px auto;
                background-color: #11092c;
                border-radius: 16px;
                overflow: hidden;
                box-shadow: 0 20px 40px rgba(0,0,0,0.6);
                border: 1px solid #231654;
            }}
            .header {{
                background: linear-gradient(135deg, #6d28d9, #a855f7);
                padding: 40px 20px;
                text-align: center;
            }}
            .header h1 {{
                margin: 0;
                color: #ffffff;
                font-size: 32px;
                font-weight: 800;
                letter-spacing: 1px;
            }}
            .content {{
                padding: 40px 30px;
                line-height: 1.8;
            }}
            .greeting {{
                font-size: 20px;
                font-weight: 700;
                color: #a855f7;
                margin-bottom: 24px;
            }}
            .card {{
                background-color: #180e3d;
                border: 1px solid #2c1a6d;
                border-radius: 12px;
                padding: 24px;
                margin-bottom: 30px;
            }}
            .body-text {{
                font-size: 16px;
                color: #cbd5e1;
            }}
            .footer {{
                background-color: #06030d;
                padding: 24px;
                text-align: center;
                font-size: 12px;
                color: #475569;
                border-top: 1px solid #1c1044;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>MindMate</h1>
            </div>
            <div class="content">
                <div class="greeting">Hello, {recipient_name}!</div>
                <div class="card">
                    <div class="body-text">
                        <strong>{title}</strong><br><br>
                        {body}
                    </div>
                </div>
            </div>
            <div class="footer">
                This is an automated notification from MindMate. Please do not reply directly to this email.<br>
                © 2026 MindMate Inc. All rights reserved.
            </div>
        </div>
    </body>
    </html>
    """

    text_content = f"Hello {recipient_name},\n\n{title}\n\n{body}\n\nBest regards,\nThe MindMate Team"

    try:
        send_mail(
            subject=f"MindMate: {title}",
            message=text_content,
            from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@mindmate.app'),
            recipient_list=[recipient_email],
            html_message=html_content,
            fail_silently=False
        )
        NotificationDeliveryLog.objects.create(
            notification_uuid=notification_uuid_str,
            notification_role=role,
            channel='email',
            status='success'
        )
    except Exception as ex:
        NotificationDeliveryLog.objects.create(
            notification_uuid=notification_uuid_str,
            notification_role=role,
            channel='email',
            status='failed',
            error_message=str(ex)
        )
        logger.error(f"Email task exception, retrying: {ex}")
        raise ex


# ============================================================
# CELERY TASK: WEB PUSH DISPATCH
# ============================================================

@shared_task(
    bind=True,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_kwargs={"max_retries": 5}
)
def send_web_push_task(self, notification_uuid_str, user_id_str, role, payload):
    """
    Sends Web Push notifications asynchronously to all registered endpoints of the user/doctor.
    Features:
      - Automatic pruning of expired/dead subscriptions (HTTP 404/410).
      - Privacy screening (masks text if is_sensitive=True).
      - Logs delivery status and errors to NotificationDeliveryLog.
    """
    # 1. Fetch subscriptions
    if role == 'user':
        subs = PushSubscription.objects.filter(user_id=user_id_str)
    elif role == 'doctor':
        subs = PushSubscription.objects.filter(doctor_id=user_id_str)
    else:
        return

    if not subs.exists():
        logger.info(f"No push subscriptions found for {role} {user_id_str}")
        return

    # 2. Privacy compliance check
    is_sensitive = payload.get('is_sensitive', False)
    display_payload = dict(payload)
    if is_sensitive:
        display_payload['title'] = "Secure Alert"
        display_payload['body'] = "You have a new secure notification"

    payload_str = json.dumps(display_payload)
    has_sent = False
    error_msgs = []

    # 3. Deliver to each endpoint
    for sub in subs:
        try:
            from pywebpush import webpush, WebPushException
            
            vapid_private = getattr(settings, 'VAPID_PRIVATE_KEY', None)
            vapid_claims = getattr(settings, 'VAPID_CLAIMS', {"sub": "mailto:admin@mindmate.app"})
            
            if vapid_private:
                webpush(
                    subscription_info={
                        "endpoint": sub.endpoint,
                        "keys": {
                            "p256dh": sub.p256dh,
                            "auth": sub.auth
                        }
                    },
                    data=payload_str,
                    vapid_private_key=vapid_private,
                    vapid_claims=vapid_claims
                )
                has_sent = True
            else:
                # Logging fallback inside dev env
                logger.info(f"[MOCK PUSH] No VAPID key. Payload logged: {payload_str}")
                has_sent = True
        except ImportError:
            logger.info(f"[MOCK PUSH] pywebpush not installed. Payload logged: {payload_str}")
            has_sent = True
        except WebPushException as ex:
            # Self-healing dead endpoint subscription cleanup
            if ex.response is not None and ex.response.status_code in [404, 410]:
                logger.info(f"Pruning expired/dead subscription {sub.subscription_id} (HTTP {ex.response.status_code})")
                sub.delete()
            else:
                error_msgs.append(f"WebPushException for sub {sub.subscription_id}: {ex}")
                logger.error(f"Push delivery error: {ex}")
        except Exception as ex:
            error_msgs.append(str(ex))
            logger.error(f"Push delivery general exception: {ex}")

    # 4. Observability Log
    if has_sent:
        NotificationDeliveryLog.objects.create(
            notification_uuid=notification_uuid_str,
            notification_role=role,
            channel='push',
            status='success'
        )
    else:
        err_message = "; ".join(error_msgs) if error_msgs else "No active subscriptions succeeded"
        NotificationDeliveryLog.objects.create(
            notification_uuid=notification_uuid_str,
            notification_role=role,
            channel='push',
            status='failed',
            error_message=err_message
        )
        if error_msgs:
            # Force celery task retry
            raise Exception(f"Push dispatch failures: {err_message}")
