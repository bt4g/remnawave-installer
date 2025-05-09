#!/bin/bash

# ===================================================================================
#                               DOCKER CONTAINER FUNCTIONS
# ===================================================================================

# Function to check and remove previous installation
remove_previous_installation() {
    # Check for previous installation
    local containers=("remnawave-subscription-page" "remnawave" "remnawave-db" "remnawave-redis" "remnanode" "caddy-remnawave")
    local container_exists=false

    # Check if any of the containers exist
    for container in "${containers[@]}"; do
        if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$container"; then
            container_exists=true
            break
        fi
    done

    if [ -d "$REMNAWAVE_DIR" ] || [ "$container_exists" = true ]; then
        show_warning "Previous RemnaWave installation detected."
        if prompt_yes_no "To continue, you need to remove previous Remnawave installations. Confirm removal?" "$ORANGE"; then
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
            # Check for node and stop it
            if [ -f "$LOCAL_REMNANODE_DIR/docker-compose.yml" ]; then
                cd $LOCAL_REMNANODE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Stopping Remnawave node container"
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
            docker volume rm remnawave-db-data remnawave-redis-data >/dev/null 2>&1 &
            spinner $! "Removing Docker volumes: remnawave-db-data and remnawave-redis-data"
            show_success "Previous installation removed."
        else
            return 0
        fi
    fi
}

# Restart panel container and service
restart_panel() {
    local no_wait=${1:-false} # Optional parameter to skip waiting for user input
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

            # Start panel
            cd /opt/remnawave && docker compose up -d >/dev/null 2>&1 &
            spinner $! "Restarting panel..."

            # Start subscription page if it exists
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd /opt/remnawave/subscription-page && docker compose up -d >/dev/null 2>&1 &
                spinner $! "Restarting panel..."
            fi
            show_info "Panel restarted"
        fi
    fi
    if [ "$no_wait" != "true" ]; then
        echo -e "${BOLD_GREEN}Press Enter to continue...${NC}"
        read
    fi
}

# Start container with proper status checking
start_container() {
    local directory="$1"      # Directory with docker-compose.yml
    local container_name="$2" # Container name to check in docker ps
    local service_name="$3"   # Service name for messages
    local wait_time=${4:-1}   # Wait time in seconds

    # Change to the required directory
    cd "$directory"

    # Run the whole process in the background using a subshell
    (
        docker compose up -d >/dev/null 2>&1
        sleep $wait_time
    ) &

    local bg_pid=$!

    # Show spinner for the entire startup and wait process
    spinner $bg_pid "Starting container ${service_name}..."

    # Check container status
    if ! docker ps | grep -q "$container_name"; then
        echo -e "${BOLD_RED}Container $service_name did not start. Check the configuration.${NC}"
        echo -e "${ORANGE}You can check logs later using 'make logs' in directory $directory.${NC}"
        return 1
    else
        # echo -e "${BOLD_GREEN}$service_name started successfully.${NC}"
        # echo ""
        return 0
    fi
}

# Create a common Makefile for managing services
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
