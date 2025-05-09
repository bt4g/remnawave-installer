#!/bin/bash

# ===================================================================================
#                              REMNAWAVE PANEL INSTALLATION
# ===================================================================================

install_panel() {
    clear_screen

    # Install common dependencies
    install_dependencies

    remove_previous_installation

    # Create base directory for the whole project
    mkdir -p $REMNAWAVE_DIR/{panel,caddy}

    # Go to the panel directory
    cd $REMNAWAVE_DIR

    # Generate JWT secrets using openssl
    JWT_AUTH_SECRET=$(openssl rand -hex 32 | tr -d '\n')
    JWT_API_TOKENS_SECRET=$(openssl rand -hex 32 | tr -d '\n')

    # Generate secure credentials
    DB_USER="remnawave_$(openssl rand -hex 4 | tr -d '\n')"
    DB_PASSWORD=$(generate_secure_password 16)
    DB_NAME="remnawave_db"
    METRICS_PASS=$(generate_secure_password 16)

    curl -s -o .env https://raw.githubusercontent.com/remnawave/backend/refs/heads/dev/.env.sample

    # Ask if Telegram integration is needed
    if prompt_yes_no "Do you want to enable Telegram notifications?"; then
        ### TELEGRAM NOTIFICATIONS ###
        IS_TELEGRAM_NOTIFICATIONS_ENABLED=true
        TELEGRAM_BOT_TOKEN=$(prompt_input "Enter your Telegram bot token: " "$ORANGE")
        TELEGRAM_NOTIFY_USERS_CHAT_ID=$(prompt_input "Enter the users chat ID: " "$ORANGE")
        TELEGRAM_NOTIFY_NODES_CHAT_ID=$(prompt_input "Enter the nodes chat ID: " "$ORANGE")

        if prompt_yes_no "Do you want to use Telegram topics?"; then
            TELEGRAM_NOTIFY_USERS_THREAD_ID=$(prompt_input "Enter the users thread ID: " "$ORANGE")
            TELEGRAM_NOTIFY_NODES_THREAD_ID=$(prompt_input "Enter the nodes thread ID: " "$ORANGE")
        fi
    else
        show_warning "Skipping Telegram integration."
        IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
        TELEGRAM_BOT_TOKEN="change-me"
        TELEGRAM_NOTIFY_USERS_CHAT_ID="change-me"
        TELEGRAM_NOTIFY_NODES_CHAT_ID="change-me"
        TELEGRAM_NOTIFY_USERS_THREAD_ID=""
        TELEGRAM_NOTIFY_NODES_THREAD_ID=""
    fi

    SCRIPT_PANEL_DOMAIN=$(prompt_domain "Enter the main domain for your panel (for example, panel.example.com)")
    SCRIPT_SUB_DOMAIN=$(prompt_domain "Enter the domain for subscriptions (for example, subs.example.com)")
    SELF_STEAL_DOMAIN=$(simple_read_domain_or_ip "Enter Selfsteal domain, e.g. domain.example.com" "" "domain_only")
    SELF_STEAL_PORT=$(read_port "Enter Selfsteal port (default can be used)" "9443" true)
    NODE_HOST=$(simple_read_domain_or_ip "Enter the IP address or domain of the node server (if different from Selfsteal domain)" "$SELF_STEAL_DOMAIN")
    NODE_PORT=$(read_port "Enter node API port (default can be used)" "2222" true)

    if prompt_yes_no "Install remnawave-subscription-page (https://remna.st/subscription-templating/installation)?"; then
        INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE="y"
    else
        INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE="n"
    fi

    SUPERADMIN_USERNAME=$(generate_readable_login)
    SUPERADMIN_PASSWORD=$(generate_secure_password 25)

    update_file ".env" \
        "JWT_AUTH_SECRET" "$JWT_AUTH_SECRET" \
        "JWT_API_TOKENS_SECRET" "$JWT_API_TOKENS_SECRET" \
        "IS_TELEGRAM_NOTIFICATIONS_ENABLED" "$IS_TELEGRAM_NOTIFICATIONS_ENABLED" \
        "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN" \
        "TELEGRAM_NOTIFY_USERS_CHAT_ID" "$TELEGRAM_NOTIFY_USERS_CHAT_ID" \
        "TELEGRAM_NOTIFY_NODES_CHAT_ID" "$TELEGRAM_NOTIFY_NODES_CHAT_ID" \
        "TELEGRAM_NOTIFY_USERS_THREAD_ID" "$TELEGRAM_NOTIFY_USERS_THREAD_ID" \
        "TELEGRAM_NOTIFY_NODES_THREAD_ID" "$TELEGRAM_NOTIFY_NODES_THREAD_ID" \
        "SUB_PUBLIC_DOMAIN" "$SCRIPT_SUB_DOMAIN" \
        "DATABASE_URL" "postgresql://$DB_USER:$DB_PASSWORD@remnawave-db:5432/$DB_NAME" \
        "POSTGRES_USER" "$DB_USER" \
        "POSTGRES_PASSWORD" "$DB_PASSWORD" \
        "POSTGRES_DB" "$DB_NAME" \
        "METRICS_PASS" "$METRICS_PASS"

    # Generate a secret key to protect the admin panel
    PANEL_SECRET_KEY=$(openssl rand -hex 16)

    # Create docker-compose.yml for the panel
    curl -s -o docker-compose.yml https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml

    # Change image to dev
    sed -i "s|image: remnawave/backend:latest|image: remnawave/backend:dev|" docker-compose.yml

    # Create Makefile
    create_makefile "$REMNAWAVE_DIR"

    # ===================================================================================
    # Install remnawave-subscription-page
    # ===================================================================================

    if [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "y" ] || [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "yes" ]; then
        setup_remnawave-subscription-page
    fi

    # ===================================================================================
    # Install Caddy for panel and subscriptions
    # ===================================================================================

    setup_caddy_for_panel "$PANEL_SECRET_KEY"

    show_info "Starting containers..." "$BOLD_GREEN"

    start_container "$REMNAWAVE_DIR" "remnawave/backend" "Remnawave"

    start_container "$REMNAWAVE_DIR/caddy" "caddy-remnawave" "Caddy"

    if [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "y" ] || [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "yes" ]; then
        start_container "$REMNAWAVE_DIR/subscription-page" "remnawave/subscription-page" "Subscription page"
    fi

    REG_TOKEN=$(register_user "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -n "$REG_TOKEN" ]; then
        vless_configuration "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$REG_TOKEN"
    else
        show_error "Failed to register user."
    fi

    # Save credentials to file
    CREDENTIALS_FILE="$REMNAWAVE_DIR/credentials.txt"
    echo "PANEL DOMAIN: $SCRIPT_PANEL_DOMAIN" >>"$CREDENTIALS_FILE"
    echo "PANEL URL: https://$SCRIPT_PANEL_DOMAIN?caddy=$PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"
    echo "" >>"$CREDENTIALS_FILE"
    echo "SUPERADMIN USERNAME: $SUPERADMIN_USERNAME" >>"$CREDENTIALS_FILE"
    echo "SUPERADMIN PASSWORD: $SUPERADMIN_PASSWORD" >>"$CREDENTIALS_FILE"
    echo "" >>"$CREDENTIALS_FILE"
    echo "SECRET KEY: $PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"

    # Set secure permissions on the credentials file
    chmod 600 "$CREDENTIALS_FILE"

    display_panel_installation_complete_message
}
