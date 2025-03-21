#!/bin/bash

# ===================================================================================
#                              УСТАНОВКА ПАНЕЛИ REMNAWAVE
# ===================================================================================

install_panel_all_in_one() {
    clear_screen

    # Проверка наличия предыдущей установки
    if [ -d "$REMNAWAVE_DIR" ]; then
        show_warning "Обнаружена предыдущая установка RemnaWave."
        if prompt_yes_no "Для продолжения требуется удалить предыдущую установку, подтверждаете удаление?" "$ORANGE"; then
            # Проверка наличия Caddy и его остановка
            if [ -f "$REMNAWAVE_DIR/caddy/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f caddy/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер Caddy"
            fi
            # Проверка наличия панели и её остановка
            if [ -f "$REMNAWAVE_DIR/panel/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнеры панели Remnawave"
            fi
            # Проверка наличия панели и её остановка
            if [ -f "$LOCAL_REMNANODE_DIR/docker-compose.yml" ]; then
                cd $LOCAL_REMNANODE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер ноды Remnawave"
            fi
            # Удаление директории
            rm -rf $REMNAWAVE_DIR >/dev/null 2>&1 &
            spinner $! "Удаляем каталог $REMNAWAVE_DIR"
            # Удаление томов Docker
            docker volume rm remnawave-db-data remnawave-redis-data >/dev/null 2>&1 &
            spinner $! "Удаляем тома Docker: remnawave-db-data и remnawave-redis-data"
            show_success "Проведено удаление предыдущей установки."
        else
            return 0
        fi
    fi

    # Установка общих зависимостей
    install_dependencies

    # Создаем базовую директорию для всего проекта
    mkdir -p $REMNAWAVE_DIR/{panel,caddy}

    # Переходим в директорию панели
    cd $REMNAWAVE_DIR/panel

    # Генерация JWT секретов с помощью openssl
    JWT_AUTH_SECRET=$(openssl rand -hex 32 | tr -d '\n')
    JWT_API_TOKENS_SECRET=$(openssl rand -hex 32 | tr -d '\n')

    # Генерация безопасных учетных данных
    DB_USER="remnawave_$(openssl rand -hex 4 | tr -d '\n')"
    DB_PASSWORD=$(generate_secure_password 16)
    DB_NAME="remnawave_db"
    METRICS_PASS=$(generate_secure_password 16)

    curl -s -o .env https://raw.githubusercontent.com/remnawave/backend/refs/heads/dev/.env.sample

    # Спрашиваем, нужна ли интеграция с Telegram
    if prompt_yes_no "Хотите включить интеграцию с Telegram?"; then
        IS_TELEGRAM_ENV_VALUE="true"
        # Если интеграция с Telegram включена, запрашиваем параметры
        TELEGRAM_BOT_TOKEN=$(prompt_input "Введите токен вашего Telegram бота: " "$ORANGE")
        TELEGRAM_ADMIN_ID=$(prompt_input "Введите ID администратора Telegram: " "$ORANGE")
        NODES_NOTIFY_CHAT_ID=$(prompt_input "Введите ID чата для уведомлений: " "$ORANGE")
    else
        # Если интеграция с Telegram не включена, устанавливаем параметры в "change-me"
        IS_TELEGRAM_ENV_VALUE="false"
        show_warning "Пропуск интеграции с Telegram."
        TELEGRAM_BOT_TOKEN="change-me"
        TELEGRAM_ADMIN_ID="change-me"
        NODES_NOTIFY_CHAT_ID="change-me"
    fi

    # Запрашиваем основной домен для панели с валидацией
    SCRIPT_PANEL_DOMAIN=$(prompt_domain "Введите основной домен для вашей панели, подписок и selfsteal (например, panel.example.com)")
    SCRIPT_SUB_DOMAIN="$SCRIPT_PANEL_DOMAIN"
    # Запрос порта Selfsteal с валидацией и дефолтным значением 9443
    SELF_STEAL_PORT=$(read_port "Введите порт для Caddy - не должен быть 443, не будет доступен снаружи (можно оставить по умолчанию)" "9443")
    echo ""
    # Запрос порта API ноды с валидацией и дефолтным значением 3001
    NODE_PORT=$(read_port "Введите порт API ноды (можно оставить по умолчанию)" "3001")
    echo ""

    # Выбор способа создания пароля
    draw_section_header "Выберите способ создания пароля" 50

    draw_menu_options "Ввести пароль вручную" "Автоматически сгенерировать надежный пароль"

    password_option=$(prompt_menu_option "Выберите опцию" "$GREEN" 1 2)

    SUPERADMIN_USERNAME=$(prompt_input "Пожалуйста, введите имя пользователя SuperAdmin: " "$ORANGE")

    if [ "$password_option" = "1" ]; then
        # Ручной ввод пароля
        SUPERADMIN_PASSWORD=$(prompt_secure_password "Введите пароль SuperAdmin (минимум 24 символа, должен содержать буквы разного регистра и цифры): " "Повторно введите пароль SuperAdmin для подтверждения: " 24)
    else
        # Автоматическая генерация пароля
        SUPERADMIN_PASSWORD=$(generate_secure_password 25)
    fi

    update_file ".env" \
        "JWT_AUTH_SECRET" "$JWT_AUTH_SECRET" \
        "JWT_API_TOKENS_SECRET" "$JWT_API_TOKENS_SECRET" \
        "IS_TELEGRAM_ENABLED" "$IS_TELEGRAM_ENV_VALUE" \
        "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN" \
        "TELEGRAM_ADMIN_ID" "$TELEGRAM_ADMIN_ID" \
        "NODES_NOTIFY_CHAT_ID" "$NODES_NOTIFY_CHAT_ID" \
        "SUB_PUBLIC_DOMAIN" "$SCRIPT_PANEL_DOMAIN/sub" \
        "DATABASE_URL" "postgresql://$DB_USER:$DB_PASSWORD@remnawave-db:5432/$DB_NAME" \
        "POSTGRES_USER" "$DB_USER" \
        "POSTGRES_PASSWORD" "$DB_PASSWORD" \
        "POSTGRES_DB" "$DB_NAME" \
        "METRICS_PASS" "$METRICS_PASS"

    # Генерация секретного ключа для защиты панели управления
    PANEL_SECRET_KEY=$(openssl rand -hex 16)

    # Создаем docker-compose.yml для панели
    curl -s -o docker-compose.yml https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml

    # Меняем образ на dev
    # sed -i "s|image: remnawave/backend:latest|image: remnawave/backend:dev|" docker-compose.yml

    # Создаем Makefile
    create_makefile "$REMNAWAVE_DIR/panel"

    # ===================================================================================
    # Установка Caddy для панели и подписок
    # ===================================================================================

    setup_caddy_all_in_one "$PANEL_SECRET_KEY" "$SCRIPT_PANEL_DOMAIN" "$SELF_STEAL_PORT"

    # Запуск всех контейнеров
    show_info "Запуск контейнеров..." "$BOLD_GREEN"

    # Запуск панели RemnaWave
    start_container "$REMNAWAVE_DIR/panel" "remnawave/backend" "Remnawave"

    # Запуск Caddy
    start_container "$REMNAWAVE_DIR/caddy" "caddy-remnawave" "Caddy"

    wait_for_panel "127.0.0.1:3000"

    REG_TOKEN=$(register_user "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -n "$REG_TOKEN" ]; then
        vless_configuration_all_in_one "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$REG_TOKEN" "$SELF_STEAL_PORT" "$NODE_PORT"
    else
        show_error "Не удалось зарегистрировать пользователя."
        exit 1
    fi

    setup_node_all_in_one "$SCRIPT_PANEL_DOMAIN" "$SELF_STEAL_PORT" "127.0.0.1:3000" "$REG_TOKEN" "$NODE_PORT"
    # Запуск ноды
    start_container "$LOCAL_REMNANODE_DIR" "remnawave/node" "Remnawave Node"

    # Проверяем, запущена ли нода
    NODE_STATUS=$(docker compose ps --services --filter "status=running" | grep -q "node" && echo "running" || echo "stopped")

    if [ "$NODE_STATUS" = "running" ]; then
        echo -e "${BOLD_GREEN}✓ Нода Remnawave успешно установлена и запущена!${NC}"
        echo ""
    fi

    # Сохранение учетных данных в файл
    CREDENTIALS_FILE="$REMNAWAVE_DIR/panel/credentials.txt"
    echo "PANEL DOMAIN: $SCRIPT_PANEL_DOMAIN" >>"$CREDENTIALS_FILE"
    echo "PANEL URL: https://$SCRIPT_PANEL_DOMAIN?caddy=$PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"
    echo "" >>"$CREDENTIALS_FILE"
    echo "SUPERADMIN USERNAME: $SUPERADMIN_USERNAME" >>"$CREDENTIALS_FILE"
    echo "SUPERADMIN PASSWORD: $SUPERADMIN_PASSWORD" >>"$CREDENTIALS_FILE"
    echo "" >>"$CREDENTIALS_FILE"
    echo "SECRET KEY: $PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"

    # Установка безопасных прав на файл с учетными данными
    chmod 600 "$CREDENTIALS_FILE"

    display_panel_installation_complete_message
}
