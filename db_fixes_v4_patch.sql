-- ============================================================
-- MindMate - Database Patch (v4 → v4.1)
-- الإصلاحات: auth_tokens + daily_progress questionnaire split + doctor_condition_tags
-- ============================================================


-- ============================================================
-- FIX 1: AUTH TOKENS
-- Email Verification + Password Reset لكلا المستخدم والطبيب
-- ============================================================

CREATE TABLE auth_tokens (
    token_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(user_id) ON DELETE CASCADE,
    doctor_id   UUID REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    token_type  VARCHAR(30) NOT NULL
                CHECK (token_type IN ('email_verification', 'password_reset')),
    expires_at  TIMESTAMP NOT NULL,
    used_at     TIMESTAMP,                           -- NULL = لم يُستخدم بعد
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT auth_token_one_role CHECK (
        (user_id IS NOT NULL AND doctor_id IS NULL) OR
        (user_id IS NULL  AND doctor_id IS NOT NULL)
    )
);

CREATE INDEX idx_auth_tokens_hash   ON auth_tokens(token_hash);
CREATE INDEX idx_auth_tokens_user   ON auth_tokens(user_id)   WHERE user_id   IS NOT NULL;
CREATE INDEX idx_auth_tokens_doctor ON auth_tokens(doctor_id) WHERE doctor_id IS NOT NULL;
CREATE INDEX idx_auth_tokens_expires ON auth_tokens(expires_at);

COMMENT ON TABLE auth_tokens IS 'Tokens التحقق من الإيميل وإعادة تعيين الباسوورد — للمستخدم والطبيب';
COMMENT ON COLUMN auth_tokens.used_at IS 'وقت الاستخدام — إذا لم يكن NULL فالـ token مُستهلك';


-- ============================================================
-- FIX 2: DAILY PROGRESS — تفصيل الاستبيانات الثلاثة
-- questionnaire_completed = phq9 AND gad7 AND pss10
-- ============================================================

ALTER TABLE daily_progress
    ADD COLUMN phq9_completed  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN gad7_completed  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN pss10_completed BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN daily_progress.phq9_completed  IS 'أكمل المستخدم PHQ-9 اليوم';
COMMENT ON COLUMN daily_progress.gad7_completed  IS 'أكمل المستخدم GAD-7 اليوم';
COMMENT ON COLUMN daily_progress.pss10_completed IS 'أكمل المستخدم PSS-10 اليوم';
COMMENT ON COLUMN daily_progress.questionnaire_completed IS 'يُحسب تلقائياً = phq9 AND gad7 AND pss10';

-- تحديث الـ trigger ليحسب questionnaire_completed تلقائياً من الثلاثة
CREATE OR REPLACE FUNCTION check_daily_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- questionnaire_completed يصبح true فقط بعد إكمال الثلاثة
    NEW.questionnaire_completed := NEW.phq9_completed AND NEW.gad7_completed AND NEW.pss10_completed;

    -- all_completed يصبح true بعد إكمال الثلاثة أساليب
    NEW.all_completed := NEW.mood_completed AND NEW.questionnaire_completed AND NEW.journal_completed;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- الـ trigger موجود مسبقاً (trg_check_completion) — الـ function تحدّثت فوق


-- ============================================================
-- FIX 3: DOCTOR CONDITION TAGS
-- ربط الطبيب بالحالات التي يعالجها لدعم اقتراح الطبيب
-- ============================================================

CREATE TABLE doctor_condition_tags (
    tag_id      SERIAL PRIMARY KEY,
    doctor_id   UUID NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    condition   VARCHAR(50) NOT NULL
                CHECK (condition IN (
                    'depression',   -- اكتئاب
                    'anxiety',      -- قلق
                    'stress',       -- توتر
                    'trauma',       -- صدمة
                    'ocd',          -- وسواس قهري
                    'general'       -- نفسي عام
                )),
    UNIQUE(doctor_id, condition)
);

CREATE INDEX idx_dct_condition ON doctor_condition_tags(condition);
CREATE INDEX idx_dct_doctor    ON doctor_condition_tags(doctor_id);

COMMENT ON TABLE doctor_condition_tags IS 'تخصصات الطبيب الدقيقة — تُستخدم في خوارزمية اقتراح الطبيب المناسب';

-- View مساعد: الأطباء المقبولون مع تخصصاتهم
CREATE OR REPLACE VIEW v_doctors_with_conditions AS
SELECT
    d.doctor_id,
    d.full_name,
    d.specialization,
    d.bio,
    d.profile_image,
    ARRAY_AGG(dct.condition ORDER BY dct.condition) AS condition_tags
FROM doctors d
LEFT JOIN doctor_condition_tags dct ON d.doctor_id = dct.doctor_id
WHERE d.status = 'approved' AND d.deleted_at IS NULL
GROUP BY d.doctor_id, d.full_name, d.specialization, d.bio, d.profile_image;

COMMENT ON VIEW v_doctors_with_conditions IS 'الأطباء المقبولون مع قائمة تخصصاتهم — تُستخدم في شاشة اختيار الطبيب واقتراحه';
