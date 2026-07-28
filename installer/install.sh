#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

CENTRAL_API="${PMGUARD_LICENSE_URL:-https://api.pmguard.ru}"
INSTALL_DIR="${PMGUARD_INSTALL_DIR:-/opt/pmguard}"
BUNDLE_BASE="${PMGUARD_BUNDLE_BASE:-https://raw.githubusercontent.com/magomedov1009/pmguard-releases/main/installer}"
PLATFORM_VERSION="${PMGUARD_PLATFORM_VERSION:-0.1.0}"
RELEASE_BASE="${PMGUARD_RELEASE_BASE:-https://github.com/magomedov1009/pmguard-releases/releases/download/platform-v${PLATFORM_VERSION}}"

fail() { printf '\nОшибка: %s\n' "$1" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || fail "запустите установщик через sudo"; }
prompt() {
  local variable="$1" label="$2" secret="${3:-false}" value
  if [ "$secret" = true ]; then read -r -s -p "$label: " value; printf '\n'
  else read -r -p "$label: " value; fi
  [ -n "$value" ] || fail "поле «$label» обязательно"
  printf -v "$variable" '%s' "$value"
}
random_hex() { openssl rand -hex "$1"; }

need_root
command -v curl >/dev/null || { apt-get update; apt-get install -y curl; }
command -v jq >/dev/null || { apt-get update; apt-get install -y jq; }
command -v openssl >/dev/null || { apt-get update; apt-get install -y openssl; }

printf 'PMGuard — мастер первой установки\n\n'
SETUP_CODE="${1:-}"
[ -n "$SETUP_CODE" ] || prompt SETUP_CODE "Одноразовый код установки" true
prompt DOMAIN "Домен кабинета (например vpn.example.ru)"
DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN%%/*}"
prompt BOT_TOKEN "Токен Telegram-бота" true
prompt ADMIN_TELEGRAM_ID "Telegram ID владельца"
prompt XUI_URL "Адрес панели 3x-ui (https://...)" 
prompt XUI_TOKEN "API-ключ 3x-ui" true
read -r -p "Номер кошелька YooMoney (можно оставить пустым): " YOOMONEY_RECEIVER
if [ -n "$YOOMONEY_RECEIVER" ]; then
  prompt YOOMONEY_SECRET "Секрет уведомлений YooMoney" true
else
  YOOMONEY_SECRET=""
fi

MACHINE_ID="$(cat /etc/machine-id 2>/dev/null || hostname)"
DMI_ID="$(cat /sys/class/dmi/id/product_uuid 2>/dev/null || true)"
FINGERPRINT="$(printf '%s|%s' "$MACHINE_ID" "$DMI_ID" | sha256sum | cut -d' ' -f1)"
HOST_NAME="$(hostname -f 2>/dev/null || hostname)"

install -d -m 700 "$INSTALL_DIR" "$INSTALL_DIR/schema"
curl -fsSL "$BUNDLE_BASE/compose.yml" -o "$INSTALL_DIR/compose.yml"
curl -fsSL "$BUNDLE_BASE/Caddyfile" -o "$INSTALL_DIR/Caddyfile"
for item in \
  001-postgres-init.sql \
  010-licensing-foundation.sql \
  020-multipanel-foundation.sql \
  030-monitoring-events.sql \
  040-subscription-lifecycle.sql \
  050-keenetic-setup-requests.sql \
  060-installations.sql; do
  curl -fsSL "$BUNDLE_BASE/schema/$item" -o "$INSTALL_DIR/schema/$item"
done

if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null 2>&1 ||
  fail "Docker Compose не установлен"

printf 'Загрузка PMGuard %s...\n' "$PLATFORM_VERSION"
curl -fL --retry 3 "$RELEASE_BASE/pmguard-backend-${PLATFORM_VERSION}.tar.gz" |
  gzip -dc | docker load
curl -fL --retry 3 "$RELEASE_BASE/pmguard-frontend-${PLATFORM_VERSION}.tar.gz" |
  gzip -dc | docker load
docker image inspect "pmguard/backend:${PLATFORM_VERSION}" >/dev/null ||
  fail "образ backend не загружен"
docker image inspect "pmguard/frontend:${PLATFORM_VERSION}" >/dev/null ||
  fail "образ frontend не загружен"

ACTIVATION_PAYLOAD="$(jq -n \
  --arg token "$SETUP_CODE" \
  --arg fingerprint "$FINGERPRINT" \
  --arg hostname "$HOST_NAME" \
  '{token:$token,fingerprint:$fingerprint,hostname:$hostname,version:"installer-1"}')"
ACTIVATION="$(curl -fsS --retry 2 \
  -H 'Content-Type: application/json' \
  -d "$ACTIVATION_PAYLOAD" \
  "${CENTRAL_API%/}/install/activate")" ||
  fail "код установки отклонён или сервер лицензий недоступен"
INSTALLATION_ID="$(jq -r '.installationId // empty' <<<"$ACTIVATION")"
INSTALLATION_SECRET="$(jq -r '.activationSecret // empty' <<<"$ACTIVATION")"
[ -n "$INSTALLATION_ID" ] && [ -n "$INSTALLATION_SECRET" ] ||
  fail "сервер лицензий вернул неполный ответ"

DB_PASSWORD="$(random_hex 24)"
ADMIN_PASSWORD="$(random_hex 12)"
ADMIN_TOKEN_SECRET="$(random_hex 32)"
KEENETIC_KEY="$(random_hex 32)"
PANEL_SECRET="$(random_hex 32)"
WEBHOOK_SECRET="$(random_hex 24)"

cat >"$INSTALL_DIR/.env" <<EOF
NODE_ENV=production
PORT=3000
LISTEN_HOST=0.0.0.0
CORS_ORIGINS=https://${DOMAIN}
DB_HOST=postgres
DB_PORT=5432
DB_USER=pmguard
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=pmguard
DB_SYNCHRONIZE=false
ADMIN_LOGIN=admin
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_TOKEN_SECRET=${ADMIN_TOKEN_SECRET}
KEENETIC_CREDENTIALS_KEY=${KEENETIC_KEY}
PANEL_CREDENTIALS_SECRET=${PANEL_SECRET}
BOT_TOKEN=${BOT_TOKEN}
TELEGRAM_WEBHOOK_SECRET=${WEBHOOK_SECRET}
CABINET_URL=https://${DOMAIN}/
ADMIN_TELEGRAM_ID=${ADMIN_TELEGRAM_ID}
YOOMONEY_RECEIVER=${YOOMONEY_RECEIVER}
YOOMONEY_SECRET=${YOOMONEY_SECRET}
XUI_URL=${XUI_URL%/}
XUI_TOKEN=${XUI_TOKEN}
XUI_SYNC_ON_START=true
PMGUARD_DOMAIN=${DOMAIN}
PMGUARD_DISTRIBUTED=true
PMGUARD_INSTALLATION_ID=${INSTALLATION_ID}
PMGUARD_INSTALLATION_SECRET=${INSTALLATION_SECRET}
PMGUARD_LICENSE_URL=${CENTRAL_API%/}
PMGUARD_PUBLIC_HOSTNAME=${DOMAIN}
PMGUARD_VERSION=${PLATFORM_VERSION}
PMGUARD_IMAGE_TAG=${PLATFORM_VERSION}
EOF
chmod 600 "$INSTALL_DIR/.env"

cd "$INSTALL_DIR"
docker compose -f compose.yml up -d

curl -fsS --retry 12 --retry-delay 5 \
  "https://${DOMAIN}/api/" >/dev/null ||
  fail "контейнеры запущены, но домен пока недоступен. Проверьте DNS и порты 80/443"

curl -fsS "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  --data-urlencode "url=https://${DOMAIN}/api/telegram/webhook" \
  --data-urlencode "secret_token=${WEBHOOK_SECRET}" |
  jq -e '.ok == true' >/dev/null ||
  fail "PMGuard установлен, но Telegram отклонил настройку webhook"

printf '\nPMGuard установлен: https://%s\n' "$DOMAIN"
printf 'Логин администратора: admin\nПароль администратора: %s\n' "$ADMIN_PASSWORD"
printf 'Сохраните пароль сейчас. Повторно он не показывается.\n'
