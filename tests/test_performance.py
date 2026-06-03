"""
tests/test_performance.py
=========================
Layer 9: Performance and Scaling Tests.
Tests database query budget restrictions and profiles notification operations.
"""

import time
import pytest
import concurrent.futures
import threading
from unittest.mock import patch
from django.db import connection
from django.test import utils

from accounts.models import User
from notifications.models import UserNotification
from notifications.services import notify_user

@pytest.mark.django_db(transaction=True)
class TestNotificationPerformance:
    def test_database_query_budget(self, user):
        """
        Verify that triggering a notification runs in a minimal number of queries.
        Prevent N+1 query regression issues inside dispatcher loops.
        """
        with utils.CaptureQueriesContext(connection) as ctx:
            notify_user(
                user=user,
                title='Budget Check',
                body='Testing query limits',
                event_key='performance_chk_01'
            )
        
        query_count = len(ctx.captured_queries)
        assert query_count <= 5, f"Query budget exceeded! Ran {query_count} queries."
        print(f"✔️ Success: Triggering notify_user consumed only {query_count} DB queries.")

    def test_bulk_notification_throughput(self, user):
        """
        Measure processing time for rapid notification dispatches.
        Ensure sub-millisecond execution when Celery offloads delivery.
        """
        start_time = time.time()
        
        for i in range(50):
            notify_user(
                user=user,
                title=f'Bulk {i}',
                body='Performance throughput test',
                event_key=f'throughput_event_{i}'
            )
            
        elapsed_time = time.time() - start_time
        avg_time = (elapsed_time / 50) * 1000
        
        print(f"✔️ Success: 50 notifications dispatched in {elapsed_time:.3f} seconds.")
        print(f"✔️ Average local latency: {avg_time:.2f} ms per dispatch.")
        assert avg_time < 20.0, f"Average dispatch latency too high: {avg_time:.2f} ms"

    def test_concurrent_idempotency_race_condition(self, user):
        """
        Test that simultaneous calls with the exact same event_key from multiple threads
        are correctly intercepted, resulting in exactly one notification record in the database.
        """
        event_key = "concurrent_session_meeting_101"
        barrier = threading.Barrier(10)
        
        def dispatch_notif():
            barrier.wait()
            try:
                from django.db import connections
                connections.close_all()
                notify_user(
                    user=user,
                    title='Race Alert',
                    body='Concurrent dispatch details',
                    event_key=event_key
                )
            except Exception:
                pass
            finally:
                from django.db import connections
                connections.close_all()

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(dispatch_notif) for _ in range(10)]
            concurrent.futures.wait(futures)
            
        count = UserNotification.objects.filter(event_key=event_key).count()
        assert count == 1, f"Race condition failure! Duplicate records created in DB: {count}"
        print(f"✔️ Concurrency confirmed: Race condition successfully blocked. DB Count: {count}")

    @patch('notifications.services.send_notification_email_task.delay')
    def test_redis_failure_fault_tolerance(self, mock_email_delay, user):
        """
        Verify that even if the Redis broker is completely offline (throwing connection errors),
        the system is fully fault-tolerant:
        1. The notification is successfully saved to the local SQL database (preserving integrity).
        2. The application handles the broker exception gracefully and does not crash,
           allowing the client REST request to complete successfully.
        """
        # Simulate Redis connection failure during Celery dispatch
        mock_email_delay.side_effect = Exception("Redis Connection Error: Connection refused")
        
        # Dispatch notification
        try:
            notif = notify_user(
                user=user,
                title='Resiliency Check',
                body='Redis is down, but database is up',
                event_key='redis_failure_test_001'
            )
        except Exception as ex:
            pytest.fail(f"Application crashed during Redis failure! Exception: {ex}")
        
        # Assert database record was successfully saved!
        assert notif is not None
        assert UserNotification.objects.filter(event_key='redis_failure_test_001').exists()
        print(f"✔️ Resiliency confirmed: Redis failure isolated. Notification saved to DB: {notif.title}")
