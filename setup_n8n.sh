# ====== VARIÁVEIS ======
DOMAIN="n8n.whaz.com.br"
EMAIL="admin@whaz.com.br"   # <-- use um email válido seu
BASIC_USER="admin"          # usuário da Basic Auth na UI

# ====== 1) Permissões volumes n8n ======
mkdir -p /opt/n8n/{data,files}
chown -R 1000:1000 /opt/n8n/data /opt/n8n/files

# ====== 2) .env do n8n (ajusta host real) ======
if [ -f /opt/n8n/.env ]; then
  sed -i "s/^N8N_HOST=.*/N8N_HOST=${DOMAIN}/" /opt/n8n/.env || true
  sed -i "s|^WEBHOOK_URL=.*|WEBHOOK_URL=https://${DOMAIN}/|" /opt/n8n/.env || true
else
  ENC_KEY=$(openssl rand -hex 32)
  cat > /opt/n8n/.env <<EOF
N8N_HOST=${DOMAIN}
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://${DOMAIN}/
N8N_ENCRYPTION_KEY=${ENC_KEY}
GENERIC_TIMEZONE=America/Sao_Paulo
EXECUTIONS_DATA_SAVE_ON_SUCCESS=true
EOF
  chown 1000:1000 /opt/n8n/.env
fi

# ====== 3) docker-compose do n8n (se já existir, mantém) ======
if [ ! -f /opt/n8n/docker-compose.yml ]; then
cat > /opt/n8n/docker-compose.yml <<'EOF'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "127.0.0.1:5678:5678"
    volumes:
      - /opt/n8n/data:/home/node/.n8n
      - /opt/n8n/files:/files
    environment:
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_HIRING_BANNER_ENABLED=false
EOF
fi

# Sobe/reinicia n8n
cd /opt/n8n
docker compose down || true
docker compose pull
docker compose up -d

# ====== 4) Nginx HTTP (sem SSL ainda) ======
apt -y install nginx apache2-utils >/dev/null

# Remove site antigo do placeholder, se existir
rm -f /etc/nginx/sites-enabled/n8n.seudominio.com.br /etc/nginx/sites-available/n8n.seudominio.com.br || true

SITE="/etc/nginx/sites-available/${DOMAIN}"
cat > "$SITE" <<EOF
server {
  listen 80;
  server_name ${DOMAIN};

  # UI protegida por Basic Auth
  location / {
    proxy_pass http://127.0.0.1:5678;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;

    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd_n8n_${DOMAIN};
  }

  # Webhooks SEM Basic Auth (WhatsApp e afins)
  location ^~ /webhook/ {
    proxy_pass http://127.0.0.1:5678;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF

ln -sf "$SITE" "/etc/nginx/sites-enabled/${DOMAIN}"

# Cria/atualiza Basic Auth (vai pedir a senha)
htpasswd -c /etc/nginx/.htpasswd_n8n_${DOMAIN} "${BASIC_USER}"

nginx -t && systemctl reload nginx

# ====== 5) Certbot (gera SSL agora que 80 está OK) ======
apt -y install certbot python3-certbot-nginx >/dev/null
certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${EMAIL}" --redirect || true

# ====== 6) Bloco HTTPS final (garante as locations no 443) ======
# Sobrescreve o site com versões 80 (redirect) e 443 (SSL) mantendo Basic Auth na UI e liberando /webhook/
cat > "$SITE" <<EOF
server {
  listen 80;
  server_name ${DOMAIN};
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name ${DOMAIN};

  ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

  # UI com Basic Auth
  location / {
    proxy_pass http://127.0.0.1:5678;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_read_timeout 300;

    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd_n8n_${DOMAIN};
  }

  # Webhooks SEM auth
  location ^~ /webhook/ {
    proxy_pass http://127.0.0.1:5678;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_read_timeout 300;
  }
}
EOF

nginx -t && systemctl reload nginx

echo "OK:
- n8n em https://${DOMAIN} (UI com Basic Auth)
- /webhook/ liberado sem auth
- Container n8n rodando (127.0.0.1:5678)
- Certificado Let's Encrypt instalado

Testes:
  curl -I http://${DOMAIN}            # deve redirecionar p/ https
  curl -I https://${DOMAIN}           # 401 (Basic Auth)
  curl -I https://${DOMAIN}/webhook/test  # NÃO deve pedir auth (pode retornar 404 do n8n se o webhook não existir)

Logs n8n:
  docker logs -f \$(docker ps --filter name=n8n -q)
"

