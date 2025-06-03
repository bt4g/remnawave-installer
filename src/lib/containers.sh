#!/bin/bash

# ===================================================================================
#                               DOCKER CONTAINER FUNCTIONS
# ===================================================================================

remove_previous_installation() {
    local from_menu=${1:-false}

    # Check if installation directory exists
    if [ -d "$REMNAWAVE_DIR" ]; then
        # Show warning and request confirmation (keep as is)
        if [ "$from_menu" = true ]; then
            show_warning "$(t removal_installation_detected)"
            if ! prompt_yes_no "$(t removal_confirm_delete)" "$ORANGE"; then
                return 1
            fi
        else
            show_warning "$(t removal_previous_detected)"
            if ! prompt_yes_no "$(t removal_confirm_continue)" "$ORANGE"; then
                return 1
            fi
        fi

        # Array of compose files to process
        local compose_configs=(
            "$REMNAWAVE_DIR/caddy/docker-compose.yml"
            "$REMNAWAVE_DIR/subscription-page/docker-compose.yml"
            "$REMNAWAVE_DIR/docker-compose.yml"
            "$REMNANODE_DIR/docker-compose.yml"
            "$SELFSTEAL_DIR/docker-compose.yml"
            "$REMNAWAVE_DIR/panel/docker-compose.yml" # Old path - for backward compatibility
            "$REMNANODE_DIR/node/docker-compose.yml"  # Old path - for backward compatibility
        )

        # Process each compose file
        for compose_file in "${compose_configs[@]}"; do
            if [ -f "$compose_file" ]; then
                local dir_path=$(dirname "$compose_file")
                cd "$dir_path" && docker compose down -v --rmi local --remove-orphans >/dev/null 2>&1 &
                spinner $! "$(t spinner_cleaning_services) $(basename "$dir_path")"
            fi
        done

        # Force cleanup of remaining containers (if any)
        local containers=("remnawave-subscription-page" "remnawave" "remnawave-db" "remnawave-redis" "remnanode" "caddy-remnawave" "caddy-selfsteal")
        for container in "${containers[@]}"; do
            if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
                docker stop "$container" >/dev/null 2>&1 && docker rm "$container" >/dev/null 2>&1 &
                spinner $! "$(t spinner_force_removing) $container"
            fi
        done

        # Remove directory
        rm -rf "$REMNAWAVE_DIR" >/dev/null 2>&1 &
        spinner $! "$(t spinner_removing_directory) $REMNAWAVE_DIR"

        # Show result
        if [ "$from_menu" = true ]; then
            show_success "$(t removal_complete_success)"
            read
        else
            show_success "$(t removal_previous_success)"
        fi
    else
        if [ "$from_menu" = true ]; then
            echo
            show_info "$(t removal_no_installation)"
            echo -e "${BOLD_GREEN}$(t prompt_press_any_key)${NC}"
            read
        fi
    fi
}

# Restart panel container and service
restart_panel() {
    local no_wait=${1:-false} # Optional parameter to skip waiting for user input
    echo ''
    # Check for panel directory
    if [ ! -d /opt/remnawave ]; then
        show_error "$(t restart_panel_dir_not_found)"
        show_error "$(t restart_install_panel_first)"
    else
        # Check for docker-compose.yml in panel directory
        if [ ! -f /opt/remnawave/docker-compose.yml ]; then
            show_error "$(t restart_compose_not_found)"
            show_error "$(t restart_installation_corrupted)"
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
                spinner $! "$(t spinner_stopping_subscription)"
            fi

            # Stop panel
            cd /opt/remnawave && docker compose down >/dev/null 2>&1 &
            spinner $! "$(t spinner_restarting_panel)"

            # Start panel with error handling
            show_info "$(t restart_starting_panel)" "$ORANGE"
            if ! start_container "/opt/remnawave" "Remnawave Panel"; then
                return 1
            fi

            # Start subscription page if it exists
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                show_info "$(t restart_starting_subscription)" "$ORANGE"
                if ! start_container "/opt/remnawave/subscription-page" "Subscription Page"; then
                    return 1
                fi
            fi

            show_success "$(t restart_success)"
        fi
    fi
    if [ "$no_wait" != "true" ]; then
        echo -e "${BOLD_GREEN}$(t prompt_enter_to_continue)${NC}"
        read
    fi
}

start_container() {
    local compose_dir="$1" display_name="$2"
    local max_wait=20 poll=1 tmp_log compose_file
    tmp_log=$(mktemp /tmp/docker-stack-XXXX.log)

    if [[ -z "$compose_dir" || -z "$display_name" ]]; then
        printf "${BOLD_RED}$(t container_error_provide_args)${NC}\n" >&2
        return 2
    fi
    if [[ ! -d "$compose_dir" ]]; then
        printf "${BOLD_RED}$(t container_error_directory_not_found)${NC}\n" "$compose_dir" >&2
        return 2
    fi
    if [[ -f "$compose_dir/docker-compose.yml" ]]; then
        compose_file="$compose_dir/docker-compose.yml"
    elif [[ -f "$compose_dir/docker-compose.yaml" ]]; then
        compose_file="$compose_dir/docker-compose.yaml"
    else
        printf "${BOLD_RED}$(t container_error_compose_not_found)${NC}\n" "$compose_dir" >&2
        return 2
    fi
    if ! command -v docker >/dev/null 2>&1; then
        printf "${BOLD_RED}$(t container_error_docker_not_installed)${NC}\n" >&2
        return 2
    fi
    if ! docker info >/dev/null 2>&1; then
        printf "${BOLD_RED}$(t container_error_docker_not_running)${NC}\n" >&2
        return 2
    fi

    (docker compose -f "$compose_file" up -d --force-recreate --remove-orphans) \
        >"$tmp_log" 2>&1 &
    spinner $! "$(t spinner_launching) $display_name"
    wait $!

    local output
    output=$(<"$tmp_log")

    if echo "$output" | grep -qiE 'toomanyrequests.*rate limit'; then
        printf "${BOLD_RED}$(t container_rate_limit_error)${NC}\n" "$display_name" >&2
        printf "${BOLD_YELLOW}$(t container_rate_limit_cause)${NC}\n" >&2
        echo -e "${ORANGE}$(t container_rate_limit_solutions)${NC}" >&2
        echo -e "${GREEN}$(t container_rate_limit_wait)${NC}" >&2
        echo -e "${GREEN}$(t container_rate_limit_login)${NC}" >&2
        echo -e "${GREEN}$(t container_rate_limit_vpn)${NC}" >&2
        echo -e "${GREEN}$(t container_rate_limit_mirror)${NC}\n" >&2
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
        printf "${BOLD_GREEN}$(t container_success_up)${NC}\n" \
            "$display_name" "$(
                IFS=,
                echo "${services[*]}"
            )"
        echo
        rm -f "$tmp_log"
        return 0
    fi

    printf "${BOLD_RED}$(t container_failed_start)${NC}\n" "$display_name" >&2
    printf "${BOLD_RED}$(t container_compose_output)${NC}\n" >&2
    cat "$tmp_log" >&2
    printf "\n${BOLD_RED}$(t container_problematic_services)${NC}\n" >&2
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
    show_info "$(t services_starting_containers)" "$BOLD_GREEN"

    if ! start_container "$REMNAWAVE_DIR" "Remnawave/backend"; then
        show_info "$(t services_installation_stopped)" "$BOLD_RED"
        exit 1
    fi

    if ! start_container "$REMNAWAVE_DIR/subscription-page" "Subscription page"; then
        show_info "$(t services_installation_stopped)" "$BOLD_RED"
        exit 1
    fi
}
