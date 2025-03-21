#!/bin/bash

# ===================================================================================
#                              УСТАНОВКА НОДЫ REMNAWAVE
# ===================================================================================

setup_node_all_in_one() {
    local SCRIPT_SUB_DOMAIN=$1
    local SELF_STEAL_PORT=$2
    local panel_url=$3
    local token=$4
    local NODE_PORT=$5

    mkdir -p "$LOCAL_REMNANODE_DIR" && cd "$LOCAL_REMNANODE_DIR"
    curl -sS https://raw.githubusercontent.com/remnawave/node/refs/heads/main/docker-compose-prod.yml >docker-compose.yml

    # Создание Makefile для ноды
    create_makefile "$LOCAL_REMNANODE_DIR"

    # Получение публичного ключа в фоновом режиме
    curl -s -X GET "http://$panel_url/api/keygen/get" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "Host: $SCRIPT_SUB_DOMAIN" \
        -H "X-Forwarded-For: $panel_url" \
        -H "X-Forwarded-Proto: https" >/tmp/api_response.txt 2>&1 &
    spinner $! "Получение публичного ключа..."
    api_response=$(cat /tmp/api_response.txt)
    rm -f /tmp/api_response.txt

    if [ -z "$api_response" ]; then
        echo -e "${BOLD_RED}Ошибка: Не удалось получить публичный ключ.${NC}"
        return 1
    fi

    pubkey=$(echo "$api_response" | jq -r '.response.pubKey')
    if [ -z "$pubkey" ]; then
        echo -e "${BOLD_RED}Ошибка: Не удалось извлечь публичный ключ из ответа.${NC}"
        return 1
    fi

    local CERTIFICATE="SSL_CERT=\"$pubkey\""

    echo -e "### APP ###\nAPP_PORT=$NODE_PORT\n$CERTIFICATE" >.env
}
