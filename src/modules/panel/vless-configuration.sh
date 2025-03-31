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

  # Запрос порта Selfsteal с валидацией и дефолтным значением
  SELF_STEAL_PORT=$(read_port "Введите Selfsteal порт (можно оставить по умолчанию)" "9443" true)

  # Запрос IP адреса или домена сервера с нодой с валидацией и дефолтным значением Selfsteal домена
  NODE_HOST=$(read_domain "Введите IP адрес или домен сервера с нодой (если отличается от Selfsteal домена)" "$SELF_STEAL_DOMAIN")

  # Запрос порта API ноды с валидацией и дефолтным значением
  NODE_PORT=$(read_port "Введите порт API ноды (можно оставить по умолчанию)" "2222" true)
  
  local config_file="$REMNAWAVE_DIR/panel/config.json"
  
  # Генерация ключей x25519
  local keys_result=$(generate_vless_keys)
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  local private_key=$(echo "$keys_result" | cut -d':' -f1)
  local public_key=$(echo "$keys_result" | cut -d':' -f2)
  
  # Создание конфигурации
  generate_vless_config "$config_file" "$SELF_STEAL_DOMAIN" "$SELF_STEAL_PORT" "$private_key" "$public_key"
  
  # Обновление конфигурации Xray
  if ! update_xray_config "$panel_url" "$token" "$panel_domain" "$config_file"; then
    return 1
  fi
  
  # Создание ноды
  if ! create_vless_node "$panel_url" "$token" "$panel_domain" "$NODE_HOST" "$NODE_PORT"; then
    return 1
  fi
  
  # Получение inbound_uuid
  local inbound_uuid=$(get_inbounds "$panel_url" "$token" "$panel_domain")
  if [ -z "$inbound_uuid" ]; then
    return 1
  fi
  
  # Создание хоста
  if ! create_vless_host "$panel_url" "$token" "$panel_domain" "$inbound_uuid" "$SELF_STEAL_DOMAIN"; then
    return 1
  fi
  
  # Получение публичного ключа
  local pubkey=$(get_public_key "$panel_url" "$token" "$panel_domain")
  if [ -z "$pubkey" ]; then
    return 1
  fi

  echo
  echo -e "${GREEN}Публичный ключ (нужен для установки ноды):${NC}"
  echo
  echo -e "SSL_CERT=\"$pubkey\""
  echo
}
