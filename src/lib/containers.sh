#!/bin/bash

# ===================================================================================
#                               DOCKER CONTAINER FUNCTIONS
# ===================================================================================

# Function to check and remove previous installation
remove_previous_installation() {
    local from_menu=${1:-false} # Optional parameter to indicate if called from menu
    # Check for previous installation
    local containers=("remnawave-subscription-page" "remnawave" "remnawave-db" "remnawave-redis" "remnanode" "caddy-remnawave" "caddy-selfsteal")
    local container_exists=false

    # Check if any of the containers exist
    for container in "${containers[@]}"; do
        if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$container"; then
            container_exists=true
            break
        fi
    done

    if [ -d "$REMNAWAVE_DIR" ] || [ "$container_exists" = true ]; then
        if [ "$from_menu" = true ]; then
            show_warning "RemnaWave installation detected."
            if prompt_yes_no "Are you sure you want to completely DELETE Remnawave? IT WILL REMOVE ALL DATA!!! Continue?" "$ORANGE"; then
                # Continue with removal
                :
            else
                return 1
            fi
        else
            show_warning "Previous RemnaWave installation detected."
            if prompt_yes_no "To continue, you need to DELETE previous Remnawave installation. IT WILL REMOVE ALL DATA!!! Continue?" "$ORANGE"; then
                # Continue with removal
                :
            else
                return 1
            fi
        fi

        # Check for Caddy and stop it
        if [ -f "$REMNAWAVE_DIR/caddy/docker-compose.yml" ]; then
            cd $REMNAWAVE_DIR && docker compose -f caddy/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Caddy container"
        fi
        # Check for subscription page and stop it
        if [ -f "$REMNAWAVE_DIR/subscription-page/docker-compose.yml" ]; then
            cd $REMNAWAVE_DIR && docker compose -f subscription-page/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping remnawave-subscription-page container"
        fi

        # Check for panel and stop it
        if [ -f "$REMNAWAVE_DIR/docker-compose.yml" ]; then
            cd $REMNAWAVE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Remnawave panel containers"
        fi
        # Check for panel and stop it
        if [ -f "$REMNAWAVE_DIR/panel/docker-compose.yml" ]; then
            cd $REMNAWAVE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Remnawave panel containers"
        fi
        # Check for selfsteal and stop it
        if [ -f "$SELFSTEAL_DIR/docker-compose.yml" ]; then
            cd $SELFSTEAL_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Caddy Selfsteal container"
        fi
        # Check for node and stop it
        if [ -f "$REMNANODE_DIR/docker-compose.yml" ]; then
            cd $REMNANODE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Remnawave node container"
        fi

        # Check for remaining containers and stop/remove them
        for container in "${containers[@]}"; do
            if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
                docker stop "$container" >/dev/null 2>&1 && docker rm "$container" >/dev/null 2>&1 &
                spinner $! "Stopping and removing container $container"
            fi
        done

        # Remove remaining Docker images
        docker rmi $(docker images -q) -f >/dev/null 2>&1 &
        spinner $! "Removing Docker images"

        # Remove directory
        rm -rf $REMNAWAVE_DIR >/dev/null 2>&1 &
        spinner $! "Removing directory $REMNAWAVE_DIR"
        # Remove Docker volumes
        docker volume rm remnawave-db-data remnawave-redis-data remnawave-caddy-ssl-data >/dev/null 2>&1 &
        spinner $! "Removing Docker volumes: remnawave-db-data and remnawave-redis-data and remnawave-caddy-ssl-data"

        if [ "$from_menu" = true ]; then
            show_success "Remnawave has been completely removed from your system. Press any key to continue..."
            read
        else
            show_success "Previous installation removed."
        fi
    elif [ "$from_menu" = true ]; then
        echo
        show_info "No Remnawave installation detected on this system."
        echo -e "${BOLD_GREEN}Press any key to continue...${NC}"
        read
    fi
}

# Restart panel container and service
restart_panel() {
    local no_wait=${1:-false} # Optional parameter to skip waiting for user input
    echo ''
    # Check for panel directory
    if [ ! -d /opt/remnawave ]; then
        show_error "Error: panel directory not found at /opt/remnawave!"
        show_error "Please install Remnawave panel first."
    else
        # Check for docker-compose.yml in panel directory
        if [ ! -f /opt/remnawave/docker-compose.yml ]; then
            show_error "Error: docker-compose.yml not found in panel directory!"
            show_error "Panel installation may be corrupted or incomplete."
        else
            # Variable to track subscription-page directory existence
            SUBSCRIPTION_PAGE_EXISTS=false

            # Check for subscription-page directory
            if [ -d /opt/remnawave/subscription-page ] && [ -f /opt/remnawave/subscription-page/docker-compose.yml ]; then
                SUBSCRIPTION_PAGE_EXISTS=true
            fi

            # Stop subscription page if it exists
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd /opt/remnawave/subscription-page && docker compose down >/dev/null 2>&1 &
                spinner $! "Stopping remnawave-subscription-page container"
            fi

            # Stop panel
            cd /opt/remnawave && docker compose down >/dev/null 2>&1 &
            spinner $! "Restarting panel..."

            # Start panel with error handling
            show_info "Starting main panel..." "$ORANGE"
            if ! start_container "/opt/remnawave" "Remnawave Panel"; then
                return 1
            fi

            # Start subscription page if it exists
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                show_info "Starting subscription page..." "$ORANGE"
                if ! start_container "/opt/remnawave/subscription-page" "Subscription Page"; then
                    return 1
                fi
            fi

            show_success "Panel restarted successfully"
        fi
    fi
    if [ "$no_wait" != "true" ]; then
        echo -e "${BOLD_GREEN}Press Enter to continue...${NC}"
        read
    fi
}

start_container() {
    local compose_dir="$1" display_name="$2"
    local max_wait=20 poll=1 tmp_log compose_file
    tmp_log=$(mktemp /tmp/docker-stack-XXXX.log)

    if [[ -z "$compose_dir" || -z "$display_name" ]]; then
        printf "${BOLD_RED}Error:${NC} provide directory and display name\n" >&2
        return 2
    fi
    if [[ ! -d "$compose_dir" ]]; then
        printf "${BOLD_RED}Error:${NC} directory “%s” not found\n" "$compose_dir" >&2
        return 2
    fi
    if [[ -f "$compose_dir/docker-compose.yml" ]]; then
        compose_file="$compose_dir/docker-compose.yml"
    elif [[ -f "$compose_dir/docker-compose.yaml" ]]; then
        compose_file="$compose_dir/docker-compose.yaml"
    else
        printf "${BOLD_RED}Error:${NC} docker-compose.yml not found in “%s”\n" "$compose_dir" >&2
        return 2
    fi
    if ! command -v docker >/dev/null 2>&1; then
        printf "${BOLD_RED}Error:${NC} Docker is not installed or not in PATH\n" >&2
        return 2
    fi
    if ! docker info >/dev/null 2>&1; then
        printf "${BOLD_RED}Error:${NC} Docker daemon is not running\n" >&2
        return 2
    fi

    (docker compose -f "$compose_file" up -d --force-recreate) \
        >"$tmp_log" 2>&1 &
    spinner $! "Launching “$display_name”"
    wait $!

    local output
    output=$(<"$tmp_log")

    if echo "$output" | grep -qiE 'toomanyrequests.*rate limit'; then
        printf "${BOLD_RED}✖ Docker Hub rate limit while pulling images for “%s”.${NC}\n" "$display_name" >&2
        printf "${BOLD_YELLOW}Cause:${NC} pull rate limit exceeded.\n" >&2
        echo -e "${ORANGE}Possible solutions:${NC}" >&2
        echo -e "${GREEN}1. Wait ~6 h and retry${NC}" >&2
        echo -e "${GREEN}2. docker login${NC}" >&2
        echo -e "${GREEN}3. Use VPN / other IP${NC}" >&2
        echo -e "${GREEN}4. Set up a mirror${NC}\n" >&2
        rm -f "$tmp_log"
        return 1
    fi

    mapfile -t services < <(docker compose -f "$compose_file" config --services)

    local all_ok=true elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        all_ok=true
        for svc in "${services[@]}"; do
            cid=$(docker compose -f "$compose_file" ps -q "$svc")
            state=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null)
            if [[ "$state" != "running" ]]; then
                all_ok=false
                break
            fi
        done
        $all_ok && break
        sleep $poll
        ((elapsed += poll))
    done

    if $all_ok; then
        printf "${BOLD_GREEN}✔ “%s” is up (services: %s).${NC}\n" \
            "$display_name" "$(
                IFS=,
                echo "${services[*]}"
            )"
        echo
        rm -f "$tmp_log"
        return 0
    fi

    printf "${BOLD_RED}✖ “%s” failed to start entirely.${NC}\n" "$display_name" >&2
    printf "${BOLD_RED}→ docker compose output:${NC}\n" >&2
    cat "$tmp_log" >&2
    printf "\n${BOLD_RED}→ Problematic services status:${NC}\n" >&2
    docker compose -f "$compose_file" ps >&2
    rm -f "$tmp_log"
    return 1
}

create_makefile() {
    local directory="$1"
    cat >"$directory/Makefile" <<'EOF'
.PHONY: start stop restart logs

start:
	docker compose up -d && docker compose logs -f -t
stop:
	docker compose down
restart:
	docker compose down && docker compose up -d
logs:
	docker compose logs -f -t
EOF
}

start_services() {
    echo
    show_info "Starting containers..." "$BOLD_GREEN"

    if ! start_container "$REMNAWAVE_DIR" "Remnawave/backend"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi

    if ! start_container "$REMNAWAVE_DIR/subscription-page" "Subscription page"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi
}
