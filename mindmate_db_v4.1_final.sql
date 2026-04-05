-- ============================================================
-- MindMate - PostgreSQL Database Schema v4.1 Final
-- النسخة الكاملة بعد تطبيق جميع التعديلات
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. USERS / DOCTORS / ADMINS
-- ============================================================

CREATE TABLE users (
    user_id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email                       VARCHAR(255) UNIQUE NOT NULL,
    password_hash               TEXT NOT NULL,
    full_name                   VARCHAR(150),
    date_of_birth               DATE,
    gender                      VARCHAR(20) CHECK (gender IN ('male','female','other','prefer_not_to_say')),
    phone_number                VARCHAR(20),
    nationality                 VARCHAR(100),
    profile_image               TEXT,
    is_active                   BOOLEAN DEFAULT TRUE,
    is_onboarded                BOOLEAN DEFAULT FALSE,
    initial_survey_completed    BOOLEAN DEFAULT FALSE,
    data_collection_start_date  DATE,
    deleted_at                  TIMESTAMP,
    created_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email  ON users(email);
CREATE INDEX idx_users_active ON users(is_active) WHERE deleted_at IS NULL;

COMMENT ON TABLE users IS 'مستخدمو تطبيق MindMate للجوال';

-- ------------------------------------------------------------

CREATE TABLE doctors (
    doctor_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email               VARCHAR(255) UNIQUE NOT NULL,
    password_hash       TEXT NOT NULL,
    full_name           VARCHAR(150) NOT NULL,
    nationality         VARCHAR(100),
    specialization      VARCHAR(150),
    bio                 TEXT,
    profile_image       TEXT,
    cv_file_path        TEXT,
    status              VARCHAR(20) DEFAULT 'pending'
                        CHECK (status IN ('pending','approved','rejected')),
    rejection_reason    TEXT,
    is_active           BOOLEAN DEFAULT TRUE,
    approved_at         TIMESTAMP,
    deleted_at          TIMESTAMP,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_doctors_email  ON doctors(email);
CREATE INDEX idx_doctors_status ON doctors(status);

COMMENT ON TABLE doctors IS 'الأطباء النفسيون المسجلون في موقع MindMate';

-- ------------------------------------------------------------

CREATE TABLE admins (
    admin_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    full_name       VARCHAR(150),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE admins IS 'مشرفو النظام لإدارة طلبات الأطباء';

-- ============================================================
-- 2. AUTHENTICATION SESSIONS
-- ============================================================

CREATE TABLE user_sessions (
    session_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(user_id)    ON DELETE CASCADE,
    doctor_id   UUID REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    admin_id    UUID REFERENCES admins(admin_id)   ON DELETE CASCADE,
    token_hash  TEXT NOT NULL,
    device_info JSONB,
    ip_address  INET,
    expires_at  TIMESTAMP NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT session_one_role CHECK (
        (user_id IS NOT NULL AND doctor_id IS NULL   AND admin_id IS NULL) OR
        (user_id IS NULL     AND doctor_id IS NOT NULL AND admin_id IS NULL) OR
        (user_id IS NULL     AND doctor_id IS NULL   AND admin_id IS NOT NULL)
    )
);

CREATE INDEX idx_sessions_token   ON user_sessions(token_hash);
CREATE INDEX idx_sessions_user    ON user_sessions(user_id);
CREATE INDEX idx_sessions_doctor  ON user_sessions(doctor_id);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);

COMMENT ON TABLE user_sessions IS 'جلسات تسجيل الدخول - token_hash للأمان';

-- ============================================================
-- 3. AUTH TOKENS — Email Verification & Password Reset
-- ============================================================

CREATE TABLE auth_tokens (
    token_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(user_id)     ON DELETE CASCADE,
    doctor_id   UUID REFERENCES doctors(doctor_id)  ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    token_type  VARCHAR(30) NOT NULL
                CHECK (token_type IN ('email_verification','password_reset')),
    expires_at  TIMESTAMP NOT NULL,
    used_at     TIMESTAMP,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT auth_token_one_role CHECK (
        (user_id IS NOT NULL AND doctor_id IS NULL) OR
        (user_id IS NULL     AND doctor_id IS NOT NULL)
    )
);

CREATE INDEX idx_auth_tokens_hash    ON auth_tokens(token_hash);
CREATE INDEX idx_auth_tokens_user    ON auth_tokens(user_id)    WHERE user_id   IS NOT NULL;
CREATE INDEX idx_auth_tokens_doctor  ON auth_tokens(doctor_id)  WHERE doctor_id IS NOT NULL;
CREATE INDEX idx_auth_tokens_expires ON auth_tokens(expires_at);

COMMENT ON TABLE auth_tokens IS 'Tokens التحقق من الإيميل وإعادة تعيين الباسوورد — للمستخدم والطبيب';
COMMENT ON COLUMN auth_tokens.used_at IS 'وقت الاستخدام — إذا لم يكن NULL فالـ token مُستهلك';

-- ============================================================
-- 4. INITIAL SURVEY (Onboarding)
-- ============================================================

CREATE TABLE initial_survey_questions (
    question_id     SERIAL PRIMARY KEY,
    question_text   TEXT NOT NULL,
    question_type   VARCHAR(30) NOT NULL
                    CHECK (question_type IN ('multiple_choice','scale','text','yes_no')),
    category        VARCHAR(50),
    options         JSONB,
    display_order   INT NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE initial_survey_questions IS 'أسئلة الاستبيان الأولي الاستكشافي';

-- ------------------------------------------------------------

CREATE TABLE initial_survey_responses (
    response_id     SERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    question_id     INT  NOT NULL REFERENCES initial_survey_questions(question_id),
    answer_text     TEXT,
    answer_value    NUMERIC,
    answered_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, question_id)
);

COMMENT ON TABLE initial_survey_responses IS 'إجابات المستخدمين على الاستبيان الأولي';

-- ============================================================
-- 5. DAILY MOOD TRACKER
-- ============================================================

CREATE TABLE daily_mood_entries (
    mood_id         SERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    mood_level      INT  NOT NULL CHECK (mood_level BETWEEN 1 AND 5),
    mood_label      VARCHAR(50),
    reason_note     TEXT,
    recorded_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_mood_user_date ON daily_mood_entries(user_id, recorded_date);

COMMENT ON TABLE daily_mood_entries IS 'تسجيل المزاج اليومي مع التفسير — يُسمح بأكثر من إدخال يومياً';

-- ============================================================
-- 6. QUESTIONNAIRES (PHQ-9 / GAD-7 / PSS-10)
-- ============================================================

CREATE TABLE questionnaire_types (
    questionnaire_type_id   SERIAL PRIMARY KEY,
    code                    VARCHAR(20) UNIQUE NOT NULL,
    name                    VARCHAR(100) NOT NULL,
    description             TEXT,
    max_score               INT NOT NULL,
    scoring_ranges          JSONB,
    is_active               BOOLEAN DEFAULT TRUE
);

INSERT INTO questionnaire_types (code, name, description, max_score, scoring_ranges) VALUES
('PHQ-9', 'مقياس الاكتئاب', 'Patient Health Questionnaire', 27,
 '{"minimal":[0,4],"mild":[5,9],"moderate":[10,14],"moderately_severe":[15,19],"severe":[20,27]}'),
('GAD-7', 'مقياس القلق', 'Generalized Anxiety Disorder', 21,
 '{"minimal":[0,4],"mild":[5,9],"moderate":[10,14],"severe":[15,21]}'),
('PSS-10', 'مقياس التوتر المدرك', 'Perceived Stress Scale', 40,
 '{"low":[0,13],"moderate":[14,26],"high":[27,40]}');

COMMENT ON TABLE questionnaire_types IS 'أنواع الاستبيانات العالمية (PHQ-9, GAD-7, PSS-10)';

-- ------------------------------------------------------------

CREATE TABLE questionnaire_questions (
    question_id             SERIAL PRIMARY KEY,
    questionnaire_type_id   INT  NOT NULL REFERENCES questionnaire_types(questionnaire_type_id),
    question_text           TEXT NOT NULL,
    question_order          INT  NOT NULL,
    options                 JSONB NOT NULL,
    is_active               BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE questionnaire_questions IS 'أسئلة كل استبيان مع خياراتها';

-- ------------------------------------------------------------

CREATE TABLE questionnaire_sessions (
    session_id              SERIAL PRIMARY KEY,
    user_id                 UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    questionnaire_type_id   INT  NOT NULL REFERENCES questionnaire_types(questionnaire_type_id),
    total_score             INT,
    severity_level          VARCHAR(30),
    completed               BOOLEAN DEFAULT FALSE,
    session_date            DATE NOT NULL DEFAULT CURRENT_DATE,
    started_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at            TIMESTAMP,
    UNIQUE(user_id, questionnaire_type_id, session_date)
);

CREATE INDEX idx_qsession_user_date ON questionnaire_sessions(user_id, session_date);

COMMENT ON TABLE questionnaire_sessions IS 'جلسات إجابة المستخدم على الاستبيانات';

-- ------------------------------------------------------------

CREATE TABLE questionnaire_answers (
    answer_id       SERIAL PRIMARY KEY,
    session_id      INT NOT NULL REFERENCES questionnaire_sessions(session_id) ON DELETE CASCADE,
    question_id     INT NOT NULL REFERENCES questionnaire_questions(question_id),
    selected_option INT NOT NULL,
    score           INT NOT NULL,
    answered_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE questionnaire_answers IS 'إجابات تفصيلية لكل سؤال مع الدرجة';

-- ============================================================
-- 7. DAILY JOURNAL + DSM-5 ANALYSIS
-- ============================================================

CREATE TABLE journal_entries (
    journal_id  SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    entry_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_journal_user_date ON journal_entries(user_id, entry_date);

COMMENT ON TABLE journal_entries IS 'المذكرات اليومية - مساحة حرة للمستخدم';

-- ------------------------------------------------------------

CREATE TABLE journal_analysis (
    analysis_id         SERIAL PRIMARY KEY,
    journal_id          INT NOT NULL REFERENCES journal_entries(journal_id) ON DELETE CASCADE,
    detected_symptoms   JSONB,
    disorder_scores     JSONB,
    dominant_pattern    VARCHAR(100),
    raw_indicators      JSONB,
    analyzed_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE journal_analysis IS 'تحليل المذكرات بناءً على معايير DSM-5';

-- ------------------------------------------------------------

CREATE TABLE journal_sharing_permissions (
    permission_id       SERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(user_id)    ON DELETE CASCADE,
    doctor_id           UUID NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    share_full_journal  BOOLEAN DEFAULT FALSE,
    share_analysis_only BOOLEAN DEFAULT TRUE,
    granted_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, doctor_id)
);

COMMENT ON TABLE journal_sharing_permissions IS 'صلاحيات مشاركة المذكرات: نص كامل أو تقييم فقط';

-- ============================================================
-- 8. DAILY PROGRESS BAR (3 parts)
-- ============================================================

CREATE TABLE daily_progress (
    progress_id             SERIAL PRIMARY KEY,
    user_id                 UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    progress_date           DATE NOT NULL DEFAULT CURRENT_DATE,
    -- Mood
    mood_completed          BOOLEAN NOT NULL DEFAULT FALSE,
    -- Questionnaires (تفصيل كل استبيان على حدة)
    phq9_completed          BOOLEAN NOT NULL DEFAULT FALSE,
    gad7_completed          BOOLEAN NOT NULL DEFAULT FALSE,
    pss10_completed         BOOLEAN NOT NULL DEFAULT FALSE,
    questionnaire_completed BOOLEAN NOT NULL DEFAULT FALSE,   -- يُحسب تلقائياً بالـ trigger
    -- Journal
    journal_completed       BOOLEAN NOT NULL DEFAULT FALSE,
    -- Overall
    all_completed           BOOLEAN NOT NULL DEFAULT FALSE,   -- يُحسب تلقائياً بالـ trigger
    tip_shown               BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, progress_date)
);

CREATE INDEX idx_progress_user_date ON daily_progress(user_id, progress_date);

COMMENT ON TABLE  daily_progress                         IS 'شريط التقدم اليومي - 3 أجزاء يتجدد كل 24 ساعة';
COMMENT ON COLUMN daily_progress.phq9_completed          IS 'أكمل المستخدم PHQ-9 اليوم';
COMMENT ON COLUMN daily_progress.gad7_completed          IS 'أكمل المستخدم GAD-7 اليوم';
COMMENT ON COLUMN daily_progress.pss10_completed         IS 'أكمل المستخدم PSS-10 اليوم';
COMMENT ON COLUMN daily_progress.questionnaire_completed IS 'يُحسب تلقائياً = phq9 AND gad7 AND pss10';
COMMENT ON COLUMN daily_progress.all_completed           IS 'يُحسب تلقائياً = mood AND questionnaire AND journal';

-- ============================================================
-- 9. AI ASSESSMENT ENGINE
-- ============================================================

CREATE TABLE assessments (
    assessment_id           SERIAL PRIMARY KEY,
    user_id                 UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    assessment_type         VARCHAR(20) NOT NULL
                            CHECK (assessment_type IN ('preliminary','final')),
    depression_score        NUMERIC(5,2),
    anxiety_score           NUMERIC(5,2),
    stress_score            NUMERIC(5,2),
    confidence_score        NUMERIC(5,2),
    overall_severity        VARCHAR(30)
                            CHECK (overall_severity IN ('normal','mild','moderate','severe','critical')),
    is_critical             BOOLEAN DEFAULT FALSE,
    mood_trend              JSONB,
    questionnaire_summary   JSONB,
    journal_summary         JSONB,
    dominant_condition      VARCHAR(100),
    recommendations         JSONB,
    data_days_count         INT,
    created_from_days       INT,
    assessed_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_assessment_user ON assessments(user_id, assessment_type);

COMMENT ON TABLE  assessments                   IS 'التقييم الشامل - مبدئي بعد 15 يوم ونهائي بعد 30 يوم';
COMMENT ON COLUMN assessments.confidence_score  IS 'مدى ثقة النموذج في التقييم (0-100)';
COMMENT ON COLUMN assessments.created_from_days IS 'هل مبني على 15 أو 30 يوم من البيانات';

-- ============================================================
-- 10. TIPS & RECOMMENDATIONS
-- ============================================================

CREATE TABLE tips_and_recommendations (
    tip_id          SERIAL PRIMARY KEY,
    category        VARCHAR(50) NOT NULL,
    content         TEXT NOT NULL,
    tip_type        VARCHAR(30) NOT NULL
                    CHECK (tip_type IN ('tip','quote','recommendation','guidance')),
    severity_target VARCHAR(30),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE tips_and_recommendations IS 'النصائح والإرشادات والاقتباسات اليومية';

-- ------------------------------------------------------------

CREATE TABLE user_daily_tips (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    tip_id      INT  NOT NULL REFERENCES tips_and_recommendations(tip_id),
    shown_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    shown_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, shown_date)
);

-- ============================================================
-- 11. DOCTOR CONDITION TAGS
-- ============================================================

CREATE TABLE doctor_condition_tags (
    tag_id      SERIAL PRIMARY KEY,
    doctor_id   UUID NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    condition   VARCHAR(50) NOT NULL
                CHECK (condition IN (
                    'depression',
                    'anxiety',
                    'stress',
                    'trauma',
                    'ocd',
                    'general'
                )),
    UNIQUE(doctor_id, condition)
);

CREATE INDEX idx_dct_condition ON doctor_condition_tags(condition);
CREATE INDEX idx_dct_doctor    ON doctor_condition_tags(doctor_id);

COMMENT ON TABLE doctor_condition_tags IS 'تخصصات الطبيب الدقيقة — تُستخدم في خوارزمية اقتراح الطبيب المناسب';

-- ============================================================
-- 12. DOCTOR-PATIENT RELATIONSHIP
-- ============================================================

CREATE TABLE doctor_patient_requests (
    request_id      SERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(user_id)    ON DELETE CASCADE,
    doctor_id       UUID NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    request_type    VARCHAR(30) NOT NULL
                    CHECK (request_type IN ('system_suggested','user_selected')),
    status          VARCHAR(20) DEFAULT 'pending'
                    CHECK (status IN ('pending','accepted','rejected')),
    assessment_id   INT REFERENCES assessments(assessment_id),
    user_message    TEXT,
    doctor_response TEXT,
    requested_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    responded_at    TIMESTAMP
);

CREATE INDEX idx_request_doctor ON doctor_patient_requests(doctor_id, status);
CREATE INDEX idx_request_user   ON doctor_patient_requests(user_id,   status);

COMMENT ON TABLE doctor_patient_requests IS 'طلبات الربط: اقتراح النظام أو اختيار المستخدم';

-- ------------------------------------------------------------

CREATE TABLE doctor_patient_relationships (
    relationship_id SERIAL PRIMARY KEY,
    doctor_id       UUID NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(user_id)     ON DELETE CASCADE,
    request_id      INT REFERENCES doctor_patient_requests(request_id),
    status          VARCHAR(20) DEFAULT 'active'
                    CHECK (status IN ('active','ended')),
    started_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at        TIMESTAMP,
    UNIQUE(doctor_id, user_id)
);

COMMENT ON TABLE doctor_patient_relationships IS 'العلاقة النشطة بين الطبيب والمريض';

-- ============================================================
-- 13. MESSAGING SYSTEM (Split with proper FK)
-- ============================================================

CREATE TABLE doctor_patient_messages_user (
    message_id      SERIAL PRIMARY KEY,
    relationship_id INT  NOT NULL REFERENCES doctor_patient_relationships(relationship_id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    is_read         BOOLEAN DEFAULT FALSE,
    sent_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at         TIMESTAMP
);

CREATE INDEX idx_dpm_user_rel ON doctor_patient_messages_user(relationship_id, sent_at);

COMMENT ON TABLE doctor_patient_messages_user IS 'رسائل المريض للطبيب - FK على users';

-- ------------------------------------------------------------

CREATE TABLE doctor_patient_messages_doctor (
    message_id      SERIAL PRIMARY KEY,
    relationship_id INT  NOT NULL REFERENCES doctor_patient_relationships(relationship_id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    is_read         BOOLEAN DEFAULT FALSE,
    sent_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at         TIMESTAMP
);

CREATE INDEX idx_dpm_doctor_rel ON doctor_patient_messages_doctor(relationship_id, sent_at);

COMMENT ON TABLE doctor_patient_messages_doctor IS 'رسائل الطبيب للمريض - FK على doctors';

-- ============================================================
-- 14. CHATBOT (AI Venting)
-- ============================================================

CREATE TABLE chatbot_conversations (
    conversation_id SERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status          VARCHAR(20) DEFAULT 'active'
                    CHECK (status IN ('active','closed')),
    started_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at        TIMESTAMP
);

CREATE INDEX idx_chatbot_user ON chatbot_conversations(user_id);

COMMENT ON TABLE chatbot_conversations IS 'محادثات الفضفضة مع الذكاء الاصطناعي';

-- ------------------------------------------------------------

CREATE TABLE chatbot_messages (
    message_id      SERIAL PRIMARY KEY,
    conversation_id INT  NOT NULL REFERENCES chatbot_conversations(conversation_id) ON DELETE CASCADE,
    sender          VARCHAR(10) NOT NULL CHECK (sender IN ('user','bot')),
    content         TEXT NOT NULL,
    sent_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE chatbot_messages IS 'رسائل الشات بوت';

-- ============================================================
-- 15. NOTIFICATIONS (Separated by role)
-- ============================================================

CREATE TABLE user_notifications (
    notification_id     SERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title               VARCHAR(255) NOT NULL,
    body                TEXT,
    notification_type   VARCHAR(50) NOT NULL,
    related_entity_type VARCHAR(50),
    related_entity_id   INT,
    is_read             BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at             TIMESTAMP
);

CREATE INDEX idx_notif_user ON user_notifications(user_id, is_read);

COMMENT ON TABLE user_notifications IS 'إشعارات المستخدمين';

-- ------------------------------------------------------------

CREATE TABLE doctor_notifications (
    notification_id     SERIAL PRIMARY KEY,
    doctor_id           UUID NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    title               VARCHAR(255) NOT NULL,
    body                TEXT,
    notification_type   VARCHAR(50) NOT NULL,
    related_entity_type VARCHAR(50),
    related_entity_id   INT,
    is_read             BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at             TIMESTAMP
);

CREATE INDEX idx_notif_doctor ON doctor_notifications(doctor_id, is_read);

COMMENT ON TABLE doctor_notifications IS 'إشعارات الأطباء';

-- ------------------------------------------------------------

CREATE TABLE admin_notifications (
    notification_id     SERIAL PRIMARY KEY,
    admin_id            UUID NOT NULL REFERENCES admins(admin_id) ON DELETE CASCADE,
    title               VARCHAR(255) NOT NULL,
    body                TEXT,
    notification_type   VARCHAR(50) NOT NULL,
    related_entity_type VARCHAR(50),
    related_entity_id   INT,
    is_read             BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at             TIMESTAMP
);

CREATE INDEX idx_notif_admin ON admin_notifications(admin_id, is_read);

COMMENT ON TABLE admin_notifications IS 'إشعارات المشرفين';

-- ============================================================
-- 16. DOCTOR REGISTRATION LOG (Admin)
-- ============================================================

CREATE TABLE doctor_registration_log (
    log_id      SERIAL PRIMARY KEY,
    doctor_id   UUID NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    admin_id    UUID REFERENCES admins(admin_id),
    action      VARCHAR(20) NOT NULL
                CHECK (action IN ('submitted','approved','rejected')),
    notes       TEXT,
    action_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_drl_doctor ON doctor_registration_log(doctor_id);

COMMENT ON TABLE doctor_registration_log IS 'سجل إجراءات تسجيل الأطباء للأدمن';

-- ============================================================
-- 17. TRIGGERS
-- ============================================================

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_doctors_updated
    BEFORE UPDATE ON doctors
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_journal_updated
    BEFORE UPDATE ON journal_entries
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_progress_updated
    BEFORE UPDATE ON daily_progress
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ------------------------------------------------------------
-- questionnaire_completed يُحسب من phq9 + gad7 + pss10
-- all_completed يُحسب من mood + questionnaire + journal
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_daily_completion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.questionnaire_completed := NEW.phq9_completed AND NEW.gad7_completed AND NEW.pss10_completed;
    NEW.all_completed           := NEW.mood_completed AND NEW.questionnaire_completed AND NEW.journal_completed;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_completion
    BEFORE INSERT OR UPDATE ON daily_progress
    FOR EACH ROW EXECUTE FUNCTION check_daily_completion();

-- ============================================================
-- 18. VIEWS
-- ============================================================

CREATE OR REPLACE VIEW v_user_daily_status AS
SELECT
    u.user_id,
    u.full_name,
    u.data_collection_start_date,
    dp.progress_date,
    dp.mood_completed,
    dp.phq9_completed,
    dp.gad7_completed,
    dp.pss10_completed,
    dp.questionnaire_completed,
    dp.journal_completed,
    dp.all_completed,
    CASE
        WHEN u.data_collection_start_date IS NULL THEN 0
        ELSE (CURRENT_DATE - u.data_collection_start_date)
    END AS days_since_start,
    CASE
        WHEN (CURRENT_DATE - u.data_collection_start_date) >= 30 THEN 'final_assessment_ready'
        WHEN (CURRENT_DATE - u.data_collection_start_date) >= 15 THEN 'preliminary_assessment_ready'
        ELSE 'collecting_data'
    END AS assessment_status
FROM users u
LEFT JOIN daily_progress dp ON u.user_id = dp.user_id AND dp.progress_date = CURRENT_DATE
WHERE u.deleted_at IS NULL;

-- ------------------------------------------------------------

CREATE OR REPLACE VIEW v_doctor_summary AS
SELECT
    d.doctor_id,
    d.full_name,
    d.specialization,
    d.status AS account_status,
    COUNT(DISTINCT dpr.user_id)   FILTER (WHERE dpr.status  = 'active')  AS active_patients,
    COUNT(DISTINCT dpreq.request_id) FILTER (WHERE dpreq.status = 'pending') AS pending_requests
FROM doctors d
LEFT JOIN doctor_patient_relationships dpr  ON d.doctor_id = dpr.doctor_id
LEFT JOIN doctor_patient_requests      dpreq ON d.doctor_id = dpreq.doctor_id
WHERE d.status = 'approved' AND d.deleted_at IS NULL
GROUP BY d.doctor_id, d.full_name, d.specialization, d.status;

-- ------------------------------------------------------------

CREATE OR REPLACE VIEW v_pending_doctors AS
SELECT
    d.doctor_id,
    d.full_name,
    d.email,
    d.nationality,
    d.specialization,
    d.cv_file_path,
    d.created_at AS registration_date
FROM doctors d
WHERE d.status = 'pending' AND d.deleted_at IS NULL
ORDER BY d.created_at ASC;

-- ------------------------------------------------------------

CREATE OR REPLACE VIEW v_latest_assessment AS
SELECT DISTINCT ON (a.user_id)
    a.user_id,
    u.full_name,
    a.assessment_type,
    a.depression_score,
    a.anxiety_score,
    a.stress_score,
    a.confidence_score,
    a.overall_severity,
    a.is_critical,
    a.dominant_condition,
    a.created_from_days,
    a.assessed_at
FROM assessments a
JOIN users u ON a.user_id = u.user_id
WHERE u.deleted_at IS NULL
ORDER BY a.user_id, a.assessed_at DESC;

-- ------------------------------------------------------------

CREATE OR REPLACE VIEW v_doctor_patient_messages AS
SELECT
    message_id,
    relationship_id,
    sender_id,
    'user'   AS sender_type,
    content,
    is_read,
    sent_at,
    read_at
FROM doctor_patient_messages_user
UNION ALL
SELECT
    message_id,
    relationship_id,
    sender_id,
    'doctor' AS sender_type,
    content,
    is_read,
    sent_at,
    read_at
FROM doctor_patient_messages_doctor;

-- ------------------------------------------------------------

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

COMMENT ON VIEW v_doctors_with_conditions   IS 'الأطباء المقبولون مع قائمة تخصصاتهم — لشاشة اختيار الطبيب واقتراحه';
COMMENT ON VIEW v_doctor_patient_messages   IS 'رسائل الطرفين مجتمعة مع sender_type';
COMMENT ON VIEW v_latest_assessment         IS 'آخر تقييم لكل مستخدم';
COMMENT ON VIEW v_pending_doctors           IS 'الأطباء في انتظار موافقة الأدمن';
COMMENT ON VIEW v_doctor_summary            IS 'ملخص الطبيب مع عدد المرضى والطلبات المعلقة';
COMMENT ON VIEW v_user_daily_status         IS 'حالة المستخدم اليومية مع تفصيل الاستبيانات وحالة التقييم';
