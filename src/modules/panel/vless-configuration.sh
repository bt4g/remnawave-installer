#!/bin/bash

vless_configuration() {
  local panel_url="$1"
  local panel_domain="$2"
  local token="$3"
  local api_url="http://${panel_url}/api/auth/register"

  # Запрос домена Selfsteal с валидацией
  SELF_STEAL_DOMAIN=$(read_domain "Введите Selfsteal домен, например domain.example.com")
  if [ -z "$SELF_STEAL_DOMAIN" ]; then
    return 1
  fi

  # Запрос порта Selfsteal с валидацией и дефолтным значением 9443
  SELF_STEAL_PORT=$(read_port "Введите Selfsteal порт (можно оставить по умолчанию)" "9443")

  # Запрос IP адреса или домена сервера с нодой с валидацией и дефолтным значением Selfsteal домена
  NODE_HOST=$(read_domain "Введите IP адрес или домен сервера с нодой (если отличается от Selfsteal домена)" "$SELF_STEAL_DOMAIN")

  # Запрос порта API ноды с валидацией и дефолтным значением 3000
  NODE_PORT=$(read_port "Введите порт API ноды (можно оставить по умолчанию)" "3000")

  local config_file="$REMNAWAVE_DIR/panel/config.json"
  local node_name="VLESS-NODE"

  # Генерация ключей x25519 с помощью Docker
  docker run --rm ghcr.io/xtls/xray-core x25519 >/tmp/xray_keys.txt 2>&1 &
  spinner $! "Генерация ключей x25519..."
  keys=$(cat /tmp/xray_keys.txt)
  private_key=$(echo "$keys" | grep "Private key:" | awk '{print $3}')
  public_key=$(echo "$keys" | grep "Public key:" | awk '{print $3}')
  rm -f /tmp/xray_keys.txt

  if [ -z "$private_key" ] || [ -z "$public_key" ]; then
    echo -e "${BOLD_RED}Ошибка: Не удалось сгенерировать ключи.${NC}"
  fi

  short_id=$(openssl rand -hex 8)
  cat >"$config_file" <<EOL
{
  "log": {
    "loglevel": "debug"
  },
  "inbounds": [
    {
      "tag": "VLESS TCP REALITY",
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "127.0.0.1:$SELF_STEAL_PORT",
          "show": false,
          "xver": 1,
          "shortIds": [
            "$short_id"
          ],
          "publicKey": "$public_key",
          "privateKey": "$private_key",
          "serverNames": [
              "$SELF_STEAL_DOMAIN"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    },
    {
      "tag": "BLOCK",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "type": "field",
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "domain": [
          "geosite:private"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "BLOCK"
      }
    ]
  }
}
EOL

  # Подготовка данных для обновления конфигурации Xray
  local new_config=$(cat "$config_file")
  # Запускаем curl в фоновом режиме и перенаправляем вывод в временный файл
  curl -s -X POST "http://$panel_url/api/xray/update-config" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Host: $panel_domain" \
    -H "X-Forwarded-For: $panel_url" \
    -H "X-Forwarded-Proto: https" \
    -d "$new_config" >/tmp/update_response.txt 2>&1 &
  spinner $! "Обновление конфигурации Xray..."
  local update_response=$(cat /tmp/update_response.txt)
  rm -f /tmp/update_response.txt

  if [ -z "$update_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при обновлении Xray конфига.${NC}"
  fi

  if echo "$update_response" | jq -e '.response.config' >/dev/null; then
    : # echo -e "${BOLD_GREEN}Конфигурация Xray успешно обновлена.${NC}"
  else
    echo -e "${BOLD_RED}Ошибка: Не удалось обновить конфигурацию Xray.${NC}"
  fi

  local new_node_data=$(
    cat <<EOF
{
    "name": "$node_name",
    "address": "$NODE_HOST",
    "port": $NODE_PORT,
    "isTrafficTrackingActive": false,
    "trafficLimitBytes": 0,
    "notifyPercent": 0,
    "trafficResetDay": 31,
    "excludedInbounds": [],
    "countryCode": "XX",
    "consumptionMultiplier": 1.0
}
EOF
  )
  # Создание ноды в фоновом режиме
  curl -s -X POST "http://$panel_url/api/nodes/create" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Host: $panel_domain" \
    -H "X-Forwarded-For: $panel_url" \
    -H "X-Forwarded-Proto: https" \
    -d "$new_node_data" >/tmp/node_response.txt 2>&1 &
  spinner $! "Создание ноды..."
  node_response=$(cat /tmp/node_response.txt)
  rm -f /tmp/node_response.txt

  if [ -z "$node_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при создании ноды.${NC}"
  fi

  if echo "$node_response" | jq -e '.response.uuid' >/dev/null; then
    : # echo -e "${BOLD_GREEN}Нода успешно создана.${NC}"
  else
    echo -e "${BOLD_RED}Ошибка: Не удалось создать ноду, ответ:${NC}"
    echo
    echo "Был направлен запрос с телом:"
    echo "$new_node_data"
    echo
    echo "Ответ:"
    echo
    echo "$node_response"
  fi

  # Получение inbounds в фоновом режиме
  curl -s -X GET "http://$panel_url/api/inbounds" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Host: $panel_domain" \
    -H "X-Forwarded-For: $panel_url" \
    -H "X-Forwarded-Proto: https" >/tmp/inbounds_response.txt 2>&1 &
  spinner $! "Получение списка inbounds..."
  inbounds_response=$(cat /tmp/inbounds_response.txt)
  rm -f /tmp/inbounds_response.txt

  if [ -z "$inbounds_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при получении inbounds.${NC}"
  fi

  inbound_uuid=$(echo "$inbounds_response" | jq -r '.response[0].uuid')
  if [ -z "$inbound_uuid" ]; then
    echo -e "${BOLD_RED}Ошибка: Не удалось извлечь UUID из ответа.${NC}"
  fi

  host_data=$(
    cat <<EOF
{
    "inboundUuid": "$inbound_uuid",
    "remark": "VLESS TCP REALITY",
    "address": "$SELF_STEAL_DOMAIN",
    "port": 443,
    "path": "",
    "sni": "$SELF_STEAL_DOMAIN",
    "host": "$SELF_STEAL_DOMAIN",
    "alpn": "h2",
    "fingerprint": "chrome",
    "allowInsecure": false,
    "isDisabled": false
}
EOF
  )

  # Создание хоста в фоновом режиме
  curl -s -X POST "http://$panel_url/api/hosts/create" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Host: $panel_domain" \
    -H "X-Forwarded-For: $panel_url" \
    -H "X-Forwarded-Proto: https" \
    -d "$host_data" >/tmp/host_response.txt 2>&1 &
  spinner $! "Создание хоста с UUID: $inbound_uuid..."
  host_response=$(cat /tmp/host_response.txt)
  rm -f /tmp/host_response.txt

  if [ -z "$host_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при создании хоста.${NC}"
  fi

  if echo "$host_response" | jq -e '.response.uuid' >/dev/null; then
    : # echo -e "${BOLD_GREEN}Хост успешно создан.${NC}"
  else
    echo -e "${BOLD_RED}Ошибка: Не удалось создать хост.${NC}"
  fi

  # Получение публичного ключа в фоновом режиме
  curl -s -X GET "http://$panel_url/api/keygen/get" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Host: $panel_domain" \
    -H "X-Forwarded-For: $panel_url" \
    -H "X-Forwarded-Proto: https" >/tmp/api_response.txt 2>&1 &
  spinner $! "Получение публичного ключа..."
  api_response=$(cat /tmp/api_response.txt)
  rm -f /tmp/api_response.txt

  if [ -z "$api_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Не удалось получить публичный ключ.${NC}"
  fi

  pubkey=$(echo "$api_response" | jq -r '.response.pubKey')
  if [ -z "$pubkey" ]; then
    echo -e "${BOLD_RED}Ошибка: Не удалось извлечь публичный ключ из ответа.${NC}"
  fi

  echo
  echo -e "${GREEN}Публичный ключ (нужен для установки ноды):${NC}"
  echo
  echo -e "SSL_CERT=\"$pubkey\""
  echo
}
