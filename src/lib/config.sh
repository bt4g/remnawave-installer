#!/bin/bash

# ===================================================================================
#                                CONFIG FUNCTIONS
# ===================================================================================

# Function for safely updating .env file with multiple keys
update_file() {
    local env_file="$1"
    shift

    # Check for parameters
    if [ "$#" -eq 0 ] || [ $(($# % 2)) -ne 0 ]; then
        echo "Error: invalid number of arguments. Should be even number of keys and values." >&2
        return 1
    fi

    # Convert arguments to key and value arrays
    local keys=()
    local values=()

    while [ "$#" -gt 0 ]; do
        keys+=("$1")
        values+=("$2")
        shift 2
    done

    # Create a temporary file
    local temp_file=$(mktemp)

    # Process file line by line and replace needed lines
    while IFS= read -r line || [[ -n "$line" ]]; do
        local key_found=false
        for i in "${!keys[@]}"; do
            if [[ "$line" =~ ^${keys[$i]}= ]]; then
                echo "${keys[$i]}=${values[$i]}" >>"$temp_file"
                key_found=true
                break
            fi
        done

        if [ "$key_found" = false ]; then
            echo "$line" >>"$temp_file"
        fi
    done <"$env_file"

    # Replace original file
    mv "$temp_file" "$env_file"
}

# Collect Telegram configuration
collect_telegram_config() {
    if prompt_yes_no "Do you want to enable Telegram notifications?"; then
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
}

# Check if domain is unique among already collected domains
check_domain_uniqueness() {
    local new_domain="$1"
    local domain_type="$2"
    local existing_domains=("${@:3}")

    for existing_domain in "${existing_domains[@]}"; do
        if [ -n "$existing_domain" ] && [ "$new_domain" = "$existing_domain" ]; then
            show_error "Domain '$new_domain' is already used for another service!"
            show_error "Each domain must be unique: panel domain, subscription domain, and selfsteal domain must all be different."
            return 1
        fi
    done
    return 0
}

# Collect domain configuration (panel and subscription domains only)
collect_domain_config() {
    # First, collect panel domain
    PANEL_DOMAIN=$(prompt_domain "Enter the main domain for your panel (e.g., panel.example.com)")

    # Then collect subscription domain with uniqueness check
    while true; do
        SUB_DOMAIN=$(prompt_domain "Enter the subscription domain (e.g., sub.example.com)")

        # Check that subscription domain is different from panel domain
        if check_domain_uniqueness "$SUB_DOMAIN" "subscription" "$PANEL_DOMAIN"; then
            break
        fi
        show_warning "Please enter a different subscription domain."
    done
}

collect_ports_all_in_one() {
    CADDY_LOCAL_PORT=$(get_available_port "9443" "Caddy")
    NODE_PORT=$(get_available_port "2222" "Node API")
}

collect_ports_separate_installation() {
    # For separate installations, both CADDY_LOCAL_PORT and NODE_PORT must be fixed

    # Check Caddy port 9443
    if CADDY_LOCAL_PORT=$(check_required_port "9443"); then
        show_info "Required Caddy port 9443 is available"
    else
        show_error "Required Caddy port 9443 is already in use!"
        show_error "For separate panel and node installation, port 9443 must be available."
        show_error "Please free up port 9443 and try again."
        show_error "Installation cannot continue with occupied port 9443"
        return 1
    fi

    # Check Node API port 2222
    if NODE_PORT=$(check_required_port "2222"); then
        show_info "Required Node API port 2222 is available"
    else
        show_error "Required Node API port 2222 is already in use!"
        show_error "For separate panel and node installation, port 2222 must be available."
        show_error "Please free up port 2222 and try again."
        show_error "Installation cannot continue with occupied port 2222"
        return 1
    fi
}

# Setup common environment
setup_panel_environment() {
    # Download environment template
    curl -s -o .env https://raw.githubusercontent.com/remnawave/backend/refs/heads/dev/.env.sample

    # Update environment file
    update_file ".env" \
        "JWT_AUTH_SECRET" "$JWT_AUTH_SECRET" \
        "JWT_API_TOKENS_SECRET" "$JWT_API_TOKENS_SECRET" \
        "IS_TELEGRAM_NOTIFICATIONS_ENABLED" "$IS_TELEGRAM_NOTIFICATIONS_ENABLED" \
        "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN" \
        "TELEGRAM_NOTIFY_USERS_CHAT_ID" "$TELEGRAM_NOTIFY_USERS_CHAT_ID" \
        "TELEGRAM_NOTIFY_NODES_CHAT_ID" "$TELEGRAM_NOTIFY_NODES_CHAT_ID" \
        "TELEGRAM_NOTIFY_USERS_THREAD_ID" "$TELEGRAM_NOTIFY_USERS_THREAD_ID" \
        "TELEGRAM_NOTIFY_NODES_THREAD_ID" "$TELEGRAM_NOTIFY_NODES_THREAD_ID" \
        "SUB_PUBLIC_DOMAIN" "$SUB_DOMAIN" \
        "DATABASE_URL" "postgresql://$DB_USER:$DB_PASSWORD@remnawave-db:5432/$DB_NAME" \
        "POSTGRES_USER" "$DB_USER" \
        "POSTGRES_PASSWORD" "$DB_PASSWORD" \
        "POSTGRES_DB" "$DB_NAME" \
        "METRICS_PASS" "$METRICS_PASS"
}

setup_panel_docker_compose() {
    cat >>docker-compose.yml <<"EOF"
services:
  remnawave-db:
    image: postgres:17
    container_name: 'remnawave-db'
    hostname: remnawave-db
    restart: always
    env_file:
      - .env
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - TZ=UTC
    ports:
      - '127.0.0.1:6767:5432'
    volumes:
      - remnawave-db-data:/var/lib/postgresql/data
    networks:
      - remnawave-network
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}']
      interval: 3s
      timeout: 10s
      retries: 3

  remnawave:
    image: remnawave/backend:dev
    container_name: 'remnawave'
    hostname: remnawave
    restart: always
    ports:
      - '127.0.0.1:3000:3000'
    env_file:
      - .env
    networks:
      - remnawave-network
    depends_on:
      remnawave-db:
        condition: service_healthy
      remnawave-redis:
        condition: service_healthy

  remnawave-redis:
    image: valkey/valkey:8.0.2-alpine
    container_name: remnawave-redis
    hostname: remnawave-redis
    restart: always
    networks:
      - remnawave-network
    volumes:
      - remnawave-redis-data:/data
    healthcheck:
      test: [ "CMD", "valkey-cli", "ping" ]
      interval: 3s
      timeout: 10s
      retries: 3

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16
    external: false

volumes:
  remnawave-db-data:
    driver: local
    external: false
    name: remnawave-db-data
  remnawave-redis-data:
    driver: local
    external: false
    name: remnawave-redis-data
EOF
}
