"""
MindMate - Comprehensive System Test
يختبر جميع ميزات التطبيق بالكامل
"""
import requests, socket, sys

BASE = "http://127.0.0.1:8000"

GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
BLUE   = "\033[94m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

results = []

def ok(msg):
    print(f"  {GREEN}✅ {msg}{RESET}")
    results.append(("PASS", msg))

def fail(msg, detail=""):
    d = str(detail)[:150] if detail else ""
    print(f"  {RED}❌ {msg}{RESET}" + (f"\n     └─ {d}" if d else ""))
    results.append(("FAIL", msg))

def warn(msg):
    print(f"  {YELLOW}⚠️  {msg}{RESET}")
    results.append(("WARN", msg))

def section(title):
    print(f"\n{BOLD}{BLUE}{'='*60}{RESET}")
    print(f"{BOLD}{BLUE}  {title}{RESET}")
    print(f"{BOLD}{BLUE}{'='*60}{RESET}")

def S(method, url, data=None, headers=None, timeout=15):
    try:
        fn = getattr(requests, method)
        kwargs = {"headers": headers, "timeout": timeout}
        if data is not None:
            kwargs["json"] = data
        r = fn(BASE + url, **kwargs)
        try:
            body = r.json()
        except Exception:
            body = r.text
        return r, body
    except Exception as e:
        return None, str(e)

# ============================================================
# 0. SERVER CONNECTIVITY
# ============================================================
section("0. Server Connectivity")
r, _ = S("get", "/api/accounts/login/")
if r is not None:
    ok(f"Backend reachable (port 8000, status={r.status_code})")
else:
    fail("Backend NOT reachable — تأكد من تشغيل daphne!")
    sys.exit(1)

# ============================================================
# 1. USER AUTH
# ============================================================
section("1. User Authentication")

r, body = S("post", "/api/accounts/register/user/", {
    "email": "systest_user@mindmate.test",
    "password": "Test@12345",
    "full_name": "SysTest User"
})
if r is not None and r.status_code == 201:
    ok("User registration")
elif r is not None and r.status_code == 400 and "email" in str(body).lower():
    warn("User already registered — skipping")
else:
    fail("User registration", body)

r, body = S("post", "/api/accounts/login/", {
    "email": "systest_user@mindmate.test",
    "password": "Test@12345",
    "role": "user"
})
user_token = None
if r is not None and r.status_code == 200:
    user_token = body.get("token")
    ok(f"User login ✓")
else:
    fail("User login", body)

UH = {"Authorization": f"Bearer {user_token}"} if user_token else {}

# ============================================================
# 2. DOCTOR AUTH
# ============================================================
section("2. Doctor Authentication")

r, body = S("post", "/api/accounts/register/doctor/", {
    "email": "systest_doctor@mindmate.test",
    "password": "Doc@12345",
    "full_name": "Dr. SysTest",
    "specialization": "Psychiatry"
})
if r is not None and r.status_code == 201:
    ok("Doctor registration")
elif r is not None and r.status_code == 400 and "email" in str(body).lower():
    warn("Doctor already registered — skipping")
else:
    fail("Doctor registration", body)

r, body = S("post", "/api/accounts/login/", {
    "email": "systest_doctor@mindmate.test",
    "password": "Doc@12345",
    "role": "doctor"
})
doctor_token = None
if r is not None and r.status_code == 200:
    doctor_token = body.get("token")
    ok("Doctor login ✓")
else:
    fail("Doctor login", body)

DH = {"Authorization": f"Bearer {doctor_token}"} if doctor_token else {}

# ============================================================
# 3. TRACKING
# ============================================================
section("3. Daily Tracking")

r, body = S("post", "/api/tracking/mood/", {"mood_level": 4, "reason_note": "Test"}, UH)
if r is not None and r.status_code in [200, 201]:
    ok("Record mood")
else:
    fail("Record mood", body)

r, body = S("get", "/api/tracking/mood/", headers=UH)
if r is not None and r.status_code == 200:
    ok(f"Get today's mood → level={body.get('mood_level')}")
else:
    fail("Get today's mood", body)

r, body = S("post", "/api/tracking/journal/", {"content": "System test journal."}, UH)
if r is not None and r.status_code in [200, 201]:
    ok("Create journal entry")
else:
    fail("Create journal entry", body)

r, body = S("get", "/api/tracking/journal/", headers=UH)
if r is not None and r.status_code == 200:
    ok("Get today's journal ✓")
else:
    fail("Get today's journal", body)

r, body = S("get", "/api/tracking/progress/", headers=UH)
if r is not None and r.status_code == 200:
    ok(f"Daily progress → mood:{body.get('mood_completed')} journal:{body.get('journal_completed')}")
else:
    fail("Get daily progress", body)

r, body = S("get", "/api/tracking/journal/history/", headers=UH)
if r is not None and r.status_code == 200:
    ok(f"Journal history → {len(body)} entries")
else:
    fail("Journal history", body)

r, body = S("get", "/api/tracking/journal/sharing/", headers=UH)
if r is not None and r.status_code == 200:
    ok(f"Journal sharing permissions → {len(body)} records")
else:
    fail("Journal sharing permissions", body)

# ============================================================
# 4. QUESTIONNAIRES
# ============================================================
section("4. Questionnaires")

r, body = S("get", "/api/tracking/questionnaires/", headers=UH)
qtypes = []
if r is not None and r.status_code == 200:
    qtypes = body
    ok(f"List questionnaire types → {len(qtypes)} types")
    for q in qtypes:
        print(f"     • {q.get('code')}: {q.get('name_en','')}")
else:
    fail("List questionnaire types", body)

if qtypes:
    code = qtypes[0]["code"]
    r, body = S("get", f"/api/tracking/questionnaires/{code}/questions/", headers=UH)
    if r is not None and r.status_code == 200:
        ok(f"Questions for '{code}' → {len(body)} questions")
    else:
        fail(f"Questions for '{code}'", body)

# ============================================================
# 5. ANALYSIS
# ============================================================
section("5. Comprehensive Analysis")

r, body = S("get", "/api/tracking/analysis/", headers=UH)
if r is not None and r.status_code == 200:
    ok("Comprehensive analysis ✓")
elif r is not None and r.status_code == 404:
    warn("Analysis: no data yet (fill questionnaires first)")
else:
    fail("Comprehensive analysis", body)

# ============================================================
# 6. DAILY TIP
# ============================================================
section("6. Daily Tip")

r, body = S("get", "/api/tracking/daily-tip/", headers=UH)
if r is not None and r.status_code == 200:
    ok(f"Daily tip ✓")
elif r is not None and r.status_code == 404:
    warn("No tip yet (complete all 3 daily tasks first)")
else:
    fail("Daily tip", body)

# ============================================================
# 7. CLINIC
# ============================================================
section("7. Clinic System")

# Correct URL: /api/clinic/doctors/list/
r, body = S("get", "/api/clinic/doctors/list/", headers=UH)
if r is not None and r.status_code == 200:
    ok(f"List approved doctors → {len(body)} doctors")
else:
    fail("List approved doctors", body)

# Correct URL: /api/clinic/link/
r, body = S("get", "/api/clinic/link/", headers=UH)
if r is not None and r.status_code in [200, 405]:
    ok(f"Patient-doctor link endpoint reachable")
else:
    fail("Patient-doctor link endpoint", body)

# Correct URL: /api/clinic/doctor/patients/
r, body = S("get", "/api/clinic/doctor/patients/", headers=DH)
if r is not None and r.status_code == 200:
    ok(f"Doctor: my patients → {len(body) if isinstance(body, list) else '?'} patients")
else:
    fail("Doctor: my patients", body)

# Doctor requests
r, body = S("get", "/api/clinic/doctor/requests/", headers=DH)
if r is not None and r.status_code == 200:
    ok(f"Doctor pending requests → {len(body)} requests")
else:
    fail("Doctor pending requests", body)

# ============================================================
# 8. CHAT REST API
# ============================================================
section("8. Chat REST API")

r, body = S("get", "/api/chat/conversations/", headers=UH)
conversations = []
if r is not None and r.status_code == 200:
    conversations = body if isinstance(body, list) else body.get("results", [])
    ok(f"List conversations → {len(conversations)} conversations")
else:
    fail("List conversations", body)

conv_id = None
if conversations:
    conv_id = conversations[0].get("id")
    r, body = S("get", f"/api/chat/conversations/{conv_id}/messages/", headers=UH)
    if r is not None and r.status_code == 200:
        msgs = body if isinstance(body, list) else body.get("results", [])
        ok(f"Get messages → {len(msgs)} messages")
    else:
        fail("Get messages", body)
else:
    warn("No conversations to test messages")

# ============================================================
# 9. WEBSOCKET HANDSHAKE
# ============================================================
section("9. WebSocket Real-time Chat")

if conv_id and user_token:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(3)
        s.connect(("127.0.0.1", 8000))
        handshake = (
            f"GET /ws/chat/{conv_id}/?token={user_token} HTTP/1.1\r\n"
            f"Host: 127.0.0.1:8000\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n"
        )
        s.send(handshake.encode())
        response = s.recv(1024).decode("utf-8", errors="ignore")
        s.close()
        if "101 Switching Protocols" in response:
            ok("WebSocket handshake → 101 Switching Protocols ✓")
        elif "403" in response:
            fail("WebSocket rejected (403)", "Token auth failed in consumer")
        elif "404" in response:
            fail("WebSocket not found (404)", "Check routing URL pattern")
        else:
            warn(f"WebSocket unexpected: {response[:80]}")
    except Exception as e:
        fail("WebSocket connection", str(e))
else:
    warn("WebSocket skipped — no conversation ID or token")

# ============================================================
# 10. CHATBOT
# ============================================================
section("10. AI Chatbot")

# Correct URL: /api/chatbot/conversation/
r, body = S("get", "/api/chatbot/conversation/", headers=UH)
if r is not None and r.status_code == 200:
    ok(f"Chatbot conversation history ✓")
else:
    fail("Chatbot conversation history", body)

# Correct URL: /api/chatbot/message/
r, body = S("post", "/api/chatbot/message/", {"message": "مرحبا"}, UH, timeout=45)
if r is not None and r.status_code in [200, 201]:
    reply = str(body.get("bot_message", {}).get("content", body))[:80]
    ok(f"Chatbot response → '{reply}'")
else:
    fail("Chatbot send message", body)

# ============================================================
# 11. NOTIFICATIONS
# ============================================================
section("11. Notifications")

# Correct URL: /api/notifications/user/
r, body = S("get", "/api/notifications/user/", headers=UH)
if r is not None and r.status_code == 200:
    notifs = body if isinstance(body, list) else body.get("results", [])
    ok(f"List user notifications → {len(notifs)} notifications")
else:
    fail("List user notifications", body)

r, body = S("get", "/api/notifications/doctor/", headers=DH)
if r is not None and r.status_code == 200:
    notifs = body if isinstance(body, list) else body.get("results", [])
    ok(f"List doctor notifications → {len(notifs)} notifications")
else:
    fail("List doctor notifications", body)

# ============================================================
# SUMMARY
# ============================================================
total   = len(results)
passed  = sum(1 for s, _ in results if s == "PASS")
failed  = sum(1 for s, _ in results if s == "FAIL")
warned  = sum(1 for s, _ in results if s == "WARN")

print(f"\n{BOLD}{'='*60}{RESET}")
print(f"{BOLD}  📊 TEST SUMMARY{RESET}")
print(f"{BOLD}{'='*60}{RESET}")
print(f"  Total:    {total}")
print(f"  {GREEN}Passed:   {passed}{RESET}")
print(f"  {RED}Failed:   {failed}{RESET}")
print(f"  {YELLOW}Warnings: {warned}{RESET}")

if failed:
    print(f"\n{RED}{BOLD}  ❌ FAILED TESTS:{RESET}")
    for s, msg in results:
        if s == "FAIL":
            print(f"    • {msg}")

print()
score = int(passed / max(passed + failed, 1) * 100)
bar   = "█" * (score // 5) + "░" * (20 - score // 5)
print(f"  Health: [{GREEN}{bar}{RESET}] {score}%")
print()
if failed == 0:
    print(f"{GREEN}{BOLD}  🎉 All tests passed!{RESET}")
else:
    print(f"{RED}{BOLD}  ⚠️  {failed} test(s) need attention.{RESET}")
print()
