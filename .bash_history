apt-get update && apt-get upgrade -y
# Install basic packages
apt-get install -y curl ca-certificates gnupg ufw
# Allow web (HTTP/HTTPS) and SSH traffic
ufw allow OpenSSH
ufw allow 80
ufw allow 443
# Enable the firewall
ufw --force enable
# Check firewall status
ufw status
# Install Docker
curl -fsSL https://get.docker.com | sh
# Add your user to the Docker group so you can run docker without sudo
usermod -aG docker $USER
# Activate the new group permissions
newgrp docker
mkdir -p /srv/aibiz/{caddy,ghost,postgres,n8n,redis,plausible,cal,endpoints}
mkdir -p /srv/aibiz/caddy/data /srv/aibiz/caddy/config
version: "3.9"
volumes:
- ./mariadb:/var/lib/mysql
redis:
image: redis:7
restart: unless-stopped
wordpress:
image: wordpress:latest # Apache + PHP
restart: unless-stopped
depends_on: [mariadb]
environment:
WORDPRESS_DB_HOST: mariadb:3306
WORDPRESS_DB_USER: ${WP_DB_USER}
WORDPRESS_DB_PASSWORD: ${WP_DB_PASS}
WORDPRESS_DB_NAME: ${WP_DB_NAME}
WORDPRESS_CONFIG_EXTRA: | define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_HOME', 'https://aibizsolutions.org');
define('WP_SITEURL', 'https://aibizsolutions.org');
volumes:
- ./wordpress:/var/www/html
expose:
- "80"
phpmyadmin:
image: phpmyadmin:5
restart: unless-stopped
depends_on: [mariadb]
environment:
PMA_HOST: mariadb
PMA_USER: ${WP_DB_USER}
PMA_PASSWORD: ${WP_DB_PASS}
expose:
- "80"
n8n:
image: n8nio/n8n:latest
restart: unless-stopped
depends_on: [mariadb, redis]
environment:
- N8N_HOST=n8n.aibizsolutions.org
- N8N_PROTOCOL=https
- N8N_PORT=5678
- DB_TYPE=sqlite
- EXECUTIONS_MODE=queue
- QUEUE_BULL_REDIS_HOST=redis
- GENERIC_TIMEZONE=America/New_York
- WEBHOOK_URL=https://n8n.aibizsolutions.org/
- N8N_DIAGNOSTICS_ENABLED=false
volumes:
- ./n8n:/home/node/.n8n
endpoints:
image: node:20
working_dir: /app
volumes:
- ./endpoints:/app
command: sh -c "npm i && npm run dev"
environment:
- OPENAI_API_KEY=${OPENAI_API_KEY}
- N8N_BASE_URL=https://n8n.aibizsolutions.org
expose:
- "3000"
cd /srv/aibiz
nano .env
docker compose --env-file .env up -d
ls -l /srv/aibiz
cd /srv/aibiz
mkdir -p wordpress mariadb
cat > /srv/aibiz/.env << 'EOF'
# WordPress DB
MYSQL_ROOT_PASSWORD=strongrootpass
WP_DB_NAME=aibiz_wp
WP_DB_USER=aibiz
WP_DB_PASS=strongwppass

# n8n / optional API
OPENAI_API_KEY=sk-YOUR-OPENAI-KEY
EOF

cat > /srv/aibiz/caddy/Caddyfile << 'EOF'
{
  email admin@aibizsolutions.org
}

aibizsolutions.org, www.aibizsolutions.org {
  encode gzip
  reverse_proxy wordpress:80
}

n8n.aibizsolutions.org {
  encode gzip
  reverse_proxy n8n:5678
}

# Optional: if you keep a small Node API later
api.aibizsolutions.org {
  encode gzip
  reverse_proxy endpoints:3000
}
EOF

cat > /srv/aibiz/docker-compose.yml << 'EOF'
version: "3.9"

services:
  caddy:
    image: caddy:2
    restart: unless-stopped
    ports: ["80:80", "443:443"]
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./caddy/data:/data
      - ./caddy/config:/config

  mariadb:
    image: mariadb:10.11
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${WP_DB_NAME}
      MYSQL_USER: ${WP_DB_USER}
      MYSQL_PASSWORD: ${WP_DB_PASS}
    command: ["mysqld","--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"]
    volumes:
      - ./mariadb:/var/lib/mysql

  redis:
    image: redis:7
    restart: unless-stopped

  wordpress:
    image: wordpress:latest  # Apache + PHP
    restart: unless-stopped
    depends_on: [mariadb]
    environment:
      WORDPRESS_DB_HOST: mariadb:3306
      WORDPRESS_DB_USER: ${WP_DB_USER}
      WORDPRESS_DB_PASSWORD: ${WP_DB_PASS}
      WORDPRESS_DB_NAME: ${WP_DB_NAME}
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_REDIS_HOST', 'redis');
        define('WP_REDIS_PORT', 6379);
        define('WP_HOME', 'https://aibizsolutions.org');
        define('WP_SITEURL', 'https://aibizsolutions.org');
    volumes:
      - ./wordpress:/var/www/html
    expose:
      - "80"

  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    depends_on: [redis]
    environment:
      - N8N_HOST=n8n.aibizsolutions.org
      - N8N_PROTOCOL=https
      - N8N_PORT=5678
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - GENERIC_TIMEZONE=America/New_York
      - WEBHOOK_URL=https://n8n.aibizsolutions.org/
      - N8N_DIAGNOSTICS_ENABLED=false
    volumes:
      - ./n8n:/home/node/.n8n
EOF

cd /srv/aibiz
docker compose --env-file .env up -d
docker ps
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker exec -it aibiz-caddy-1 ping -c2 wordpress
# 1) Show what Caddy is actually loading
sed -n '1,120p' /srv/aibiz/caddy/Caddyfile
# 2) Validate and reload the config inside the container
docker exec aibiz-caddy-1 caddy validate --config /etc/caddy/Caddyfile
docker exec aibiz-caddy-1 caddy reload --config /etc/caddy/Caddyfile
# 3) Hit Caddy locally with the proper Host header (HTTP and HTTPS)
curl -I http://127.0.0.1 -H "Host: aibizsolutions.org"
curl -kI https://127.0.0.1 -H "Host: aibizsolutions.org"
# Public IP of this server
curl -s ifconfig.me
# What DNS resolves aibizsolutions.org to (must match the public IP above)
getent hosts aibizsolutions.org
getent hosts www.aibizsolutions.org
# Your server's public IPv4
curl -s ifconfig.me
# Check DNS now points to that same IPv4
getent hosts aibizsolutions.org
getent hosts www.aibizsolutions.org
getent hosts n8n.aibizsolutions.org
ufw allow OpenSSH
ufw allow 80
ufw allow 443
ufw --force enable
ufw allow OpenSSH
ufw allow 80
ufw allow 443
ufw --force enable
curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER
newgrp docker
apt-get install -y docker-compose-plugin
getent hosts aibizsolutions.org
getent hosts www.aibizsolutions.org
docker exec aibiz-caddy-1 caddy reload --config /etc/caddy/Caddyfile
docker logs -f aibiz-caddy-1
context: connection refused, status: 502
reverseproxy.statusError
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep n8n
docker logs --tail=120 $(docker ps -qf name=n8n)
cd /srv/aibiz
docker compose stop n8n
# Give the node user (UID 1000) ownership of the folder
chown -R 1000:1000 /srv/aibiz/n8n
# Set safe directory permissions
chmod -R 755 /srv/aibiz/n8n
# Give the node user (UID 1000) ownership of the folder
chown -R 1000:1000 /srv/aibiz/n8n
# Set safe directory permissions
chmod -R 755 /srv/aibiz/n8n
docker compose up -d n8n
sleep 10
docker logs --tail=80 aibiz-n8n-1
nano /srv/aibiz/docker-compose.yml
cd /srv/aibiz
nano docker-compose.yml
# Paste the corrected YAML above
docker compose down
docker compose up -d
nano /srv/aibiz/docker-compose.yml
# delete the 'version:' line at the very top
docker compose up -d
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
curl -I https://aibizsolutions.org
curl -I https://n8n.aibizsolutions.org
# MariaDB / WordPress
MYSQL_ROOT_PASSWORD=change_this_root_pw
WP_DB_NAME=aibiz_wp
WP_DB_USER=aibiz
WP_DB_PASS=change_this_wp_pw
# Email (for WP Mail SMTP)
SMTP_HOST=smtp.yourprovider.com
SMTP_USER=noreply@aibizsolutions.org
SMTP_PASS=change_this_smtp_pw
# (Optional) n8n auth (if you want to move them out of compose)
N8N_USER=admin
N8N_PASS=ChangeThisPassword!
openssl rand -hex 24   # strong random
bash
- N8N_BASIC_AUTH_USER=${N8N_USER}
- N8N_BASIC_AUTH_PASSWORD=${N8N_PASS}
docker compose --env-file .env up -d n8n
N8N_BASIC_AUTH_ACTIVE=true
N8N_USER=admin
N8N_PASS=ChangeThisPassword!
OPENAI_API_KEY=sk-...yourkey...
CALENDLY_URL=https://calendly.com/supportai-aibizsolutions/ai-blueprint
SUPPORT_EMAIL=support@aibizsolutions.org
SITE_URL=https://aibizsolutions.org
cd /srv/aibiz
docker compose --env-file .env up -d n8n
https://n8n.aibizsolutions.org/webhook/chat
curl -X POST https://n8n.aibizsolutions.org/webhook/chat   -H 'Content-Type: application/json'   -d '{"message":"Hello, this is a test from the terminal."}'
curl -X POST https://n8n.aibizsolutions.org/webhook/chat   -H 'Content-Type: application/json'   -d '{"message":"Hello, this is a test from the terminal."}'
curl -X POST https://n8n.aibizsolutions.org/webhook/chat   -H 'Content-Type: application/json'   -d '{"message":"Hello, this is a production test."}'
curl -X POST https://n8n.aibizsolutions.org/webhook/chat   -H 'Content-Type: application/json'   -d '{"message":"Hello, this is a production test."}'
docker compose restart n8n
find / -name "docker-compose.yml" 2>/dev/null
/srv/aibiz/docker-compose.yml
cd /srv/aibiz
ls -l docker-compose.yml .env
docker compose ps
docker compose restart n8n
# docker compose up -d n8n
pwd
# should print: /srv/aibiz
curl -X POST https://n8n.aibizsolutions.org/webhook/chat   -H 'Content-Type: application/json'   -d '{"message":"Hello from server test!"}'
curl -X POST 'https://n8n.aibizsolutions.org/webhook-test/chat'   -H 'Content-Type: application/json'   -d '{"message":"I want to book a consultation"}'
cd /srv/aibiz
grep OPENAI_API_KEY .env
cd /srv/aibiz
cat .env | grep OPENAI_API_KEY
cd /srv/aibiz
nano .env
docker compose up -d n8n
docker compose exec n8n env | grep OPENAI_API_KEY
cd /srv/aibiz
ls -l .env
nano .env
cd /srv/aibiz
nano docker-compose.yml
docker compose down
docker compose up -d
docker compose exec n8n env | grep -E 'OPENAI|CALENDLY|SUPPORT'
cd /srv/aibiz
ls -l .env
nano .env
Ctrl + O
Enter
Ctrl + X
cd /srv/aibiz
nano docker-compose.yml
curl -X POST 'https://n8n.aibizsolutions.org/webhook-test/chat'   -H 'Content-Type: application/json'   -d '{"message":"I want to book a consultation"}'
docker compose exec n8n env | grep OPENAI_API_KEY
cd /srv/aibiz
ls -l
cd /srv/aibiz
# create the .env with your values
cat > .env <<'EOF'
# AI Biz / n8n environment
OPENAI_API_KEY=sk-REPLACE_WITH_YOUR_REAL_KEY
CALENDLY_URL=https://cal.com/supportai-aibizsolutions/ai-blueprint
SUPPORT_EMAIL=support@aibizsolutions.org
EOF

# make sure it exists
ls -l .env
# (optional) restrict permissions
chmod 600 .env
nano docker-compose.yml
docker compose down
docker compose up -d
cd /srv/aibiz
nano .env
nano /srv/aibiz/docker-compose.yml
docker compose config
docker compose down
docker compose up -d
docker compose exec n8n env | grep -E 'OPENAI|CALENDLY|SUPPORT'
cd /srv/aibiz
docker compose ps
# make sure the data dir exists
mkdir -p .n8n
# give it to the node user inside the container (uid 1000)
chown -R 1000:1000 .n8n
# restart only n8n
docker compose restart n8n
docker compose ps
docker compose exec n8n env | grep -E 'OPENAI|CALENDLY|SUPPORT'
curl -X POST 'https://n8n.aibizsolutions.org/webhook-test/chat'   -H 'Content-Type: application/json'   -d '{"message":"I want to book a consultation"}'
cd /srv/aibiz
ls -lah .n8n
# make sure n8n can read it
chown -R 1000:1000 .n8n
docker compose restart n8n
# replace <OLD_N8N_CONTAINER_ID>
docker cp <OLD_N8N_CONTAINER_ID>:/home/node/.n8n /srv/aibiz/.n8n_recovered
ls -lah /srv/aibiz/.n8n_recovered
docker ps -a | grep n8n
docker volume ls | grep -i n8n
{   "ok": true,;   "intent": "support",;   "message": "={{$json.reply}}",;   "email": "={{$json.email}}"; }
cd /srv/aibiz
# make sure the persistent data directory exists
mkdir -p .n8n
# give it to the 'node' user inside the container (uid 1000)
chown -R 1000:1000 .n8n
docker compose restart n8n
docker compose ps
curl -X POST 'https://n8n.aibizsolutions.org/webhook-test/chat'   -H 'Content-Type: application/json'   -d '{"message":"I want to book a consultation"}'
OPENAI_API_KEY=sk-...
CALENDLY_URI=https://cal.com/supportai-aibizsolutions/ai-blueprint
SUPPORT_EMAIL=support@aibizsolutions.org
docker ps | grep n8n
docker exec -it aibiz-n8n-1 env | grep OPENAI_API_KEY
nano /srv/aibiz/.env
docker exec -it aibiz-n8n-1 env | grep OPENAI_API_KEY
cat /srv/aibiz/.env | grep OPENAI_API_KEY
cd /srv/aibiz
docker compose down
docker compose up -d
docker compose exec n8n env | grep OPENAI_API_KEY
nano /srv/aibiz/docker-compose.yml
cd /srv/aibiz
docker compose down
docker compose up -d
cd /srv/aibiz
docker compose exec n8n bash
# now inside the container:
echo $OPENAI_API_KEY   # just to double-check it's present
# Quick test call:
curl -s -i https://api.openai.com/v1/models   -H "Authorization: Bearer $OPENAI_API_KEY"
docker compose exec n8n env | grep OPENAI_API_KEY
docker compose up -d n8n
cd /srv/aibiz
nano .env
cd /srv/aibiz
# Where in your project files is OPENAI_API_KEY mentioned?
grep -R --line-number --no-messages "OPENAI_API_KEY" .
# Show the exact env that docker-compose will pass after variable expansion
docker compose config | grep -n "OPENAI_API_KEY" -n
# Show the value INSIDE the running n8n container
docker compose exec n8n env | grep OPENAI_API_KEY
# Also check if your shell/session has it exported (should not unless you set it)
printenv | grep OPENAI
# (nice to know) Which container ID is n8n, and what envs did it start with?
docker compose ps -q n8n | xargs docker inspect --format='{{.Id}}'
docker inspect $(docker compose ps -q n8n) | grep -n '"OPENAI_API_KEY'
cd /srv/aibiz
nano .env
cd /srv/aibiz
nano .env
docker compose down
docker compose up -d
docker compose exec n8n env | grep OPENAI_API_KEY
docker compose exec n8n bash
curl -s -i https://api.openai.com/v1/models   -H "Authorization: Bearer $OPENAI_API_KEY"
cd /srv/aibiz
nl -ba docker-compose.yml | sed -n '48,68p'
nano docker-compose.yml
nano /srv/aibiz/docker-compose.yml
CD /SRV/AIBIZ la -a
docker compose down
docker compose up -d
docker compose exec n8n env | grep OPENAI_API_KEY
cd /srv/aibiz
pwd
ls -la
chown -R 1000:1000 .n8n
chmod 600 .env
docker compose down
docker compose up -d
the attribute `version` is obsolete
nano -c docker-compose.yml
docker compose config
nano docker-compose.yml
nano .env
chown -R 1000:1000 .n8n
chmod 600 .env
docker compose down
docker compose config       # should output full config with no errors
docker compose up -d
docker compose ps
docker compose exec n8n env | grep -E 'OPENAI|CALENDLY|SUPPORT'
curl -X POST 'https://n8n.aibizsolutions.org/webhook-test/chat'   -H 'Content-Type: application/json'   -d '{"message":"I want to book a consultation"}'
curl -X POST 'https://n8n.aibizsolutions.org/webhook-test/chat'   -H 'Content-Type: application/json'   -d '{"message":"I want to book a consultation"}'
# 1) See containers
docker compose ps
# 2) Print the key from INSIDE the n8n container
docker compose exec n8n env | grep OPENAI_API_KEY
docker compose down
docker compose up -d
docker compose exec n8n env | grep OPENAI_API_KEY
docker compose exec n8n bash -lc 'curl -sS https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY" | head'
# 1) Check the shell and OS
docker compose exec n8n sh -lc 'cat /etc/os-release'
# 2) If curl is missing, install it (try apk first; if not Alpine, fall back to apt)
docker compose exec n8n sh -lc 'apk add --no-cache curl || (apt-get update && apt-get install -y curl)'
# 3) Call OpenAI's models endpoint using the env var the container already has
docker compose exec n8n sh -lc   'curl -sS https://api.openai.com/v1/models \
     -H "Authorization: Bearer $OPENAI_API_KEY" | head'
# 1) Install curl as root inside the container (temporary; survives only until the container is rebuilt)
docker compose exec -u root n8n sh -lc 'apk add --no-cache curl'
# 2) Call OpenAI using the OPENAI_API_KEY that’s already in the container env
docker compose exec n8n sh -lc   'curl -sS https://api.openai.com/v1/models \
     -H "Authorization: Bearer $OPENAI_API_KEY" | head'
cd /home/youruser/public_html/wp-content
mkdir -p mu-plugins
cd /home/youruser/public_html/wp-content
mkdir -p mu-plugins
nano cd /home/youruser/public_html/wp-content
mkdir -p mu-plugins
sudo nano /home/youruser/public_html/wp-content/mu-plugins/ava-chat-mu.php
cd /var/www/html
cd /home
ls
cd /home/ubuntu
ls
cd /home/ubuntu
ls
cd /var/www/
ls
bash
cd /var/www/html
ls
find / -type d -name "wp-content" 2>/dev/null
cd /srv/aibiz/wordpress/wp-content
mkdir -p mu-plugins
sudo nano mu-plugins/ava-chat-mu.php
sudo systemctl restart apache2
sudo nano /srv/aibiz/wordpress/wp-content/mu-plugins/ava-chat-mu.php
cd /srv/aibiz
docker compose ps
docker compose restart wordpress
docker compose exec wordpress bash -lc 'ls -l /var/www/html/wp-content/mu-plugins'
curl -X POST https://n8n.aibizsolutions.org/webhook/chat   -H "Content-Type: application/json"   -d '{"message": "hello"}'
curl -v --max-time 15 https://n8n.aibizsolutions.org/webhook/chat   -H "Content-Type: application/json"   -d '{"message":"hello"}'
curl -v --max-time 15 https://n8n.aibizsolutions.org/webhook/chat   -H "Content-Type: application/json"   -d '{"message":"hello"}'
curl -v -X POST https://n8n.aibizsolutions.org/webhook/chat   -H "Content-Type: application/json"   -d '{"message":"hello"}'
# Find the n8n container name (likely aibiz-n8n-1)
docker compose ps
docker exec -it aibiz-n8n-1 sh -lc   "curl -s -X POST http://localhost:5678/webhook/chat -H 'Content-Type: application/json' -d '{\"message\":\"hello\"}'"
cd /srv/aibiz/
cd /srv/aibiz/n8n/
cd /root/n8n/
cd /opt/n8n/
cd /srv/aibiz
docker compose ps
# or (works anywhere)
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker exec -it aibiz-n8n-1 sh -lc   "curl -v -X POST http://localhost:5678/webhook/chat \
  -H 'Content-Type: application/json' \
  -d '{\"message\":\"hello\"}'"
curl -v -X POST https://n8n.aibizsolutions.org/webhook/chat   -H "Content-Type: application/json"   -d '{"message":"hello"}'
# Get into Caddy container
docker exec -it aibiz-caddy-1 sh
cd /srv/aibiz
# Check status of running containers
docker compose ps
# View logs for n8n
docker logs -f aibiz-n8n-1
cd /srv/aibiz
curl -v -X POST https://n8n.aibizsolutions.org/webhook-test/chat   -H "Content-Type: application/json"   -d '{"message":"hello"}'
docker exec -it aibiz-n8n-1 sh -lc   'curl -sv http://localhost:5678/webhook/chat -H "Content-Type: application/json" -d "{\"message\":\"hello\"}"'
# Pull latest (stable) version
docker pull docker.n8n.io/n8nio/n8n
# Pull specific version
docker pull docker.n8n.io/n8nio/n8n:1.81.0
# Pull next (unstable) version
docker pull docker.n8n.io/n8nio/n8n:next
docker.n8n.io/n8nio/n8n:nextcd /srv/aibiz
docker compose restart n8n
docker compose logs -f n8n | grep -i webhook
cd /srv/aibiz
docker compose restart n8n
docker compose logs -f n8n | grep -i webhook
cd /srv/aibiz
docker compose restart n8n
docker compose logs -f n8n | grep -i webhook
cd /srv/aibiz
curl -v -H "Content-Type: application/json"   -d '{"message":"hello"}'   https://n8n.aibizsolutions.org/webhook/chat
docker compose logs -f n8n | grep webhook
cd /srv/aibiz
docker compose logs -f n8n | grep webhook
cd /srv/aibiz
volumes:
docker compose up -d/srv/aibiz# volumes:
/srv/aibiz# docker compose up -d
docker compose up -d
nano /srv/aibiz/docker-compose.yml
nano /srv/aibiz/caddy/Caddyfile
# 1) Create needed folders if missing
sudo mkdir -p /srv/aibiz/{caddy/config,caddy/data,wordpress,mariadb,.n8n}
# 2) Bring the stack up
cd /srv/aibiz
docker compose up -d
# 3) Watch logs (in another terminal you can stop with Ctrl+C)
docker compose logs -f --tail=100 caddy n8n wordpress mariadb
sudo nano /srv/aibiz/caddy/Caddyfile
cd /srv/aibiz
docker compose ps
docker compose logs --tail=200 n8n
# tighten n8n settings file perms (if it exists)
sudo mkdir -p /srv/aibiz/.n8n
sudo chown -R 1000:1000 /srv/aibiz/.n8n
sudo chmod 600 /srv/aibiz/.n8n/config 2>/dev/null || true
cd /srv/aibiz
# tighten n8n settings file perms (if it exists)
sudo mkdir -p /srv/aibiz/.n8n
sudo chown -R 1000:1000 /srv/aibiz/.n8n
sudo chmod 600 /srv/aibiz/.n8n/config 2>/dev/null || true
nano
nano docker-compose.yml
cd /srv/aibiz
docker compose up -d n8n
docker compose logs -f --tail=100 n8n
curl -v https://n8n.aibizsolutions.org/webhook/chat   -H "Content-Type: application/json"   -d '{"message":"hello from curl"}'
/srv/aibiz/docker-compose.yml
cd /srv/aibiz
nano /srv/aibiz/docker-compose.yml
cd /srv/aibiz
docker compose up -d n8n
nano /srv/aibiz/docker-compose.yml
cd /srv/aibiz
docker compose up -d n8n
nano /srv/aibiz/docker-compose.yml
cd /srv/aibiz
docker compose down
docker network rm aibiz_default
printf "COMPOSE_PROJECT_NAME=aibiz\n" > /srv/aibiz/.env
docker compose up -d
docker compose logs -f --tail=100 n8n
docker compose logs -f --tail=100 caddy
nano /srv/aibiz/docker-compose.yml
printf "COMPOSE_PROJECT_NAME=aibiz\n" > /srv/aibiz/.env
mkdir -p /srv/aibiz/{caddy/config,caddy/data,n8n,redis,mariadb,wordpress}
nano /srv/aibiz/caddy/Caddyfile
docker compose restart caddy
# or:
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
nano /var/www/html/wp-content/mu-plugins/ava-chat.php
docker exec -it aibiz-wordpress-1 bash
ls /var/www/html/wp-content/mu-plugins/
cd /var/www/html/wp-content/mu-plugins/
cd /wp
/var/www/html/wp-content/mu-plugins/
CONTAINER ID   IMAGE              COMMAND                  NAMES
b7f12e3ab3f2   wordpress:latest   "docker-entrypoint.s…"   aibiz-wordpress-1
1a9f7c09b2d3   n8nio/n8n:latest   "tini -- /docker-ent…"   aibiz-n8n-1
...etc
docker exec -it aibiz-wordpress-1 bash
/var/www/html/wp-content/mu-plugins/
nano /var/www/html/wp-content/mu-plugins/
/var/www/html/wp-content/mu-plugins/
cd /srv/aibiz
docker compose down
docker compose up -d
docker compose ps
docker compose logs SERVICE_NAME --tail=50
docker exec -it aibiz-wordpress-1 bash
cd /srv/aibiz
nano /srv/aibiz/caddy/Caddyfile
cd /srv/aibiz
docker compose restart caddy
docker compose logs -f caddy
cd /srv/aibiz
docker compose ps
docker compose logs -f n8n
cd /srv/aibiz
docker compose stop n8n
cp /srv/aibiz/.n8n/database.sqlite /srv/aibiz/.n8n/database.sqlite.backup.$(date +%F-%H%M%S)
apt-get update && apt-get install -y sqlite3
sqlite3 /srv/aibiz/.n8n/database.sqlite '.mode json' 'SELECT * FROM "workflow_entity";'   > /srv/aibiz/workflows-export.json
sqlite3 /srv/aibiz/.n8n/database.sqlite '.mode json' 'SELECT id,name,type,data FROM "credentials_entity";'   > /srv/aibiz/credentials-export.json
mv /srv/aibiz/.n8n/database.sqlite /srv/aibiz/.n8n/database.sqlite.bad.$(date +%s)
sqlite3 /srv/aibiz/.n8n/database.sqlite '.mode json' 'SELECT id,name,type,data FROM "credentials_entity";'   > /srv/aibiz/credentials-export.json
mv /srv/aibiz/.n8n/database.sqlite /srv/aibiz/.n8n/database.sqlite.bad.$(date +%s)
cd /srv/aibiz
docker compose stop n8n
sqlite3 /srv/aibiz/.n8n/database.sqlite
# 1) See the fully-resolved config that Docker will use
docker compose config
# 2) Confirm the project name (network should be "aibiz")
echo $COMPOSE_PROJECT_NAME
cd /srv/aibiz
printf "COMPOSE_PROJECT_NAME=aibiz\n" > ./.env
docker compose down
docker network rm aibiz_default || true
nano docker-compose.yml
docker compose up -d n8n
nano docker-compose.yml
cd /srv/aibiz
# Optional: set consistent project name so network = aibiz
printf "COMPOSE_PROJECT_NAME=aibiz\n" > ./.env
# Make sure the custom network name isn't lingering incorrectly
docker network rm aibiz_default 2>/dev/null || true
# Start the stack
docker compose up -d
# Watch logs for each service
docker compose logs -f n8n
cd /srv/aibiz
docker compose ps
docker compose logs --tail=200 caddy
# Stop only n8n
docker compose stop n8n
# Backup the SQLite DB
mv /srv/aibiz/.n8n/database.sqlite /srv/aibiz/.n8n/database.sqlite.bak.$(date +%s)
# Start n8n again (fresh DB will be created)
docker compose up -d n8n
docker compose logs -f n8n
# stop the container(s)
docker compose down
# or: docker stop n8n
# find your n8n data volume or bind mount (commonly ~/.n8n)
# back it up before touching anything
tar -czf n8n_backup_$(date +%F_%H%M).tgz ~/.n8n
# if using a Docker volume named "n8n_data", dump it:
docker run --rm -v n8n_data:/data -v "$PWD":/backup alpine   sh -c 'cd /data && tar -czf /backup/n8n_volume_backup.tgz .'
cd /srv/aibiz
# open the DB (adjust path to the database file if you’re using a volume)
sqlite3 ~/.n8n/database.sqlite
cd /srv/aibiz
# list your n8n container
docker ps --filter "name=n8n"
# show mounts so we can see where /home/node/.n8n is mapped on the HOST
docker inspect <container_name_or_id>   --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
docker run --rm -v n8n_data:/data -v "$PWD":/backup alpine   sh -lc 'cd /data && tar -czf /backup/n8n_volume_backup_$(date +%F_%H%M).tgz .'
docker stop aibiz-n8n-1
docker exec aibiz-n8n-1 sh -lc 'cd /home/node/.n8n && tar -czf - database.sqlite *.sqlite-* 2>/dev/null || tar -czf - database.sqlite' > n8n_backup_$(date +%F_%H%M).tgz
docker inspect aibiz-n8n-1   --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
docker stop aibiz-n8n-1
# backup the whole n8n data folder (this is the one mapped to /home/node/.n8n)
tar -czf n8n_backup_$(date +%F_%H%M).tgz -C /srv/aibiz/n8n .
ls -lh n8n_backup_*.tgz
sqlite3 /srv/aibiz/n8n/database.sqlite
# 1) Does the 'user' table exist?
sqlite3 /srv/aibiz/n8n/database.sqlite "SELECT COUNT(*) FROM sqlite_master WHERE name='user';"
# 2) Does the 'api_keys' table exist?  (this is what that migration usually adds)
sqlite3 /srv/aibiz/n8n/database.sqlite "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='api_keys';"
# 3) Is the migration already recorded?
sqlite3 /srv/aibiz/n8n/database.sqlite "SELECT timestamp, name FROM migrations ORDER BY timestamp;"
docker stop aibiz-n8n-1
mv /srv/aibiz/n8n/database.sqlite /srv/aibiz/n8n/database.sqlite.bak
rm -f /srv/aibiz/n8n/database.sqlite-shm /srv/aibiz/n8n/database.sqlite-wal
docker start aibiz-n8n-1
docker logs -f aibiz-n8n-1
sqlite3 /srv/aibiz/n8n/database.sqlite ".tables *workflow*"
docker stop aibiz-n8n-1
docker start aibiz-n8n-1
docker logs -f aibiz-n8n-1
# Stop the container so nothing writes while we check
docker stop aibiz-n8n-1
# See your actual workflow table names
sqlite3 /srv/aibiz/n8n/database.sqlite ".tables *workflow*"
# See what prefix the container is using
docker inspect aibiz-n8n-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^DB_TABLE_PREFIX='
DB_TABLE_PREFIX=n8n
services:
nano docker-compose.yml
docker exec -it aibiz-mariadb-1 bash
cd /srv/aibiz
docker exec -it aibiz-mariadb-1 mysql -u root -p
nano docker-compose.yml
cd /srv/aibiz
# Stop old containers
docker compose down
# Bring them up clean with new credentials
docker compose up -d
# Confirm services are running
docker compose ps
docker exec -it aibiz-mariadb-1 mysql -u root -p
# Enter: AiBizRoot#9581
docker exec -it aibiz-mariadb-1 mysql -u root -p
nano /srv/aibiz/docker-compose.yml
docker compose down
docker compose up -d
cd /srv/aibiz
# Stop old containers
docker compose down
# Bring them up clean with new credentials
docker compose up -d
# Confirm services are running
docker compose ps
docker exec -it aibiz-mariadb-1 mysql -u root -p
nano /srv/aibiz/docker-compose.yml
docker exec -it aibiz-mariadb-1 mysql -u root -p
nano /srv/aibiz/docker-compose.yml
docker exec -it aibiz-mariadb-1 mysql -u root -p
Dimma@3161
cd /srv/aibiz
cat >/root/aibiz_recover.sh <<'BASH'
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
BASH

chmod +x /root/aibiz_recover.sh
bash /root/aibiz_recover.sh
docker exec -it aibiz-mariadb-1 mysql -uroot -pAiBizRoot#9581 -e "SHOW DATABASES;"
docker exec -i aibiz-mariadb-1 mysql -uroot -pAiBizRoot#9581 <<SQL
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY 'AiBizWP#7439';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
FLUSH PRIVILEGES;
SQL

docker exec -it aibiz-mariadb-1 mysql -uroot -pAiBizRoot#9581 -e "SHOW DATABASES;"
docker exec -it aibiz-wordpress-1 bash -lc "grep -E \"DB_(NAME|USER|PASSWORD|HOST)\" /var/www/html/wp-config.php || echo 'no wp-config.php'"
docker exec -it aibiz-wordpress-1 bash -lc "sed -i \"/DB_NAME/s/'[^']*'/'wordpress'/\" /var/www/html/wp-config.php && \
 sed -i \"/DB_USER/s/'[^']*'/'wpuser'/\" /var/www/html/wp-config.php && \
 sed -i \"/DB_PASSWORD/s/'[^']*'/'AiBizWP#7439'/\" /var/www/html/wp-config.php && \
 sed -i \"/DB_HOST/s/'[^']*'/'mariadb:3306'/\" /var/www/html/wp-config.php"
docker exec -it aibiz-mariadb-1 mysql -uroot -pAiBizRoot#9581 -e "SHOW DATABASES;"
docker compose restart wordpress
sleep 10
docker compose logs --tail=80 wordpress
docker exec -i aibiz-mariadb-1 mysql -uroot -pAiBizRoot#9581 wordpress <<SQL
INSERT INTO wp_users (user_login, user_pass, user_nicename, user_email, user_status, display_name)
SELECT 'admin', MD5('WPAdmin#8473'), 'admin', 'admin@aibizsolutions.org', 0, 'Admin'
WHERE NOT EXISTS (SELECT 1 FROM wp_users WHERE user_login='admin');
UPDATE wp_users SET user_pass = MD5('WPAdmin#8473') WHERE user_login='admin';
SQL

docker exec -i aibiz-mariadb-1 mysql -uroot -p'AiBizRoot#9581' -e "SHOW DATABASES;"
# expect to see: wordpress
docker exec -i aibiz-mariadb-1 mysql -uroot -p'AiBizRoot#9581' -e "SHOW GRANTS FOR 'wpuser'@'%';"
# should include ALL PRIVILEGES ON wordpress.*
docker exec -i aibiz-mariadb-1 mysql -uroot -p'AiBizRoot#9581' <<'SQL'
CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY 'AiBizWP#7439';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
FLUSH PRIVILEGES;
SQL

# open a shell in the container
docker exec -it aibiz-wordpress-1 bash
cd /srv/aibiz
# Create a fresh wp-config.php with your DB settings
docker run --rm   --network aibiz   --volumes-from aibiz-wordpress-1   wordpress:cli   config create   --path=/var/www/html   --dbname=wordpress   --dbuser=wpuser   --dbpass='AiBizWP#7439'   --dbhost='mariadb:3306'   --dbprefix='wp_'   --skip-check
docker run --rm   --network aibiz   --volumes-from aibiz-wordpress-1   wordpress:cli   core install   --path=/var/www/html   --url='https://aibizsolutions.org'   --title='AI Biz Solutions'   --admin_user='admin'   --admin_password='WPAdmin#8473'   --admin_email='admin@aibizsolutions.org'
