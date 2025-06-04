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
    image: remnawave/node:$REMNAWAVE_NODE_TAG
    env_file:
      - .env
    network_mode: host
    restart: always
EOL
}

collect_node_selfsteal_domain() {
    SELF_STEAL_DOMAIN=$(prompt_domain "$(t node_enter_selfsteal_domain)" "$ORANGE" true false false)
}

check_node_ports() {
    if CADDY_LOCAL_PORT=$(check_required_port "9443"); then
        show_info "$(t config_caddy_port_available)"
    else
        show_error "$(t node_port_9443_in_use)"
        show_error "$(t node_separate_port_9443)"
        show_error "$(t node_free_port_9443)"
        show_error "$(t node_cannot_continue_9443)"
        exit 1
    fi

    # Check required Node API port 2222
    if NODE_PORT=$(check_required_port "2222"); then
        show_info "$(t config_node_port_available)"
    else
        show_error "$(t node_port_2222_in_use)"
        show_error "$(t node_separate_port_2222)"
        show_error "$(t node_free_port_2222)"
        show_error "$(t node_cannot_continue_2222)"
        exit 1
    fi
}

# Collect SSL certificate for node
collect_node_ssl_certificate() {
    while true; do
        echo -e "${ORANGE}$(t node_enter_ssl_cert) ${NC}"
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
            echo -e "${BOLD_GREEN}$(t node_ssl_cert_valid)${NC}"
            echo
            break
        else
            echo -e "${BOLD_RED}$(t node_ssl_cert_invalid)${NC}"
            echo -e "${YELLOW}$(t node_ssl_cert_expected)${NC}"
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
    if ! start_container "$REMNANODE_DIR" "Remnawave Node"; then
        show_info "$(t services_installation_stopped)" "$BOLD_RED"
        exit 1
    fi

    echo -e "${LIGHT_GREEN}$(t node_port_info) ${BOLD_GREEN}$NODE_PORT${NC}"
    echo -e "${LIGHT_GREEN}$(t node_directory_info) ${BOLD_GREEN}$REMNANODE_DIR${NC}"
    echo
}

collect_panel_ip() {
    while true; do
        PANEL_IP=$(simple_read_domain_or_ip "$(t node_enter_panel_ip)" "" "ip_only")
        if [ -n "$PANEL_IP" ]; then
            break
        fi
    done
}

allow_ufw_node_port_from_panel_ip() {
    echo "$(t node_allow_connections)"
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

    echo -e "\n${BOLD_GREEN}$(t node_press_enter_return)${NC}"
    read -r
}
