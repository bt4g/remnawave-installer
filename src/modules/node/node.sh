# ===================================================================================
#                              REMNAWAVE NODE INSTALLATION
# ===================================================================================

# Create docker-compose.yml for node
create_node_docker_compose() {
    mkdir -p $REMNANODE_DIR && cd $REMNANODE_DIR
    cat >docker-compose.yml <<EOL
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:dev
    env_file:
      - .env
    network_mode: host
    restart: always
EOL
}

collect_node_selfsteal_domain() {
    SELF_STEAL_DOMAIN=$(prompt_domain "Enter Selfsteal domain, e.g. domain.example.com" "$ORANGE" true false false)
}

check_node_ports() {
    if CADDY_LOCAL_PORT=$(check_required_port "9443"); then
        show_info "Required Caddy port 9443 is available"
    else
        show_error "Required Caddy port 9443 is already in use!"
        show_error "For separate node installation, port 9443 must be available."
        show_error "Please free up port 9443 and try again."
        show_error "Installation cannot continue with occupied port 9443"
        exit 1
    fi

    # Check required Node API port 2222
    if NODE_PORT=$(check_required_port "2222"); then
        show_info "Required Node API port 2222 is available"
    else
        show_error "Required Node API port 2222 is already in use!"
        show_error "For separate node installation, port 2222 must be available."
        show_error "Please free up port 2222 and try again."
        show_error "Installation cannot continue with occupied port 2222"
        exit 1
    fi
}

# Collect SSL certificate for node
collect_node_ssl_certificate() {
    while true; do
        echo -e "${ORANGE}Enter the server certificate in format SSL_CERT=\"...\" (paste the content and press Enter twice): ${NC}"
        CERTIFICATE=""
        while IFS= read -r line; do
            if [ -z "$line" ]; then
                if [ -n "$CERTIFICATE" ]; then
                    break
                fi
            else
                CERTIFICATE="${CERTIFICATE}${line}"
            fi
        done

        # Validate SSL certificate format
        if validate_ssl_certificate "$CERTIFICATE"; then
            echo -e "${BOLD_GREEN}✓ SSL certificate format is valid${NC}"
            echo
            break
        else
            echo -e "${BOLD_RED}✗ Invalid SSL certificate format. Please try again.${NC}"
            echo -e "${YELLOW}Expected format: SSL_CERT=\"...eyJub2RlQ2VydFBldW0iOiAi...\"${NC}"
            echo
        fi
    done
}

# Create .env file for node
create_node_env_file() {
    echo -e "### APP ###" >.env
    echo -e "APP_PORT=$NODE_PORT" >>.env
    echo -e "$CERTIFICATE" >>.env
}

# Start node container and show results
start_node_and_show_results() {
    if ! start_container "$REMNANODE_DIR" "remnanode" "Remnawave Node"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi

    echo -e "${LIGHT_GREEN}• Node port: ${BOLD_GREEN}$NODE_PORT${NC}"
    echo -e "${LIGHT_GREEN}• Node directory: ${BOLD_GREEN}$REMNANODE_DIR${NC}"
    echo
}

collect_panel_ip() {
    while true; do
        PANEL_IP=$(simple_read_domain_or_ip "Enter the IP address of the panel server (for configuring firewall)" "" "ip_only")
        if [ -n "$PANEL_IP" ]; then
            break
        fi
    done
}

allow_ufw_node_port_from_panel_ip() {
    echo "Allow connections from panel server to node port 2222..."
    echo
    ufw allow from "$PANEL_IP" to any port 2222 proto tcp
    echo
    ufw reload >/dev/null 2>&1
}

setup_node() {
    clear

    # Preparation
    if ! prepare_installation; then
        return 1
    fi

    create_node_docker_compose

    create_makefile "$REMNANODE_DIR"

    collect_node_selfsteal_domain

    collect_panel_ip

    allow_ufw_node_port_from_panel_ip

    check_node_ports

    collect_node_ssl_certificate

    create_node_env_file

    setup_selfsteal

    start_node_and_show_results

    unset CERTIFICATE
    unset NODE_PORT

    echo -e "\n${BOLD_GREEN}Press Enter to return to the main menu...${NC}"
    read -r
}
