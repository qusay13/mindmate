from .models import UserNotification, DoctorNotification, AdminNotification

class NotificationService:
    @staticmethod
    def notify_doctor_new_link_request(doctor, user, request_id):
        """Notifies a doctor when a patient sends a link request"""
        return DoctorNotification.objects.create(
            doctor=doctor,
            title="New Link Request",
            body=f"Patient {user.full_name} wants to link with you.",
            notification_type="link_request",
            related_entity_type="doctor_patient_request",
            related_entity_id=request_id
        )

    @staticmethod
    def notify_patient_request_accepted(user, doctor):
        """Notifies a patient when their link request is accepted"""
        return UserNotification.objects.create(
            user=user,
            title="Request Accepted",
            body=f"Dr. {doctor.full_name} has accepted your link request.",
            notification_type="request_accepted",
            related_entity_type="doctor",
            related_entity_id=doctor.doctor_id
        )

    @staticmethod
    def notify_patient_request_rejected(user, doctor):
        """Notifies a patient when their link request is rejected"""
        return UserNotification.objects.create(
            user=user,
            title="Request Rejected",
            body=f"Dr. {doctor.full_name} has declined your link request.",
            notification_type="request_rejected",
            related_entity_type="doctor",
            related_entity_id=doctor.doctor_id
        )

    @staticmethod
    def notify_new_message(recipient, sender_name, conversation_id, sender_type):
        """Notifies a user or doctor about a new chat message"""
        if sender_type == 'doctor':
            # Recipient is user
            return UserNotification.objects.create(
                user=recipient,
                title="New Message",
                body=f"Dr. {sender_name} sent you a message.",
                notification_type="new_message",
                related_entity_type="conversation",
                related_entity_id=str(conversation_id)
            )
        else:
            # Recipient is doctor
            return DoctorNotification.objects.create(
                doctor=recipient,
                title="New Message",
                body=f"Patient {sender_name} sent you a message.",
                notification_type="new_message",
                related_entity_type="conversation",
                related_entity_id=str(conversation_id)
            )
