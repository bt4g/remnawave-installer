#!/bin/bash

# ===================================================================================
#                              INSTALLATION OF STEAL ONESELF SITE
# ===================================================================================

setup_selfsteal() {
    mkdir -p $SELFSTEAL_DIR/html && cd $SELFSTEAL_DIR

    # Create .env file
    cat >.env <<EOF
# Domains
SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN
CADDY_LOCAL_PORT=$CADDY_LOCAL_PORT
EOF

    # Create Caddyfile
    cat >Caddyfile <<'EOF'
{
    admin   off
    https_port {$CADDY_LOCAL_PORT}
    default_bind 127.0.0.1
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
}

http://{$SELF_STEAL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
    root * /var/www/html
    try_files {path} /index.html
    file_server
}


:{$CADDY_LOCAL_PORT} {
    tls internal
    respond 204
}

:80 {
    bind 0.0.0.0
    respond 204
}
EOF

    # Create docker-compose.yml
    cat >docker-compose.yml <<EOF
services:
  caddy:
    image: caddy:2.10.0
    container_name: caddy-selfsteal
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/www/html
      - remnawave-caddy-ssl-data:/data
    env_file:
      - .env
    network_mode: "host"

volumes:
    remnawave-caddy-ssl-data:
        driver: local
        external: false
        name: remnawave-caddy-ssl-data
EOF

    create_makefile "$SELFSTEAL_DIR"

    create_static_site "$SELFSTEAL_DIR"

    # Start the service
    mkdir -p logs

    if ! start_container "$SELFSTEAL_DIR" "Caddy"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi

    # Check if the service is running
    CADDY_STATUS=$(docker compose ps --services --filter "status=running" | grep -q "caddy" && echo "running" || echo "stopped")

    if [ "$CADDY_STATUS" = "running" ]; then
        echo -e "${LIGHT_GREEN}• Domain: ${BOLD_GREEN}$SELF_STEAL_DOMAIN${NC}"
        echo -e "${LIGHT_GREEN}• Port: ${BOLD_GREEN}$CADDY_LOCAL_PORT${NC}"
        echo -e "${LIGHT_GREEN}• Directory: ${BOLD_GREEN}$SELFSTEAL_DIR${NC}"
        echo
    fi

    unset SELF_STEAL_DOMAIN
    unset CADDY_LOCAL_PORT
}
