import datetime
import hashlib
import asyncio
from django.test import TransactionTestCase
from django.utils import timezone
from django.core.cache import cache
from channels.testing import WebsocketCommunicator
from channels.routing import URLRouter
from asgiref.sync import async_to_sync
from channels.db import database_sync_to_async

from chat.models import Conversation, Message
from chat.consumers import ChatConsumer
from chat.utils import is_user_online, get_last_seen
from accounts.models import User, Doctor, UserSession
import chat.routing


class ChatWebSocketTests(TransactionTestCase):

    def setUp(self):
        # Clean cache
        cache.clear()

        # Create Patient User
        self.patient = User.objects.create_user(
            email="patient_test@mindmate.test",
            password="Test@12345",
            full_name="Patient Test"
        )
        # Create Doctor User
        self.doctor = Doctor.objects.create_user(
            email="doctor_test@mindmate.test",
            password="Doc@12345",
            full_name="Doctor Test",
            specialization="Psychiatry",
            status="approved"
        )

        # Create Conversation
        self.conv = Conversation.objects.create(
            patient=self.patient,
            doctor=self.doctor
        )

        # Create Session for Patient
        self.patient_token = "patient_secret_token_123"
        self.patient_token_hash = hashlib.sha256(self.patient_token.encode()).hexdigest()
        self.patient_session = UserSession.objects.create(
            user=self.patient,
            token_hash=self.patient_token_hash,
            expires_at=timezone.now() + datetime.timedelta(days=7)
        )

        # Create Session for Doctor
        self.doctor_token = "doctor_secret_token_123"
        self.doctor_token_hash = hashlib.sha256(self.doctor_token.encode()).hexdigest()
        self.doctor_session = UserSession.objects.create(
            doctor=self.doctor,
            token_hash=self.doctor_token_hash,
            expires_at=timezone.now() + datetime.timedelta(days=7)
        )

        # Application router for testing
        self.application = URLRouter(chat.routing.websocket_urlpatterns)

    def test_websocket_handshake_success(self):
        async def run():
            communicator = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.patient_token}"
            )
            connected, subprotocol = await communicator.connect()
            self.assertTrue(connected)

            # Patient doesn't receive their own status change
            nothing = await communicator.receive_nothing()
            self.assertTrue(nothing)

            # Check online status in cache
            patient_id = str(self.patient.user_id)
            online = await database_sync_to_async(is_user_online)(patient_id)
            self.assertTrue(online)

            await communicator.disconnect()
            await asyncio.sleep(0.05)

            online_after = await database_sync_to_async(is_user_online)(patient_id)
            self.assertFalse(online_after)
            
            last_seen = await database_sync_to_async(get_last_seen)(patient_id)
            self.assertIsNotNone(last_seen)

        async_to_sync(run)()

    def test_websocket_handshake_unauthorized_token(self):
        async def run():
            communicator = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token=invalid_token_xyz"
            )
            connected, subprotocol = await communicator.connect()
            self.assertFalse(connected)
            await communicator.disconnect()
            await asyncio.sleep(0.05)

        async_to_sync(run)()

    def test_websocket_handshake_unauthorized_conversation(self):
        async def run():
            # Create an unrelated conversation
            other_doctor = await database_sync_to_async(Doctor.objects.create_user)(
                email="other_doctor_test@mindmate.test",
                password="Doc@12345",
                full_name="Other Doctor Test",
                specialization="Psychiatry",
                status="approved"
            )
            other_conv = await database_sync_to_async(Conversation.objects.create)(
                patient=self.patient,
                doctor=other_doctor
            )

            # Doctor 1 tries to connect to Doctor 2's conversation
            communicator = WebsocketCommunicator(
                self.application,
                f"ws/chat/{other_conv.id}/?token={self.doctor_token}"
            )
            connected, subprotocol = await communicator.connect()
            self.assertFalse(connected)
            await communicator.disconnect()
            await asyncio.sleep(0.05)

        async_to_sync(run)()

    def test_websocket_send_and_receive_message(self):
        async def run():
            # Connect patient
            patient_comm = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.patient_token}"
            )
            connected1, _ = await patient_comm.connect()
            self.assertTrue(connected1)
            self.assertTrue(await patient_comm.receive_nothing())

            # Connect doctor
            doctor_comm = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.doctor_token}"
            )
            connected2, _ = await doctor_comm.connect()
            self.assertTrue(connected2)
            self.assertTrue(await doctor_comm.receive_nothing())

            # Patient receives doctor online event
            event = await patient_comm.receive_json_from()
            self.assertEqual(event["type"], "user_status")
            self.assertEqual(event["status"], "online")
            self.assertEqual(event["user_id"], str(self.doctor.doctor_id))

            # Patient sends message
            payload = {
                "type": "message",
                "message": "Hello Doctor!",
                "message_type": "TEXT"
            }
            await patient_comm.send_json_to(payload)

            # Doctor receives the message
            response = await doctor_comm.receive_json_from()
            self.assertEqual(response["type"], "message")
            self.assertEqual(response["message"], "Hello Doctor!")
            self.assertEqual(response["sender_type"], "user")
            self.assertEqual(response["sender_id"], str(self.patient.user_id))

            # Patient receives their own broadcast message and message acknowledgment
            r1 = await patient_comm.receive_json_from()
            r2 = await patient_comm.receive_json_from()
            # We just need to make sure we consumed them to empty the queue

            # Check database
            @database_sync_to_async
            def check_db():
                return Message.objects.filter(
                    conversation=self.conv,
                    content="Hello Doctor!"
                ).exists()

            msg_exists = await check_db()
            self.assertTrue(msg_exists)

            await patient_comm.disconnect()
            await doctor_comm.disconnect()
            await asyncio.sleep(0.05)

        async_to_sync(run)()

    def test_websocket_typing_indicator(self):
        async def run():
            patient_comm = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.patient_token}"
            )
            await patient_comm.connect()
            self.assertTrue(await patient_comm.receive_nothing())

            doctor_comm = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.doctor_token}"
            )
            await doctor_comm.connect()
            self.assertTrue(await doctor_comm.receive_nothing())

            # Patient receives doctor online event
            event = await patient_comm.receive_json_from()
            self.assertEqual(event["type"], "user_status")
            self.assertEqual(event["user_id"], str(self.doctor.doctor_id))

            # Patient sends typing
            await patient_comm.send_json_to({
                "type": "typing",
                "is_typing": True
            })

            # Doctor receives typing event
            response = await doctor_comm.receive_json_from()
            self.assertEqual(response["type"], "typing")
            self.assertEqual(response["sender_id"], str(self.patient.user_id))
            self.assertTrue(response["is_typing"])

            await patient_comm.disconnect()
            await doctor_comm.disconnect()
            await asyncio.sleep(0.05)

        async_to_sync(run)()

    def test_websocket_messages_read_seen(self):
        async def run():
            # Create unseen message from patient
            @database_sync_to_async
            def create_msg():
                return Message.objects.create(
                    conversation=self.conv,
                    sender_type="user",
                    sender_id=self.patient.user_id,
                    content="Check this message",
                    is_seen=False
                )
            msg = await create_msg()

            # Connect Doctor
            doctor_comm = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.doctor_token}"
            )
            await doctor_comm.connect()
            self.assertTrue(await doctor_comm.receive_nothing())

            # Connect Patient
            patient_comm = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.patient_token}"
            )
            await patient_comm.connect()
            self.assertTrue(await patient_comm.receive_nothing())

            # Doctor receives patient online event
            event = await doctor_comm.receive_json_from()
            self.assertEqual(event["type"], "user_status")
            self.assertEqual(event["user_id"], str(self.patient.user_id))

            # Doctor sends messages_read event
            await doctor_comm.send_json_to({
                "type": "messages_read"
            })

            # Patient receives messages_read event
            response = await patient_comm.receive_json_from()
            self.assertEqual(response["type"], "messages_read")
            self.assertEqual(response["conversation_id"], str(self.conv.id))
            self.assertEqual(response["reader_id"], str(self.doctor.doctor_id))

            # Check DB updated
            @database_sync_to_async
            def check_seen():
                msg.refresh_from_db()
                return msg.is_seen
            is_seen = await check_seen()
            self.assertTrue(is_seen)

            await patient_comm.disconnect()
            await doctor_comm.disconnect()
            await asyncio.sleep(0.05)

        async_to_sync(run)()

    def test_websocket_message_acknowledgement(self):
        async def run():
            patient_comm = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.patient_token}"
            )
            connected, _ = await patient_comm.connect()
            self.assertTrue(connected)
            await patient_comm.receive_nothing()

            # Send message with client_msg_id
            payload = {
                "type": "message",
                "message": "Testing ack",
                "client_msg_id": "msg-999"
            }
            await patient_comm.send_json_to(payload)

            # Receive broadcast and ack
            r1 = await patient_comm.receive_json_from()
            r2 = await patient_comm.receive_json_from()

            # Identify ack frame
            ack = r1 if r1["type"] == "message_ack" else r2
            msg = r2 if r1["type"] == "message_ack" else r1

            self.assertEqual(ack["type"], "message_ack")
            self.assertEqual(ack["client_msg_id"], "msg-999")
            self.assertEqual(ack["status"], "saved")
            self.assertIsNotNone(ack["message_id"])

            self.assertEqual(msg["type"], "message")
            self.assertEqual(msg["message"], "Testing ack")

            await patient_comm.disconnect()
            await asyncio.sleep(0.05)

        async_to_sync(run)()

    def test_websocket_rate_limiting(self):
        async def run():
            patient_comm = WebsocketCommunicator(
                self.application,
                f"ws/chat/{self.conv.id}/?token={self.patient_token}"
            )
            connected, _ = await patient_comm.connect()
            self.assertTrue(connected)
            await patient_comm.receive_nothing()

            # Send 60 messages (limit)
            for i in range(60):
                payload = {
                    "type": "message",
                    "message": f"Message {i}"
                }
                await patient_comm.send_json_to(payload)
                
                # Receive both broadcast and ack
                r1 = await patient_comm.receive_json_from()
                r2 = await patient_comm.receive_json_from()
                self.assertTrue(r1["type"] in ["message", "message_ack"])
                self.assertTrue(r2["type"] in ["message", "message_ack"])

            # 61st message should fail due to rate limit
            payload = {
                "type": "message",
                "message": "Spam message 61"
            }
            await patient_comm.send_json_to(payload)

            # Receive response which should be rate limit error
            error_response = await patient_comm.receive_json_from()
            self.assertEqual(error_response["type"], "error")
            self.assertEqual(error_response["message"], "Too many messages. Please slow down.")

            await patient_comm.disconnect()
            await asyncio.sleep(0.05)

        async_to_sync(run)()
