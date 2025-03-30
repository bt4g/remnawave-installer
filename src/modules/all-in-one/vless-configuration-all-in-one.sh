#!/bin/bash

vless_configuration_all_in_one() {
  local panel_url="$1"
  local SCRIPT_SUB_DOMAIN="$2"
  local token="$3"
  local SELF_STEAL_PORT="$4"
  local NODE_PORT="$5"
  local api_url="http://${panel_url}/api/auth/register"

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
              "$SCRIPT_SUB_DOMAIN"
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
  
  # Обновление конфигурации Xray
  local temp_file=$(mktemp)
  make_api_request "POST" "http://$panel_url/api/xray/update-config" "$token" "$SCRIPT_SUB_DOMAIN" "$new_config" > "$temp_file" 2>&1 &
  spinner $! "Обновление конфигурации Xray..."
  local update_response=$(cat "$temp_file")
  rm -f "$temp_file"

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
    "address": "172.17.0.1",
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
  
  # Создание ноды
  temp_file=$(mktemp)
  make_api_request "POST" "http://$panel_url/api/nodes/create" "$token" "$SCRIPT_SUB_DOMAIN" "$new_node_data" > "$temp_file" 2>&1 &
  spinner $! "Создание ноды..."
  node_response=$(cat "$temp_file")
  rm -f "$temp_file"

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

  # Получение inbounds
  temp_file=$(mktemp)
  make_api_request "GET" "http://$panel_url/api/inbounds" "$token" "$SCRIPT_SUB_DOMAIN" > "$temp_file" 2>&1 &
  spinner $! "Получение списка inbounds..."
  inbounds_response=$(cat "$temp_file")
  rm -f "$temp_file"

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
    "address": "$SCRIPT_SUB_DOMAIN",
    "port": 443,
    "path": "",
    "sni": "$SCRIPT_SUB_DOMAIN",
    "host": "$SCRIPT_SUB_DOMAIN",
    "alpn": "h2",
    "fingerprint": "chrome",
    "allowInsecure": false,
    "isDisabled": false
}
EOF
  )

  # Создание хоста
  temp_file=$(mktemp)
  make_api_request "POST" "http://$panel_url/api/hosts/create" "$token" "$SCRIPT_SUB_DOMAIN" "$host_data" > "$temp_file" 2>&1 &
  spinner $! "Создание хоста..."
  host_response=$(cat "$temp_file")
  rm -f "$temp_file"

  if [ -z "$host_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при создании хоста.${NC}"
  fi

  if echo "$host_response" | jq -e '.response.uuid' >/dev/null; then
    : # echo -e "${BOLD_GREEN}Хост успешно создан.${NC}"
  else
    echo -e "${BOLD_RED}Ошибка: Не удалось создать хост.${NC}"
  fi

}
