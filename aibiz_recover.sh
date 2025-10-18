#!/usr/bin/env bash
set -euo pipefail

# ========= YOU CAN CHANGE THESE IF YOU WANT =========
# New secure passwords (you can modify safely before running)
MYSQL_ROOT_PASS="AiBizRoot#9581"
WP_ADMIN_USER="admin"
WP_ADMIN_PASS="WPAdmin#8473"

# n8n login (what you use in docker-compose)
N8N_USER="supportai@aibizsolutions.org"
N8N_PASS="Dimma@31614565"

# Paths & names
PROJECT_DIR="/srv/aibiz"
DB_VOL_DIR="${PROJECT_DIR}/mariadb"
N8N_VOL_DIR="${PROJECT_DIR}/n8n"
WP_VOL_MOUNT_CONTAINER="aibiz-wordpress-1"   # from `docker compose ps`
MARIADB_CONTAINER="aibiz-mariadb-1"
WORDPRESS_CONTAINER="aibiz-wordpress-1"
# ====================================================

echo "==> Moving to project dir: ${PROJECT_DIR}"
cd "${PROJECT_DIR}"

echo "==> Show running containers:"
docker compose ps || true

echo "==> Stopping n8n and mariadb to avoid locks..."
docker compose stop n8n || true
docker compose stop mariadb || true

echo "==> Starting a temporary MariaDB repair container with --skip-grant-tables ..."
docker run -d --rm \
  --name mariadb-repair \
  -v "${DB_VOL_DIR}:/var/lib/mysql" \
  -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=yes \
  mariadb:10.11 \
  --skip-grant-tables --skip-networking

echo "==> Give MariaDB a few seconds to boot in repair mode..."
sleep 6

echo "==> Resetting MariaDB root password..."
docker exec mariadb-repair bash -lc "mysql -uroot <<SQL
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
ALTER USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
SQL"

echo "==> Stopping temporary repair container..."
docker stop mariadb-repair >/dev/null

echo "==> Bringing up mariadb normally..."
docker compose up -d mariadb

echo "==> Waiting 8s for mariadb to be ready..."
sleep 8

echo "==> Testing DB login with the new root password..."
docker exec -i "${MARIADB_CONTAINER}" \
  mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "SHOW DATABASES;" >/dev/null \
  && echo "    ✓ MariaDB root OK" || { echo "    ✗ MariaDB root test failed"; exit 1; }

# ---------- Reset WordPress admin password ----------
# Try to autodetect WP table prefix
echo "==> Detecting WordPress table prefix..."
WP_DB_NAME="wordpress"

# Try to find a likely users table
POSSIBLE_USERS_TABLE=$(docker exec -i "${MARIADB_CONTAINER}" \
  mysql -N -uroot -p"${MYSQL_ROOT_PASS}" -e "SELECT table_name FROM information_schema.tables WHERE table_schema='${WP_DB_NAME}' AND table_name LIKE '%users';" | head -n1 || true)

if [[ -z "${POSSIBLE_USERS_TABLE}" ]]; then
  # Default fallback
  POSSIBLE_USERS_TABLE="wp_users"
fi

WP_PREFIX="${POSSIBLE_USERS_TABLE%users}"
echo "    Detected users table: ${POSSIBLE_USERS_TABLE}"
echo "    Detected prefix: ${WP_PREFIX}"

echo "==> Ensuring a WP admin user exists (user_login='${WP_ADMIN_USER}'); setting password via MD5 (WP will rehash on login)..."
docker exec -i "${MARIADB_CONTAINER}" mysql -uroot -p"${MYSQL_ROOT_PASS}" "${WP_DB_NAME}" <<SQL
-- Create admin if not exists
INSERT INTO ${POSSIBLE_USERS_TABLE} (user_login, user_pass, user_nicename, user_email, user_status, display_name)
SELECT '${WP_ADMIN_USER}', MD5('${WP_ADMIN_PASS}'), 'admin', 'admin@aibizsolutions.org', 0, 'Admin'
WHERE NOT EXISTS (SELECT 1 FROM ${POSSIBLE_USERS_TABLE} WHERE user_login='${WP_ADMIN_USER}');
-- Update password for admin
UPDATE ${POSSIBLE_USERS_TABLE} SET user_pass = MD5('${WP_ADMIN_PASS}') WHERE user_login='${WP_ADMIN_USER}';
SQL

echo "    ✓ WordPress admin set:"
echo "       - username: ${WP_ADMIN_USER}"
echo "       - password: ${WP_ADMIN_PASS}"

# ---------- Clean up corrupted n8n DB ----------
echo "==> Backing up and resetting n8n data directory..."
timestamp=$(date +%F-%H%M%S)
if [[ -d "${N8N_VOL_DIR}" ]]; then
  mv "${N8N_VOL_DIR}" "${N8N_VOL_DIR}.broken.${timestamp}"
fi
mkdir -p "${N8N_VOL_DIR}"
# n8n runs as node (uid 1000)
chown -R 1000:1000 "${N8N_VOL_DIR}"

# ---------- Bring the whole stack up ----------
echo "==> Starting full stack..."
docker compose up -d

echo "==> Health check: show last 60 lines of n8n logs"
sleep 5
docker compose logs --tail=60 n8n || true

cat <<NOTE

================= NEXT STEPS =================

1) WordPress
   - URL: https://aibizsolutions.org/wp-admin
   - Login: ${WP_ADMIN_USER}
   - Pass : ${WP_ADMIN_PASS}

2) n8n editor
   - URL: https://n8n.aibizsolutions.org
   - Login (BASIC AUTH): ${N8N_USER} / ${N8N_PASS}
   - If the editor loads, your n8n DB reset worked.

3) Test webhook (from your server):
   curl -X POST https://n8n.aibizsolutions.org/webhook/chat \\
     -H "Content-Type: application/json" \\
     -d '{"message":"hello"}'

If webhook still times out:
 - Open n8n → make sure the "Website Chat Assistant" workflow is **Active** (switch on).
 - Confirm your Caddyfile points n8n.aibizsolutions.org -> n8n:5678
 - Confirm docker compose shows n8n 'Up' (docker compose ps)

4) Save these credentials in a safe password manager.

==============================================
NOTE
