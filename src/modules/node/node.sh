# ===================================================================================
#                              REMNAWAVE NODE INSTALLATION
# ===================================================================================

setup_node() {
    clear

    # Install common dependencies
    install_dependencies

    # Check for previous installation
    if [ -d "$REMNANODE_ROOT_DIR" ]; then
        show_warning "Previous Remnawave Node installation detected."
        if prompt_yes_no "To continue, the previous installation must be removed. Do you confirm removal?" "$ORANGE"; then
            # Stop main container
            if [ -f "$REMNANODE_DIR/docker-compose.yml" ]; then
                cd $REMNANODE_DIR && docker compose -f docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Stopping Remnawave Node container"
            fi

            # Stop selfsteal container
            if [ -f "$SELFSTEAL_DIR/docker-compose.yml" ]; then
                cd $SELFSTEAL_DIR && docker compose -f docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Stopping Selfsteal container"
            fi

            # Remove directory
            rm -rf $REMNANODE_ROOT_DIR >/dev/null 2>&1 &
            spinner $! "Removing directory $REMNANODE_ROOT_DIR"

            show_success "Previous installation removed."
        else
            return 0
        fi
    fi

    mkdir -p $REMNANODE_DIR && cd $REMNANODE_DIR
    # Create docker-compose.yml
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

    # Create Makefile for the node
    create_makefile "$REMNANODE_DIR"

    # Request Selfsteal domain with validation
    SELF_STEAL_DOMAIN=$(prompt_domain "Enter Selfsteal domain, e.g. domain.example.com" "$ORANGE" true false)

    # Request Selfsteal port with validation and default value
    SELF_STEAL_PORT=$(read_port "Enter Selfsteal port (default can be used)" "9443")

    # Request node API port with validation and default value
    NODE_PORT=$(read_port "Enter node API port (default can be used)" "2222")

    echo -e "${ORANGE}Enter the server certificate, DO NOT remove SSL_CERT= (paste the content and press Enter twice): ${NC}"
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

    echo -ne "${BOLD_RED}Are you sure the certificate is correct? (y/n): ${NC}"
    read confirm
    echo

    echo -e "### APP ###" >.env
    echo -e "APP_PORT=$NODE_PORT" >>.env
    echo -e "$CERTIFICATE" >>.env

    setup_selfsteal

    start_container "$REMNANODE_DIR" "remnawave/node" "Remnawave Node"

    unset CERTIFICATE

    # Check if the node is running
    NODE_STATUS=$(docker compose ps --services --filter "status=running" | grep -q "node" && echo "running" || echo "stopped")

    if [ "$NODE_STATUS" = "running" ]; then
        echo -e "${BOLD_GREEN}✓ Remnawave Node successfully installed and started!${NC}"
        echo -e "${LIGHT_GREEN}• Node port: ${BOLD_GREEN}$NODE_PORT${NC}"
        echo -e "${LIGHT_GREEN}• Node directory: ${BOLD_GREEN}$REMNANODE_DIR${NC}"
        echo ""
    fi

    unset NODE_PORT

    echo -e "\n${BOLD_GREEN}Press Enter to return to the main menu...${NC}"
    read -r

}
