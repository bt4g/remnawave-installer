#!/bin/bash

# Установка и настройка remnawave-subscription-page
setup_remnawave-subscription-page() {
    echo -e "${BOLD_GREEN}Установка remnawave-subscription-page...${NC}"

    # Создаем директорию для remnawave-subscription-page
    mkdir -p $REMNAWAVE_DIR/subscription-page

    cd $REMNAWAVE_DIR/subscription-page

    # Создание .env файла
    cat >.env <<EOF
PANEL_DOMAIN=$SCRIPT_PANEL_DOMAIN
EOF

    # Создание docker-compose.yml для remnawave-subscription-page
    cat >docker-compose.yml <<"EOF"
services:
    remnawave-subscription-page:
        image: remnawave/subscription-page:latest
        container_name: remnawave-subscription-page
        hostname: remnawave-subscription-page
        restart: always
        env_file:
            - .env
        environment:
            - REMNAWAVE_PLAIN_DOMAIN=${PANEL_DOMAIN}
            - SUBSCRIPTION_PAGE_PORT=3010
        ports:
            - '127.0.0.1:3010:3010'
        networks:
            - remnawave-network

networks:
    remnawave-network:
        driver: bridge
        external: true
EOF

    # Создание Makefile для remnawave-subscription-page
    create_makefile "$REMNAWAVE_DIR/subscription-page"

    echo -e "${BOLD_GREEN}Конфигурация remnawave-subscription-page завершена.${NC}"
}
