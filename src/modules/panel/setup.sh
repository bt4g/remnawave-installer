#!/bin/bash

# ===================================================================================
#                              REMNAWAVE PANEL INSTALLATION
# ===================================================================================

# Generate secrets for panel installation
generate_secrets_panel_only() {
    local auth_type=$1

    generate_secrets
    if [ "$auth_type" = "full" ]; then
        generate_full_auth_secrets
    else
        if [ "$auth_type" = "cookie" ]; then
            generate_cookie_auth_secrets
        fi
    fi
}

collect_selfsteal_domain_for_panel() {
    while true; do
        # 3 - true show_warning
        # 4 - false allow_cf_proxy
        # 5 - true expect_different_ip
        SELF_STEAL_DOMAIN=$(prompt_domain "Enter Selfsteal domain (will be used on node server), e.g. domain.example.com" "$ORANGE" true false true)

        # Check that selfsteal domain is different from panel and subscription domains
        if check_domain_uniqueness "$SELF_STEAL_DOMAIN" "selfsteal" "$PANEL_DOMAIN" "$SUB_DOMAIN"; then
            break
        fi
        show_warning "Please enter a different domain for selfsteal service."
        echo
    done
}

# Collect configuration for panel installation
collect_config_panel_only() {
    local auth_type=$1

    collect_telegram_config
    collect_domain_config
    collect_selfsteal_domain_for_panel

    # Use separate installation port collection
    if ! collect_ports_separate_installation; then
        return 1
    fi

    if [ "$auth_type" = "full" ]; then
        collect_full_auth_config
    fi
}

# Setup Caddy for panel installation
setup_caddy_panel_only() {
    local auth_type=$1

    if [ "$auth_type" = "cookie" ]; then
        setup_caddy_for_panel "$PANEL_SECRET_KEY"
    else
        if [ "$auth_type" = "full" ]; then
            setup_caddy_panel_only_full_auth
        fi
    fi
}

# Start Caddy for panel installation
start_caddy_panel_only() {
    local auth_type=$1

    if [ "$auth_type" = "cookie" ]; then
        start_caddy_cookie_auth
    else
        if [ "$auth_type" = "full" ]; then
            start_caddy_full_auth
        fi
    fi
}

# Save credentials and display results for panel installation
save_and_display_panel_only() {
    local auth_type=$1

    if [ "$auth_type" = "cookie" ]; then
        save_credentials_cookie_auth
        display_cookie_auth_results "panel"
    else
        if [ "$auth_type" = "full" ]; then
            save_credentials_full_auth
            display_full_auth_results "panel"
        fi
    fi
}

# Main panel installation function using composition
install_panel_only() {
    local auth_type=$1

    # Validate auth type
    if [[ "$auth_type" != "cookie" && "$auth_type" != "full" ]]; then
        show_error "Invalid auth type: $auth_type. Must be 'cookie' or 'full'"
        return 1
    fi

    # Preparation
    if ! prepare_installation; then
        return 1
    fi

    # Generate secrets
    generate_secrets_panel_only $auth_type

    # Collect configuration
    if ! collect_config_panel_only $auth_type; then
        return 1
    fi

    setup_panel_docker_compose

    setup_panel_environment

    create_makefile "$REMNAWAVE_DIR"

    # Setup components
    setup_caddy_panel_only $auth_type
    setup_remnawave-subscription-page

    # Start services
    start_services
    start_caddy_panel_only $auth_type

    # Register user and configure VLESS
    register_panel_user
    configure_vless_panel_only

    # Save credentials and display results
    save_and_display_panel_only $auth_type
}
