#!/bin/bash

# ===================================================================================
#                          WARP DOCKER INTEGRATION FUNCTIONS
# ===================================================================================

check_installation_type() {
    if [ -d /opt/remnawave ] && docker ps --format '{{.Names}}' | grep -q '^remnawave$'; then
        if [ -d /opt/remnawave/node ] && docker ps --format '{{.Names}}' | grep -q '^remnanode$'; then
            echo "all-in-one"
        else
            echo "panel-only"
        fi
    elif [ -d /opt/remnanode ] && docker ps --format '{{.Names}}' | grep -q '^remnanode$'; then
        echo "node-only"
    else
        echo "none"
    fi
}

check_panel_installation_docker() {
    if [ ! -d /opt/remnawave ]; then
        show_error "$(t warp_panel_not_found)"
        echo -e "${YELLOW}$(t update_install_first)${NC}"
        echo
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 1
    fi

    if ! docker ps --format '{{.Names}}' | grep -q '^remnawave$'; then
        show_error "$(t warp_panel_not_running)"
        echo -e "${YELLOW}$(t cli_ensure_panel_running)${NC}"
        echo
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 1
    fi

    if [ ! -f /opt/remnawave/credentials.txt ]; then
        show_error "$(t warp_credentials_not_found)"
        echo
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 1
    fi

    return 0
}

extract_panel_credentials_docker() {
    local credentials_file="/opt/remnawave/credentials.txt"
    
    PANEL_USERNAME=$(grep "REMNAWAVE ADMIN USERNAME:" "$credentials_file" | cut -d':' -f2 | xargs)
    PANEL_PASSWORD=$(grep "REMNAWAVE ADMIN PASSWORD:" "$credentials_file" | cut -d':' -f2 | xargs)
    PANEL_DOMAIN=$(grep "PANEL URL:" "$credentials_file" | cut -d'/' -f3 | cut -d'?' -f1)
    
    if [ -z "$PANEL_USERNAME" ]; then
        PANEL_USERNAME=$(grep "SUPERADMIN USERNAME:" "$credentials_file" | cut -d':' -f2 | xargs)
        PANEL_PASSWORD=$(grep "SUPERADMIN PASSWORD:" "$credentials_file" | cut -d':' -f2 | xargs)
    fi
    
    if [ -z "$PANEL_USERNAME" ] || [ -z "$PANEL_PASSWORD" ] || [ -z "$PANEL_DOMAIN" ]; then
        show_error "$(t warp_failed_auth)"
        return 1
    fi
    
    return 0
}

authenticate_panel_docker() {
    local panel_url="127.0.0.1:3000"
    local api_url="http://${panel_url}/api/auth/login"
    
    local temp_file=$(mktemp)
    local login_data="{\"username\":\"$PANEL_USERNAME\",\"password\":\"$PANEL_PASSWORD\"}"
    
    make_api_request "POST" "$api_url" "" "$PANEL_DOMAIN" "$login_data" >"$temp_file" 2>&1 &
    spinner $! "$(t warp_authenticating_panel)"
    local response=$(cat "$temp_file")
    rm -f "$temp_file"
    
    if [ -z "$response" ]; then
        show_error "$(t warp_failed_auth)"
        return 1
    fi
    
    if [[ "$response" == *"accessToken"* ]]; then
        PANEL_TOKEN=$(echo "$response" | jq -r '.response.accessToken')
        if [ -z "$PANEL_TOKEN" ] || [ "$PANEL_TOKEN" = "null" ]; then
            show_error "$(t warp_failed_auth)"
            return 1
        fi
        return 0
    else
        show_error "$(t warp_failed_auth)"
        return 1
    fi
}

get_nodes_list() {
    local panel_url="127.0.0.1:3000"
    local nodes_response=$(get_nodes "$panel_url" "$PANEL_TOKEN" "$PANEL_DOMAIN")
    
    if [ $? -ne 0 ] || [ -z "$nodes_response" ]; then
        show_error "$(t warp_no_nodes_found)"
        return 1
    fi
    
    NODES_JSON=$(echo "$nodes_response" | jq -r '.response // empty')
    if [ -z "$NODES_JSON" ] || [ "$NODES_JSON" = "null" ] || [ "$NODES_JSON" = "[]" ]; then
        show_error "$(t warp_no_nodes_found)"
        return 1
    fi
    
    return 0
}

select_nodes_for_warp() {
    local installation_type="$1"
    local nodes_count=$(echo "$NODES_JSON" | jq '. | length')
    
    if [ "$nodes_count" -eq 0 ]; then
        show_error "$(t warp_no_nodes_found)"
        return 1
    fi
    
    SELECTED_NODES=()
    SELECTED_NODE_ADDRESSES=()
    HAS_LOCAL_NODE=false
    
    if [ "$nodes_count" -eq 1 ]; then
        local node_uuid=$(echo "$NODES_JSON" | jq -r ".[0].uuid")
        local node_address=$(echo "$NODES_JSON" | jq -r ".[0].address")
        local node_name=$(echo "$NODES_JSON" | jq -r ".[0].name")
        
        SELECTED_NODES+=("$node_uuid|$node_name")
        SELECTED_NODE_ADDRESSES+=("$node_address")
        
        if [[ "$node_address" == "172.17.0.1" ]] || [[ "$node_address" == "127.0.0.1" ]] || [[ "$node_address" == "localhost" ]]; then
            HAS_LOCAL_NODE=true
            show_info "$(t warp_single_local_node_detected): $node_name - $node_address"
        else
            show_info "$(t warp_single_remote_node_detected): $node_name - $node_address"
        fi
        
        return 0
    fi
    
    local nodes_array=()
    local i=0
    while [ $i -lt "$nodes_count" ]; do
        local node_name=$(echo "$NODES_JSON" | jq -r ".[$i].name")
        local node_address=$(echo "$NODES_JSON" | jq -r ".[$i].address")
        local node_uuid=$(echo "$NODES_JSON" | jq -r ".[$i].uuid")
        local is_local=""
        
        if [[ "$node_address" == "172.17.0.1" ]] || [[ "$node_address" == "127.0.0.1" ]] || [[ "$node_address" == "localhost" ]]; then
            is_local=" $(t warp_node_local)"
        fi
        
        nodes_array+=("$node_uuid|$node_name - $node_address$is_local")
        ((i++))
    done
    
    echo
    echo -e "${BOLD_BLUE}$(t warp_select_nodes_title)${NC}"
    echo
    echo -e "${BOLD_GREEN}0)${NC} $(t warp_all_nodes)"
    
    i=0
    while [ $i -lt "$nodes_count" ]; do
        local node_info="${nodes_array[$i]}"
        local display_info="${node_info#*|}"
        echo -e "${BOLD_GREEN}$((i+1)))${NC} $display_info"
        ((i++))
    done
    
    echo
    read -p "$(t warp_select_node_prompt)" selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 0 ] || [ "$selection" -gt "$nodes_count" ]; then
        show_error "$(t warp_invalid_selection)"
        return 1
    fi
    
    if [ "$selection" -eq 0 ]; then
        i=0
        while [ $i -lt "$nodes_count" ]; do
            local node_uuid=$(echo "$NODES_JSON" | jq -r ".[$i].uuid")
            local node_address=$(echo "$NODES_JSON" | jq -r ".[$i].address")
            local node_name=$(echo "$NODES_JSON" | jq -r ".[$i].name")
            
            SELECTED_NODES+=("$node_uuid|$node_name")
            SELECTED_NODE_ADDRESSES+=("$node_address")
            
            if [[ "$node_address" == "172.17.0.1" ]] || [[ "$node_address" == "127.0.0.1" ]] || [[ "$node_address" == "localhost" ]]; then
                HAS_LOCAL_NODE=true
            fi
            ((i++))
        done
    else
        local node_index=$((selection-1))
        local node_uuid=$(echo "$NODES_JSON" | jq -r ".[$node_index].uuid")
        local node_address=$(echo "$NODES_JSON" | jq -r ".[$node_index].address")
        local node_name=$(echo "$NODES_JSON" | jq -r ".[$node_index].name")
        
        SELECTED_NODES+=("$node_uuid|$node_name")
        SELECTED_NODE_ADDRESSES+=("$node_address")
        
        if [[ "$node_address" == "172.17.0.1" ]] || [[ "$node_address" == "127.0.0.1" ]] || [[ "$node_address" == "localhost" ]]; then
            HAS_LOCAL_NODE=true
        fi
    fi
    
    return 0
}

update_profiles_for_selected_nodes() {
    local panel_url="127.0.0.1:3000"
    local temp_file=$(mktemp)
    
    make_api_request "GET" "http://$panel_url/api/config-profiles" "$PANEL_TOKEN" "$PANEL_DOMAIN" "" >"$temp_file" 2>&1 &
    spinner $! "$(t warp_getting_current_config)"
    local profiles_response=$(cat "$temp_file")
    rm -f "$temp_file"
    
    if [ -z "$profiles_response" ]; then
        show_error "$(t warp_failed_get_config)"
        return 1
    fi
    
    # Group selected nodes by their profile UUID
    local profile_groups=$(
        for node_info in "${SELECTED_NODES[@]}"; do
            local node_uuid="${node_info%%|*}"
            local node_name="${node_info#*|}"
            local node_data=$(echo "$NODES_JSON" | jq -r ".[] | select(.uuid == \"$node_uuid\")")
            local profile_uuid=$(echo "$node_data" | jq -r '.configProfile.activeConfigProfileUuid // empty')
            
            if [ -n "$profile_uuid" ] && [ "$profile_uuid" != "null" ]; then
                echo "$profile_uuid|$node_name"
            fi
        done | sort | jq -R -s -c 'split("\n") | map(select(length > 0) | split("|") | {profile: .[0], node: .[1]}) | group_by(.profile) | map({profile: .[0].profile, nodes: map(.node)})'
    )
    
    local total_profiles=$(echo "$profile_groups" | jq '. | length')
    if [ "$total_profiles" -eq 0 ]; then
        show_error "$(t warp_failed_get_config)"
        return 1
    fi
    
    show_info "$(t warp_found_profiles): $total_profiles"
    
    local profiles_updated=0
    UPDATED_PROFILES_INFO=()
    
    echo "$profile_groups" | jq -c '.[]' | while read -r group; do
        local profile_uuid=$(echo "$group" | jq -r '.profile')
        local node_names=$(echo "$group" | jq -r '.nodes | join(", ")')
        
        # Get profile configuration
        local current_config=$(echo "$profiles_response" | jq -r ".response.configProfiles[] | select(.uuid == \"$profile_uuid\") | .config" 2>/dev/null)
        
        if [ -z "$current_config" ] || [ "$current_config" = "null" ]; then
            show_error "$(t warp_failed_get_config) for profile $profile_uuid"
            continue
        fi
        
        # Get profile name
        local profile_name=$(echo "$profiles_response" | jq -r ".response.configProfiles[] | select(.uuid == \"$profile_uuid\") | .name // \"$profile_uuid\"" 2>/dev/null)
        
        # Check if WARP already configured in this profile
        if echo "$current_config" | jq -e '.outbounds[] | select(.tag == "warp-out")' >/dev/null 2>&1; then
            show_warning "$(t warp_already_configured) ($(t warp_profile): $profile_name, $(t warp_nodes_lowercase): $node_names)"
            continue
        fi
        
        # Add WARP outbound
        local warp_outbound=$(cat <<'EOF'
{
  "tag": "warp-out",
  "protocol": "freedom",
  "settings": {},
  "streamSettings": {
    "sockopt": {
      "interface": "warp",
      "tcpFastOpen": true
    }
  }
}
EOF
        )
        
        local updated_config=$(echo "$current_config" | jq --argjson warp_outbound "$warp_outbound" '.outbounds += [$warp_outbound]')
        
        if [ $? -ne 0 ]; then
            show_error "$(t warp_failed_update_config) for profile $profile_uuid"
            continue
        fi
        
        # Add WARP routing rules
        local warp_routing_rule=$(cat <<'EOF'
{
  "type": "field",
  "domain": [
    "ipinfo.io"
  ],
  "inboundTag": [
    "VLESS"
  ],
  "outboundTag": "warp-out"
}
EOF
        )
        
        # Ensure routing and rules exist before adding
        updated_config=$(echo "$updated_config" | jq 'if .routing == null then .routing = {} else . end')
        updated_config=$(echo "$updated_config" | jq 'if .routing.rules == null then .routing.rules = [] else . end')
        updated_config=$(echo "$updated_config" | jq --argjson warp_rule "$warp_routing_rule" '.routing.rules += [$warp_rule]')
        
        if [ $? -ne 0 ]; then
            show_error "$(t warp_failed_update_config) for profile $profile_uuid"
            continue
        fi
        
        # Update profile
        local update_data=$(jq -n --arg uuid "$profile_uuid" --argjson config "$updated_config" '{
            uuid: $uuid,
            config: $config
        }')
        
        local update_temp=$(mktemp)
        make_api_request "PATCH" "http://$panel_url/api/config-profiles" "$PANEL_TOKEN" "$PANEL_DOMAIN" "$update_data" >"$update_temp" 2>&1 &
        spinner $! "$(t warp_updating_config) ($node_names)"
        local update_response=$(cat "$update_temp")
        rm -f "$update_temp"
        
        if [ -z "$update_response" ]; then
            show_error "$(t warp_failed_update_config) for profile $profile_uuid"
            continue
        fi
        
        if echo "$update_response" | jq -e '.response.uuid' >/dev/null 2>&1; then
            ((profiles_updated++))
            # Store updated info in temp file to pass to parent shell
            echo "$node_names|$profile_name" >> /tmp/warp_updated_profiles.tmp
            show_success "$(t warp_profile_updated): $node_names"
        else
            show_error "$(t warp_failed_update_config) for profile $profile_uuid"
            echo "$(t api_response):"
            echo "$update_response"
        fi
    done
    
    # Read updated profiles info from temp file
    if [ -f /tmp/warp_updated_profiles.tmp ]; then
        while IFS='|' read -r nodes profile; do
            UPDATED_PROFILES_INFO+=("$nodes ($(t warp_profile): $profile)")
        done < /tmp/warp_updated_profiles.tmp
        rm -f /tmp/warp_updated_profiles.tmp
        
        if [ ${#UPDATED_PROFILES_INFO[@]} -gt 0 ]; then
            return 0
        fi
    fi
    
    return 1
}

install_docker_warp_native() {
    local warp_dir="/opt/docker-warp-native"
    
    mkdir -p "$warp_dir"
    
    show_info "$(t warp_docker_downloading)"
    if ! wget -q "https://raw.githubusercontent.com/xxphantom/docker-warp-native/refs/heads/main/docker-compose.yml" -O "$warp_dir/docker-compose.yml"; then
        show_error "$(t warp_docker_download_failed)"
        return 1
    fi
    
    cd "$warp_dir"
    show_info "$(t warp_docker_starting)"
    
    if ! docker compose up -d; then
        show_error "$(t warp_docker_start_failed)"
        return 1
    fi
    
    echo
    show_info "$(t warp_docker_logs)"
    docker compose logs -f -t --tail=20 &
    local log_pid=$!
    
    sleep 10
    kill $log_pid 2>/dev/null
    
    cd - >/dev/null
    return 0
}

show_warp_config_changes() {
    # Take updated profiles info as parameters
    local updated_profiles=("$@")
    
    clear
    echo -e "${BOLD_GREEN}$(t warp_docker_config_added)${NC}"
    echo
    
    # Show affected nodes and profiles
    if [ ${#updated_profiles[@]} -gt 0 ]; then
        echo -e "${BOLD_BLUE}$(t warp_affected_nodes_profiles):${NC}"
        echo
        for profile_info in "${updated_profiles[@]}"; do
            echo "  • $profile_info"
        done
        echo
    fi
    
    echo -e "${BOLD_BLUE}$(t warp_docker_outbound_added):${NC}"
    echo
    cat <<'EOF'
{
  "tag": "warp-out",
  "protocol": "freedom",
  "settings": {},
  "streamSettings": {
    "sockopt": {
      "interface": "warp",
      "tcpFastOpen": true
    }
  }
}
EOF
    echo
    echo -e "${BOLD_BLUE}$(t warp_docker_routing_added):${NC}"
    echo
    cat <<'EOF'
{
  "type": "field",
  "domain": [
    "ipinfo.io"
  ],
  "inboundTag": ["VLESS"],
  "outboundTag": "warp-out"
}
EOF
    echo
    echo -e "${YELLOW}$(t warp_docker_edit_domains)${NC}"
}

show_remote_nodes_warning() {
    local has_remote=false
    
    for addr in "${SELECTED_NODE_ADDRESSES[@]}"; do
        if [[ "$addr" != "172.17.0.1" ]] && [[ "$addr" != "127.0.0.1" ]] && [[ "$addr" != "localhost" ]]; then
            has_remote=true
            break
        fi
    done
    
    if [ "$has_remote" = true ]; then
        echo
        echo -e "${BOLD_RED}❗ $(t warp_remote_nodes_warning)${NC}"
        echo
        echo -e "${BLUE}$(t warp_docker_repo_link)${NC}"
        echo
    fi
}

add_warp_docker_integration() {
    clear
    echo -e "${BOLD_GREEN}$(t warp_docker_title)${NC}"
    echo -e "${BLUE}$(t warp_docker_subtitle)${NC}"
    echo
    
    if ! command -v docker &> /dev/null; then
        show_error "$(t warp_docker_no_docker)"
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi
    
    local installation_type=$(check_installation_type)
    
    case "$installation_type" in
        "node-only")
            show_info "$(t warp_node_only_detected)"
            echo
            show_info "$(t warp_installing_container_only)"
            
            if ! install_docker_warp_native; then
                echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
                read -r
                return 0
            fi
            
            show_success "$(t warp_container_installed_node_only)"
            echo
            echo -e "${YELLOW}$(t warp_manual_config_needed)${NC}"
            echo -e "${BLUE}$(t warp_docker_repo_link)${NC}"
            echo
            echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
            read -r
            return 0
            ;;
            
        "panel-only"|"all-in-one")
            show_info "$(t warp_checking_installation)" "$ORANGE"
            if ! check_panel_installation_docker; then
                return 0
            fi
            
            if ! extract_panel_credentials_docker; then
                echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
                read -r
                return 0
            fi
            
            if ! authenticate_panel_docker; then
                echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
                read -r
                return 0
            fi
            
            if ! get_nodes_list; then
                echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
                read -r
                return 0
            fi
            
            if ! select_nodes_for_warp "$installation_type"; then
                echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
                read -r
                return 0
            fi
            
            show_info "$(t warp_config_will_update)"
            
            if [ "$HAS_LOCAL_NODE" = true ] || [ "$installation_type" = "all-in-one" ]; then
                if [ -d "/opt/docker-warp-native" ] && docker ps --format '{{.Names}}' | grep -q "docker-warp-native"; then
                    show_warning "$(t warp_docker_already_installed)"
                    
                    if prompt_yes_no "$(t warp_docker_reinstall)" "$YELLOW"; then
                        cd /opt/docker-warp-native
                        docker compose down
                        cd - >/dev/null
                        rm -rf /opt/docker-warp-native
                    else
                        show_info "$(t warp_docker_updating_config_only)"
                    fi
                fi
                
                if [ ! -d "/opt/docker-warp-native" ] || ! docker ps --format '{{.Names}}' | grep -q "docker-warp-native"; then
                    if ! install_docker_warp_native; then
                        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
                        read -r
                        return 0
                    fi
                fi
            fi
            
            show_info "$(t warp_updating_config)" "$ORANGE"
            if ! update_profiles_for_selected_nodes; then
                echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
                read -r
                return 0
            fi
            
            show_warp_config_changes "${UPDATED_PROFILES_INFO[@]}"
            
            show_remote_nodes_warning
            
            show_success "$(t warp_docker_success)"
            echo -e "${GREEN}$(t warp_docker_success_details)${NC}"
            echo -e "${GREEN}$(t warp_docker_config_updated)${NC}"
            echo
            echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
            read -r
            ;;
            
        *)
            show_error "$(t warp_panel_not_found)"
            echo -e "${YELLOW}$(t update_install_first)${NC}"
            echo
            echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
            read -r
            return 0
            ;;
    esac
}