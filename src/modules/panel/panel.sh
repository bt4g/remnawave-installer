#!/bin/bash

# ===================================================================================
#                              УСТАНОВКА ПАНЕЛИ REMNAWAVE
# ===================================================================================

wait_for_panel() {
    local panel_url="$1"
    local max_wait=180
    local temp_file=$(mktemp)

    # Запускаем проверку доступности сервера в фоновом процессе
    {
        local start_time=$(date +%s)
        local end_time=$((start_time + max_wait))

        while [ $(date +%s) -lt $end_time ]; do
            if curl -s --connect-timeout 1 "http://$panel_url/api/auth/register" >/dev/null; then
                echo "success" >"$temp_file"
                exit 0
            fi
            sleep 1
        done
        echo "timeout" >"$temp_file"
        exit 1
    } &
    local check_pid=$!

    spinner "$check_pid" "Ожидание инициализации панели..."

    if [ "$(cat "$temp_file")" = "success" ]; then
        show_success "Панель готова к работе!"
        rm -f "$temp_file"
        return 0
    else
        show_warning "Превышено максимальное время ожидания ($max_wait секунд)."
        show_info "Пробуем продолжить регистрацию в любом случае..."
        rm -f "$temp_file"
        return 1
    fi
}

register_user() {
    local panel_url="$1"
    local panel_domain="$2"
    local username="$3"
    local password="$4"
    local api_url="http://${panel_url}/api/auth/register"

    local reg_token=""
    local reg_error=""

    local response=$(
        curl -s "$api_url" \
        -H "Host: $panel_domain" \
        -H "X-Forwarded-For: $panel_url" \
        -H "X-Forwarded-Proto: https" \
        -H "Content-Type: application/json" \
        --data-raw '{"username":"'"$username"'","password":"'"$password"'"}'
    )

    if [ -z "$response" ]; then
        reg_error="Пустой ответ сервера"
        return 1
    elif [[ "$response" == *"accessToken"* ]]; then
        # Успешная регистрация
        reg_token=$(echo "$response" | jq -r '.response.accessToken')
        echo "$reg_token"
        return 0
    else
        echo "$response"
        return 1
    fi
}

install_panel() {
    clear_screen

    remove_previous_installation

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
    SCRIPT_PANEL_DOMAIN=$(prompt_domain "Введите основной домен для вашей панели (например, panel.example.com)")
    check_domain_points_to_server "$SCRIPT_PANEL_DOMAIN"
    domain_check_result=$?
    if [ $domain_check_result -eq 2 ]; then
        # Пользователь решил прервать установку
        return 1
    fi

    # Запрашиваем домен для подписок с валидацией
    SCRIPT_SUB_DOMAIN=$(prompt_domain "Введите домен для подписок (например, subs.example.com)")
    check_domain_points_to_server "$SCRIPT_SUB_DOMAIN"
    domain_check_result=$?
    if [ $domain_check_result -eq 2 ]; then
        # Пользователь решил прервать установку
        return 1
    fi

    # Запрос на установку remnawave-subscription-page
    if prompt_yes_no "Установить remnawave-subscription-page (https://remna.st/subscription-templating/installation)?"; then
        INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE="y"
    else
        INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE="n"
    fi

    SUPERADMIN_USERNAME=$(generate_readable_login)
    SUPERADMIN_PASSWORD=$(generate_secure_password 25)

    update_file ".env" \
    "JWT_AUTH_SECRET" "$JWT_AUTH_SECRET" \
    "JWT_API_TOKENS_SECRET" "$JWT_API_TOKENS_SECRET" \
    "IS_TELEGRAM_ENABLED" "$IS_TELEGRAM_ENV_VALUE" \
    "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN" \
    "TELEGRAM_ADMIN_ID" "$TELEGRAM_ADMIN_ID" \
    "NODES_NOTIFY_CHAT_ID" "$NODES_NOTIFY_CHAT_ID" \
    "SUB_PUBLIC_DOMAIN" "$SCRIPT_SUB_DOMAIN" \
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
    # Установка remnawave-subscription-page
    # ===================================================================================

    # Установка remnawave-subscription-page, если пользователь согласился
    if [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "y" ] || [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "yes" ]; then
        setup_remnawave-subscription-page
    fi

    # ===================================================================================
    # Установка Caddy для панели и подписок
    # ===================================================================================

    setup_caddy_for_panel "$PANEL_SECRET_KEY"

    # Запуск всех контейнеров
    show_info "Запуск контейнеров..." "$BOLD_GREEN"

    # Запуск панели RemnaWave
    start_container "$REMNAWAVE_DIR/panel" "remnawave/backend" "Remnawave"

    # Запуск Caddy
    start_container "$REMNAWAVE_DIR/caddy" "caddy-remnawave" "Caddy"

    # Запуск remnawave-subscription-page (если был выбран)
    if [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "y" ] || [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "yes" ]; then
        start_container "$REMNAWAVE_DIR/subscription-page" "remnawave/subscription-page" "Subscription page"
    fi

    wait_for_panel "127.0.0.1:3000"

    REG_TOKEN=$(register_user "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -n "$REG_TOKEN" ]; then
        vless_configuration "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$REG_TOKEN"
    else
        show_error "Не удалось зарегистрировать пользователя."
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
