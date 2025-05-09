#!/bin/bash

# ===================================================================================
#                              REMNAWAVE PANEL INSTALLATION
# ===================================================================================

install_panel_all_in_one() {
    clear_screen

    # Install general dependencies
    install_dependencies

    remove_previous_installation

    mkdir -p $REMNAWAVE_DIR/caddy

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
    if prompt_yes_no "Do you want to enable Telegram integration?"; then
        IS_TELEGRAM_ENV_VALUE="true"
        # If Telegram integration is enabled, ask for parameters
        TELEGRAM_BOT_TOKEN=$(prompt_input "Enter your Telegram bot token: " "$ORANGE")
        TELEGRAM_ADMIN_ID=$(prompt_input "Enter the Telegram admin ID: " "$ORANGE")
        NODES_NOTIFY_CHAT_ID=$(prompt_input "Enter the chat ID for notifications: " "$ORANGE")
    else
        # If Telegram integration is not enabled, set parameters to "change-me"
        IS_TELEGRAM_ENV_VALUE="false"
        show_warning "Skipping Telegram integration."
        TELEGRAM_BOT_TOKEN="change-me"
        TELEGRAM_ADMIN_ID="change-me"
        NODES_NOTIFY_CHAT_ID="change-me"
    fi

    # Ask for the main domain for the panel with integrated validation
    SCRIPT_PANEL_DOMAIN=$(prompt_domain "Enter the main domain for your panel, subscriptions, and selfsteal (e.g., panel.example.com)")
    SCRIPT_SUB_DOMAIN="$SCRIPT_PANEL_DOMAIN"
    # Ask for Selfsteal port with validation and default value 9443
    SELF_STEAL_PORT=$(read_port "Enter the port for Caddy - should not be 443 (you can leave the default)" "9443")
    echo ""
    # Ask for API node port with validation and default value 2222
    NODE_PORT=$(read_port "Enter the API node port (you can leave the default)" "2222")
    echo ""

    SUPERADMIN_USERNAME=$(generate_readable_login)
    SUPERADMIN_PASSWORD=$(generate_secure_password 25)

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

    # Generate a secret key to protect the admin panel
    PANEL_SECRET_KEY=$(openssl rand -hex 16)

    # Create docker-compose.yml for the panel
    curl -s -o docker-compose.yml https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml

    # Change the image to dev
    sed -i "s|image: remnawave/backend:latest|image: remnawave/backend:dev|" docker-compose.yml

    # Create Makefile
    create_makefile "$REMNAWAVE_DIR"

    # ===================================================================================
    # Install Caddy for the panel and subscriptions
    # ===================================================================================

    setup_caddy_all_in_one "$PANEL_SECRET_KEY" "$SCRIPT_PANEL_DOMAIN" "$SELF_STEAL_PORT"

    # Start all containers
    show_info "Starting containers..." "$BOLD_GREEN"

    # Start RemnaWave panel
    start_container "$REMNAWAVE_DIR" "remnawave/backend" "Remnawave"

    # Start Caddy
    start_container "$REMNAWAVE_DIR/caddy" "caddy-remnawave" "Caddy"

    REG_TOKEN=$(register_user "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -n "$REG_TOKEN" ]; then
        vless_configuration_all_in_one "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$REG_TOKEN" "$SELF_STEAL_PORT" "$NODE_PORT"
    else
        show_error "Failed to register user."
        exit 1
    fi

    setup_node_all_in_one "$SCRIPT_PANEL_DOMAIN" "$SELF_STEAL_PORT" "127.0.0.1:3000" "$REG_TOKEN" "$NODE_PORT"
    # Start the node
    start_container "$LOCAL_REMNANODE_DIR" "remnawave/node" "Remnawave Node"

    # Check if the node is running
    NODE_STATUS=$(docker compose ps --services --filter "status=running" | grep -q "node" && echo "running" || echo "stopped")

    if [ "$NODE_STATUS" = "running" ]; then
        echo -e "${BOLD_GREEN}✓ Remnawave node successfully installed and running!${NC}"
        echo ""
    fi

    # Save credentials to a file
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
