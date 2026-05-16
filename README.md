# 🧠 MindMate - Mental Health Platform

**MindMate** هي منصة طبية متكاملة للصحة النفسية تهدف إلى سد الفجوة بين المرضى والأطباء النفسيين من خلال تقديم أدوات تتبع ذكية، تحليلات مبنية على خوارزميات طبية معتمدة، وتجربة تواصل سلسة وآمنة.

![MindMate Banner](https://via.placeholder.com/1200x400.png?text=MindMate+-+Your+Mental+Health+Companion)

---

## ✨ المميزات الرئيسية (Key Features)

### 🧑‍⚕️ نظام التوصية والتشخيص الذكي (AI & Clinical Assessment)
* **تقييم الحالة:** استخدام خوارزميات طبية (RaedRepo) لتحليل استبيانات مثل PHQ-9 و GAD-7 وتحديد مستوى الشدة (Severity).
* **توصية الأطباء:** نظام ذكي يقترح أنسب طبيب للمريض بناءً على أشد حالاته خلال آخر 30 يوماً.

### 👤 واجهة المريض (Patient Features)
* **المتتبع اليومي (Daily Tracker):** تتبع الحالة المزاجية (Mood)، وتدوين المذكرات (Journaling).
* **التحليل الشامل (Comprehensive Analysis):** لوحة تحكم ذكية تلخص حالة المريض خلال الـ 30 يوماً الماضية لتحديد الأنماط والأيام الصعبة.
* **إدارة الصلاحيات (Privacy & Sharing):** تحكم كامل للمريض في مشاركة مذكراته أو تحليلاته مع الأطباء المرتبطين به.

### 👨‍⚕️ واجهة الطبيب (Doctor Features)
* **لوحة تحكم الطبيب:** مراجعة طلبات الربط من المرضى، ومتابعة حالاتهم بناءً على الصلاحيات الممنوحة.
* **الدردشة الفورية (Real-time Chat):** تواصل حي ومباشر مع المرضى باستخدام تقنية WebSockets للحصول على استشارات فورية.

### 👑 لوحة تحكم الإدارة (Admin Dashboard)
* إحصائيات عامة للمنصة (عدد المستخدمين، الأطباء، وحالة التقييمات).
* إدارة الحسابات (تفعيل وإلغاء تفعيل حسابات المرضى والأطباء).

---

## 🛠️ التقنيات المستخدمة (Tech Stack)

### الواجهة الخلفية (Backend)
* **الإطار:** Django & Django REST Framework (DRF)
* **الدردشة الفورية:** Django Channels & Redis (ASGI)
* **قاعدة البيانات:** PostgreSQL (Production) / SQLite (Local Dev)
* **التوثيق (API Docs):** Swagger & OpenAPI 3.0 عبر `drf-spectacular`
* **المصادقة:** Token-Based Authentication

### الواجهة الأمامية (Frontend)
* **الإطار:** React.js (Vite)
* **التصميم:** Vanilla CSS & Tailwind CSS (لبعض المكونات)
* **الأيقونات:** Lucide-React

---

## 🚀 كيفية تشغيل المشروع (Installation & Setup)

### 1. إعداد الواجهة الخلفية (Backend)
يجب التأكد من تثبيت **Python 3.10+** و **Redis Server** على جهازك.

```bash
# 1. استنساخ المستودع
git clone <repository_url>
cd mindmate

# 2. تفعيل البيئة الوهمية (Virtual Environment)
python -m venv venv
source venv/bin/activate  # في الويندوز: venv\Scripts\activate

# 3. تثبيت الاعتمادات
pip install -r requirements.txt

# 4. إعداد قاعدة البيانات
python manage.py migrate

# 5. (اختياري) تشغيل سكربت إعداد البيانات التجريبية
python setup_demo_data.py

# 6. تشغيل السيرفر باستخدام Daphne (مطلوب لعمل الدردشة الفورية WebSockets)
daphne -p 8000 config.asgi:application
```

### 2. إعداد الواجهة الأمامية (Frontend)
يجب التأكد من تثبيت **Node.js**.

```bash
# 1. الانتقال لمجلد الواجهة الأمامية
cd front

# 2. تثبيت الحزم
npm install

# 3. تشغيل خادم التطوير
npm run dev
```

---

## 📚 توثيق الـ API (API Documentation)
المشروع مزود بتوثيق تفاعلي كامل يمكن لمطوري الويب والموبايل استخدامه لتجربة الطلبات (Requests) ومعرفة شكل الردود (Responses).

بعد تشغيل السيرفر (`daphne`)، يمكنك زيارة:
* **Swagger UI:** [http://localhost:8000/api/docs/](http://localhost:8000/api/docs/)
* **Redoc:** [http://localhost:8000/api/redoc/](http://localhost:8000/api/redoc/)

*ملاحظة لمطوري الموبايل: يوجد ملف `schema.json` وملف `MindMate_Environment.postman_environment.json` في مجلد المشروع الرئيسي يمكن استيرادها مباشرة إلى Postman.*

---

## 📁 هيكل المشروع الأساسي (Project Structure)
```text
mindmate/
├── accounts/         # إدارة الحسابات، التسجيل، الدخول (Users, Doctors, Admins)
├── clinic/           # إدارة العلاقات بين الطبيب والمريض، ونظام توصية الأطباء الذكي
├── tracking/         # المتتبع اليومي (المزاج، المذكرات، الاستبيانات، التحليل)
├── survey/           # الاستبيان المبدئي عند التسجيل
├── chat/             # نظام الدردشة الفورية (WebSockets)
├── chatbot/          # نظام الرد الآلي / البوت
├── notifications/    # نظام الإشعارات
├── config/           # إعدادات مشروع Django الرئيسية
└── front/            # مشروع React للواجهة الأمامية
```

---
**تم تطوير المشروع كمنصة متكاملة قابلة للتوسع لتقديم أفضل رعاية نفسية ممكنة.**
