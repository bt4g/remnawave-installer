#!/bin/bash

# ===================================================================================
#                              FULL AUTH SHARED FUNCTIONS
# ===================================================================================

# Collect full auth specific configuration from user
collect_full_auth_config() {
    AUTHP_ADMIN_EMAIL=$(prompt_email "Enter the admin email for Caddy Auth")
}

# Generate full auth specific secrets
generate_full_auth_secrets() {
    CUSTOM_LOGIN_ROUTE=$(generate_custom_path)
    AUTHP_ADMIN_USER=$(generate_readable_login)
    AUTHP_ADMIN_SECRET=$(generate_secure_password 25)
}

# Start Caddy with full auth
start_caddy_full_auth() {
    if ! start_container "$REMNAWAVE_DIR/caddy" "remnawave/caddy-with-auth" "Caddy"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi
}

# Save credentials for full auth
save_credentials_full_auth() {
    CREDENTIALS_FILE="$REMNAWAVE_DIR/credentials.txt"
    echo "PANEL URL: https://$PANEL_DOMAIN/$CUSTOM_LOGIN_ROUTE" >>"$CREDENTIALS_FILE"
    echo >>"$CREDENTIALS_FILE"
    echo "REMNAWAVE ADMIN USERNAME: $SUPERADMIN_USERNAME" >>"$CREDENTIALS_FILE"
    echo "REMNAWAVE ADMIN PASSWORD: $SUPERADMIN_PASSWORD" >>"$CREDENTIALS_FILE"
    echo >>"$CREDENTIALS_FILE"
    echo "CADDY AUTH USERNAME: $AUTHP_ADMIN_USER" >>"$CREDENTIALS_FILE"
    echo "CADDY AUTH PASSWORD: $AUTHP_ADMIN_SECRET" >>"$CREDENTIALS_FILE"
    echo "CADDY AUTH EMAIL: $AUTHP_ADMIN_EMAIL" >>"$CREDENTIALS_FILE"
    echo >>"$CREDENTIALS_FILE"

    chmod 600 "$CREDENTIALS_FILE"
}

display_full_auth_results() {
    local installation_type="${1:-panel}"
    local caddy_auth_url="https://$PANEL_DOMAIN/$CUSTOM_LOGIN_ROUTE/auth"

    # Calculate width based on longest line
    local max_width=${#caddy_auth_url}
    if [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$installation_type" = "all-in-one" ]; then
        if [ ${#USER_SUBSCRIPTION_URL} -gt $max_width ]; then
            max_width=${#USER_SUBSCRIPTION_URL}
        fi
    fi
    local effective_width=$((max_width + 3))
    local border_line=$(printf '─%.0s' $(seq 1 $effective_width))

    print_text_line() {
        local text="$1"
        local padding=$((effective_width - ${#text} - 1))
        echo -e "\033[1m│ $text$(printf '%*s' $padding)│\033[0m"
    }

    print_empty_line() {
        echo -e "\033[1m│$(printf '%*s' $effective_width)│\033[0m"
    }

    echo -e "\033[1m┌${border_line}┐\033[0m"

    print_text_line "Auth Portal page:"
    print_text_line "$caddy_auth_url"
    print_empty_line

    # Show subscription URL only for all-in-one installation
    if [ "$installation_type" = "all-in-one" ] && [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$USER_SUBSCRIPTION_URL" != "null" ]; then
        print_text_line "Subscription URL:"
        print_text_line "$USER_SUBSCRIPTION_URL"
        print_empty_line
    fi

    print_text_line "Caddy auth login: $AUTHP_ADMIN_USER"
    print_text_line "Caddy auth password: $AUTHP_ADMIN_SECRET"
    print_empty_line
    print_text_line "Remnawave admin login: $SUPERADMIN_USERNAME"
    print_text_line "Remnawave admin password: $SUPERADMIN_PASSWORD"
    print_empty_line
    echo -e "\033[1m└${border_line}┘\033[0m"

    echo
    show_success "Credentials saved in file: $CREDENTIALS_FILE"
    echo -e "${BOLD_BLUE}Installation directory: ${NC}$REMNAWAVE_DIR/"
    echo

    # Show QR code for subscription URL if available
    if [ "$installation_type" = "all-in-one" ] && [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$USER_SUBSCRIPTION_URL" != "null" ]; then
        generate_qr_code "$USER_SUBSCRIPTION_URL" "Subscription URL QR Code"
        echo
    fi

    cd ~

    echo -e "${BOLD_GREEN}Installation complete. Press Enter to continue...${NC}"
    read -r
}
