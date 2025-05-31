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
            echo
            show_success "Previous installation removed."
        fi
    elif [ "$from_menu" = true ]; then
        echo ''
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
            if ! start_container "/opt/remnawave" "remnawave/backend" "Remnawave Panel"; then
                return 1
            fi

            # Start subscription page if it exists
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                show_info "Starting subscription page..." "$ORANGE"
                if ! start_container "/opt/remnawave/subscription-page" "remnawave/subscription-page" "Subscription Page"; then
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

# Check for specific Docker errors and provide solutions
check_docker_rate_limit() {
    local error_output="$1"
    local service_name="$2"

    # Check for rate limit error
    if echo "$error_output" | grep -q "toomanyrequests.*pull rate limit"; then
        show_error "Docker Hub rate limit exceeded for $service_name"
        show_info "Cause: Docker Hub pull rate limit exceeded" "$BOLD_YELLOW"
        echo -e "${ORANGE}Possible solutions:${NC}"
        echo -e "${GREEN}1. Wait 6 hours and retry installation${NC}"
        echo -e "${GREEN}2. Login to Docker Hub: docker login${NC}"
        echo -e "${GREEN}3. Use VPN or different IP address${NC}"
        echo -e "${GREEN}4. Configure Docker Hub mirror${NC}"
        echo
        return 0 # Rate limit detected
    fi

    return 1 # No rate limit detected
}

# Check if all required containers are running
check_containers_health() {
    local directory="$1"
    local expected_containers=("$@")
    shift # Remove directory from arguments

    cd "$directory"

    local failed_containers=()
    local running_containers=$(docker compose ps --services --filter "status=running" 2>/dev/null)

    for container in "${expected_containers[@]}"; do
        if ! echo "$running_containers" | grep -q "^$container$"; then
            failed_containers+=("$container")
        fi
    done

    if [ ${#failed_containers[@]} -gt 0 ]; then
        show_error "The following containers failed to start: ${failed_containers[*]}"
        return 1
    fi

    return 0
}

start_container() {
    local directory="$1"      # Directory with docker-compose.yml
    local container_name="$2" # Container name to check in docker ps
    local service_name="$3"   # Service name for messages
    local wait_time=${4:-3}   # Wait time in seconds (increased default)

    cd "$directory"

    # Capture both stdout and stderr
    local temp_output=$(mktemp)
    local temp_error=$(mktemp)

    (
        docker compose up -d >"$temp_output" 2>"$temp_error"
        sleep $wait_time
    ) &

    local bg_pid=$!

    spinner $bg_pid "Starting container ${service_name}..."

    wait $bg_pid
    local docker_exit_code=$?

    local error_output=$(cat "$temp_error")
    local stdout_output=$(cat "$temp_output")

    # Clean up temp files
    rm -f "$temp_output" "$temp_error"

    # Check if docker compose command failed with non-zero exit code
    if [ $docker_exit_code -ne 0 ]; then
        show_error "Failed to start $service_name"

        local combined_output="$error_output$stdout_output"
        if ! check_docker_rate_limit "$combined_output" "$service_name"; then
            local container_logs=$(docker compose logs --tail=100 2>/dev/null || echo "Unable to get logs")
        fi

        echo -e "${ORANGE}Diagnostic commands:${NC}"
        echo -e "${GREEN}cd $directory && docker compose logs${NC}"
        echo -e "${GREEN}cd $directory && docker compose ps${NC}"
        echo -e "${ORANGE}You can check logs later using 'make logs' in directory $directory${NC}"
        echo
        return 1
    fi
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

    if ! start_container "$REMNAWAVE_DIR" "remnawave/backend" "Remnawave/backend"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi

    if ! start_container "$REMNAWAVE_DIR/subscription-page" "remnawave/subscription-page" "Subscription page"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi
}
