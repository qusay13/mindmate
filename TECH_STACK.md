# 🛠️ MindMate — حصر الأدوات والتقنيات المستخدمة

> **آخر تحديث:** 2026-06-06 | **الإصدار:** v5.0 (تحديث الإشعارات والدردشة المتقدمة)

---

## 📋 فهرس

1. [بيئة التطوير](#-بيئة-التطوير)
2. [Backend — إطار العمل والمكتبات](#-backend)
3. [قواعد البيانات](#-قواعد-البيانات)
4. [Frontend — الواجهة الأمامية](#-frontend)
5. [الذكاء الاصطناعي](#-الذكاء-الاصطناعي)
6. [البنية التحتية والشبكة](#-البنية-التحتية)
7. [الأمان والمصادقة](#-الأمان-والمصادقة)
8. [ملفات الإعداد](#-ملفات-الإعداد)

---

## 💻 بيئة التطوير

| الأداة | الإصدار/الوصف | سبب الاستخدام |
|--------|---------------|---------------|
| **Python** | 3.x | لغة البرمجة الأساسية للـ Backend |
| **Node.js + npm** | Latest | تشغيل بيئة React وإدارة حزم الـ Frontend |
| **Vite** | v8.0.4 | أداة بناء الـ Frontend سريعة جداً تدعم HMR |
| **Git** | — | إدارة النسخ والتعاون |
| **python-dotenv** | — | قراءة متغيرات البيئة من ملف `.env` |
| **virtualenv (venv)** | — | عزل بيئة Python لتجنب تعارض المكتبات |

---

## ⚙️ Backend

### إطار العمل الأساسي

| الأداة | الإصدار | سبب الاستخدام |
|--------|---------|---------------|
| **Django** | 6.0.3 | إطار الويب الرئيسي — يوفر ORM، Admin Panel، Middleware، URL routing |
| **Django REST Framework (DRF)** | Latest | بناء RESTful APIs بسرعة مع Serializers و Permissions و Views |
| **Django Channels** | Latest | تمديد Django لدعم WebSockets والاتصالات غير المتزامنة (Async) |
| **Daphne** | Latest | خادم ASGI لتشغيل Django Channels في الإنتاج والتطوير |
| **Celery** | 5.6.3 | خادم جدولة ومعالجة المهام الخلفية لإرسال إشعارات البريد و Web Push بشكل غير متزامن |

**لماذا Django؟**
- نظام ORM قوي يمنع SQL Injection تلقائياً.
- Admin Panel جاهز للإدارة.
- نظام Migrations لإدارة تطور قاعدة البيانات.
- مجتمع ضخم وتوثيق ممتاز.

---

### مكتبات DRF الإضافية والمهام الخلفية

| الأداة | سبب الاستخدام |
|--------|---------------|
| **corsheaders (django-cors-headers)** | السماح للـ Frontend (React) بالوصول إلى API على نطاق مختلف |
| **channels_redis** | ربط Django Channels بخادم Redis لإدارة Channel Layers في الدردشة الفورية |
| **pywebpush** | إرسال إشعارات Web Push الفورية إلى المتصفح عبر بروتوكول Web Push |
| **py-vapid** | توليد وإدارة مفاتيح التشفير VAPID اللازمة للمصادقة وتأمين الإشعارات الفورية |
| **http_ece** | تشفير محتوى الإشعارات الفورية (Payload encryption) لتأمين نقل البيانات للمتصفحات |

---

### محرك التحليل النفسي (RaedRepo)

| الوحدة | الموقع | الوظيفة |
|--------|--------|---------|
| **scoring.py** | `external/RaedRepo/scoring.py` | تصنيف درجات PHQ-9/GAD-7/PSS-10 وتحديد مستوى الشدة |
| **questionnaires.py** | `external/RaedRepo/questionnaires.py` | تعريف بنية الاستبيانات وأوزان الأسئلة |
| **adaptive.py** | `external/RaedRepo/adaptive.py` | خوارزميات التكيف التدريجي للتقييم |
| **arabic_output.py** | `external/RaedRepo/arabic_output.py` | ترجمة النتائج للعربية (مستوى الخطورة، التوصيات) |
| **models.py** | `external/RaedRepo/models.py` | نماذج البيانات الداخلية للمحرك |

**لماذا RaedRepo؟**
- مبني خصيصاً لتصنيف الحالات النفسية وفق معايير DSM-5.
- يدعم اللغة العربية في المخرجات.
- يوفر نتائج رقمية (درجات) وكيفية (تسميات شدة).

---

### وحدة تحليل المذكرات

| الأداة | الموقع | الوظيفة |
|--------|--------|---------|
| **journal_analyzer** | `external/journal_analyzer/` | تحليل نص المذكرات واستخراج أعراض DSM-5 بالـ NLP |

> ⚠️ **تنبيه:** هذه الوحدة موجودة لكن التكامل مع قاعدة البيانات لم يكتمل بعد.

---

## 🗄️ قواعد البيانات

### قاعدة البيانات الرئيسية

| الأداة | الإصدار | سبب الاستخدام |
|--------|---------|---------------|
| **PostgreSQL** | Latest | قاعدة البيانات الرئيسية في الإنتاج |
| **psycopg2** (ضمني) | — | مشغّل Django للتواصل مع PostgreSQL |

**لماذا PostgreSQL؟**
- يدعم أنواع بيانات متقدمة: `UUID`, `JSONField`, `ArrayField`.
- أداء ممتاز مع البيانات العلائقية المعقدة.
- يدعم Soft Delete وIndexes بكفاءة عالية.
- ACID compliance كاملة — ضروري للبيانات الطبية الحساسة.

---

### قاعدة بيانات التطوير

| الأداة | سبب الاستخدام |
|--------|---------------|
| **SQLite** | Fallback للتطوير المحلي بدون PostgreSQL — يُكتشف تلقائياً من `.env` |

---

### التخزين المؤقت والوسيط للمهام (Caching & Message Broker)

| الأداة | سبب الاستخدام |
|--------|---------------|
| **Redis** (عبر channels_redis) | - خادم Channel Layers للـ WebSockets<br>- ذاكرة تحليل مؤقتة (cache) لنتائج Analysis (6 ساعات)<br>- وسيط رسائل (Message Broker) و backend للنتائج لصالح Celery<br>- تتبع مؤشرات حضور المستخدمين (Online/Offline) وتخزينها لحظياً |

**لماذا Redis؟**
- In-memory storage — سريع جداً للبيانات المتكررة.
- دعم Pub/Sub المطلوب لـ WebSocket Channel Layers.
- يدعم TTL (انتهاء الصلاحية) تلقائياً للـ Cache.

---

### ملفات SQL

| الملف | الوظيفة |
|-------|---------|
| `mindmate_db_v4.1_final.sql` | Schema كامل لـ PostgreSQL (جميع الجداول والعلاقات) |
| `db_fixes_v4_patch.sql` | Patch إصلاحي لـ auth_tokens و doctor_condition_tags |

---

## 🖥️ Frontend

### إطار العمل والمكتبات

| الأداة | الإصدار | سبب الاستخدام |
|--------|---------|---------------|
| **React** | v19.2.4 | مكتبة UI للواجهة الأمامية — Component-based architecture |
| **React DOM** | v19.2.4 | تصيير React في متصفح الويب |
| **React Router DOM** | v7.14.0 | إدارة التوجيه (Routing) بين صفحات التطبيق |
| **Axios** | v1.15.0 | إرسال HTTP requests إلى API البـ Backend |
| **Framer Motion** | v12.38.0 | مكتبة انيميشن متقدمة للعناصر التفاعلية |
| **Lucide React** | v1.8.0 | مكتبة أيقونات SVG خفيفة وعصرية |

**لماذا React؟**
- Component-based يسهل إعادة الاستخدام وصيانة الكود.
- دعم ممتاز لـ WebSockets و Real-time updates.
- نظام State management مدمج (useState, useEffect).

**لماذا Vite؟**
- أسرع بكثير من Webpack في التطوير.
- HMR (Hot Module Replacement) فوري.
- بناء الإنتاج محسّن ومضغوط.

---

### أدوات التطوير (devDependencies)

| الأداة | سبب الاستخدام |
|--------|---------------|
| **@vitejs/plugin-react** | دعم JSX وReact في Vite |
| **ESLint** | تحليل الكود وكشف الأخطاء قبل التشغيل |
| **eslint-plugin-react-hooks** | قواعد لاستخدام Hooks بشكل صحيح |

---

## 🤖 الذكاء الاصطناعي

| الأداة | سبب الاستخدام |
|--------|---------------|
| **Google Gemini API** (gemini-flash-latest) | نموذج الذكاء الاصطناعي للمساعد النفسي (Chatbot) |
| **google-generativeai** (Python SDK) | مكتبة Python الرسمية للتواصل مع Gemini API |

**لماذا Gemini Flash؟**
- سريع جداً — مناسب للردود الفورية في المحادثات.
- يدعم اللغة العربية بجودة عالية.
- نافذة سياق واسعة لتذكر سياق المحادثة.
- مجاني نسبياً للاستخدام التجريبي.

---

## 🌐 البنية التحتية

### الخوادم

| الأداة | الوظيفة |
|--------|---------|
| **Daphne (ASGI)** | خادم Django الرئيسي — يدعم HTTP وWebSocket |
| **WSGI** | خادم بديل للبيئات التي لا تتطلب WebSocket |

### إعدادات الأمان في الإنتاج (DEBUG=False)

| الإعداد | الوظيفة |
|---------|---------|
| `SECURE_SSL_REDIRECT` | إعادة التوجيه إلى HTTPS تلقائياً |
| `SECURE_HSTS_SECONDS = 31536000` | HSTS لمدة سنة كاملة |
| `SESSION_COOKIE_SECURE` | الكوكيز عبر HTTPS فقط |
| `SECURE_CONTENT_TYPE_NOSNIFF` | منع MIME type sniffing |
| `X_FRAME_OPTIONS = 'DENY'` | منع Clickjacking |

---

## 🔐 الأمان والمصادقة

### نظام المصادقة المخصص

| المكوّن | الملف | الوظيفة |
|---------|-------|---------|
| **CustomTokenAuthentication** | `accounts/authentication.py` | قراءة Token من Header وتحقق من الجلسة في قاعدة البيانات |
| **UserSession** | `accounts/models.py` | جلسات المستخدمين/الأطباء/الأدمن مع IP وUserAgent |
| **SHA-256 Hashing** | `accounts/views.py` | تشفير Token قبل حفظه في قاعدة البيانات |
| **AuthToken** | `accounts/models.py` | رموز التحقق من الإيميل وإعادة تعيين كلمة المرور |

**لماذا Custom Token؟**
- بدلاً من JWT — Token يُخزَّن في قاعدة البيانات مما يسمح بإلغائه فوراً.
- ربط الجلسة بـ IP وUserAgent لكشف الاختراق.
- One-role constraint — جلسة واحدة لكل دور.

### Rate Limiting

| الأداة | الإعداد | الوظيفة |
|--------|---------|---------|
| **DRF UserRateThrottle** | 100 طلب/دقيقة | منع إساءة استخدام الـ API وحماية الخوادم |

---

## 📁 ملفات الإعداد الهامة

| الملف | الوظيفة |
|-------|---------|
| `.env` | متغيرات البيئة (SECRET_KEY, DB_*, GOOGLE_API_KEY) |
| `config/settings.py` | إعدادات Django الرئيسية |
| `config/urls.py` | توجيه URLs لجميع الـ Apps |
| `config/asgi.py` | إعداد ASGI + WebSocket routing |
| `front/vite.config.js` | إعداد Vite للـ Frontend |
| `front/package.json` | تبعيات الـ Frontend |
| `manage.py` | أداة إدارة Django |

---

## 📊 ملخص التقنيات بالطبقات

```
┌─────────────────────────────────────────────────────┐
│             Frontend (React + Vite)                  │
│  React 19 | React Router 7 | Axios | Framer Motion  │
├─────────────────────────────────────────────────────┤
│              Backend (Django 6 + DRF)                │
│  Django Channels | Daphne ASGI | Custom Auth        │
├─────────────────────────────────────────────────────┤
│         AI & Analysis Engine                         │
│  Google Gemini Flash | RaedRepo | journal_analyzer  │
├─────────────────────────────────────────────────────┤
│              Data Layer                              │
│  PostgreSQL (Primary) | Redis (Cache + WebSocket)   │
│  SQLite (Dev Fallback)                              │
└─────────────────────────────────────────────────────┘
```
