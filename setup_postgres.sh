#!/bin/bash
# ============================================================
# MindMate — PostgreSQL Setup Script
# ============================================================
# يُنشئ مستخدم وقاعدة بيانات PostgreSQL للمشروع.
# 
# الاستخدام:
#   sudo bash setup_postgres.sh
# ============================================================

set -e

DB_NAME="mindmate_db"
DB_USER="mindmate_user"
DB_PASS="mindmate_dev_2026"

echo ""
echo "🔧 MindMate — PostgreSQL Setup"
echo "================================"

# 1. إنشاء المستخدم
echo "📌 Creating database user: $DB_USER ..."
sudo -u postgres psql -c "DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';
        RAISE NOTICE 'User $DB_USER created.';
    ELSE
        ALTER ROLE $DB_USER WITH PASSWORD '$DB_PASS';
        RAISE NOTICE 'User $DB_USER already exists — password updated.';
    END IF;
END
\$\$;"

# 2. إنشاء قاعدة البيانات
echo "📌 Creating database: $DB_NAME ..."
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo "   ⚠️  Database '$DB_NAME' already exists — skipping."
else
    sudo -u postgres createdb $DB_NAME -O $DB_USER
    echo "   ✅ Database '$DB_NAME' created and owned by '$DB_USER'."
fi

# 3. منح الصلاحيات
echo "📌 Granting privileges ..."
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"

echo ""
echo "✅ PostgreSQL setup complete!"
echo ""
echo "   Database: $DB_NAME"
echo "   User:     $DB_USER"
echo "   Password: $DB_PASS"
echo "   Host:     localhost"
echo "   Port:     5432"
echo ""
echo "👉 Next: run 'python manage.py migrate' to apply Django migrations."
echo ""
