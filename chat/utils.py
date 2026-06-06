from django.core.cache import cache
from django.utils import timezone

def get_user_id_str(user):
    return str(user.user_id) if hasattr(user, 'user_id') else str(user.doctor_id)

def set_user_online(user):
    """
    Increments connection count in cache for the user.
    Returns True if user just went online (count transition 0 -> 1).
    """
    user_id = get_user_id_str(user)
    count_key = f"online_count_{user_id}"
    status_key = f"online_{user_id}"
    
    try:
        count = cache.get(count_key, 0)
        new_count = count + 1
        cache.set(count_key, new_count, timeout=None)
        cache.set(status_key, True, timeout=None)
        return count == 0
    except Exception as e:
        print(f"Error in set_user_online: {e}")
        cache.set(status_key, True, timeout=None)
        return True

def set_user_offline(user):
    """
    Decrements connection count in cache for the user.
    Returns True if user just went offline (count transition 1 -> 0).
    """
    user_id = get_user_id_str(user)
    count_key = f"online_count_{user_id}"
    status_key = f"online_{user_id}"
    last_seen_key = f"last_seen_{user_id}"
    
    # Update last seen timestamp
    now = timezone.now().isoformat()
    cache.set(last_seen_key, now, timeout=None)
    
    try:
        count = cache.get(count_key, 0)
        new_count = max(0, count - 1)
        if new_count == 0:
            cache.delete(count_key)
            cache.delete(status_key)
            return True
        else:
            cache.set(count_key, new_count, timeout=None)
            return False
    except Exception as e:
        print(f"Error in set_user_offline: {e}")
        cache.delete(status_key)
        return True

def is_user_online(user_id):
    """
    Returns True if user is currently online.
    """
    return cache.get(f"online_{user_id}", False)

def get_last_seen(user_id):
    """
    Returns the ISO-format datetime of when the user was last seen.
    """
    return cache.get(f"last_seen_{user_id}", None)

def check_rate_limit(user_id, event_type):
    """
    Checks if a user has exceeded their rate limit for a specific event type.
    Limits:
    - 'message' (TEXT/IMAGE/FILE): 60 per minute
    - 'typing': 300 per minute
    - 'read_event': 120 per minute
    Returns True if allowed, False if throttled.
    """
    limits = {
        'message': (60, 60),      # (limit, period in seconds)
        'typing': (300, 60),
        'read_event': (120, 60)
    }
    
    if event_type not in limits:
        return True
        
    limit, period = limits[event_type]
    key = f"rate_limit_{event_type}_{user_id}"
    
    try:
        current = cache.get(key, 0)
        if current >= limit:
            return False
        cache.set(key, current + 1, timeout=period)
        return True
    except Exception as e:
        print(f"Error in check_rate_limit: {e}")
        return True

