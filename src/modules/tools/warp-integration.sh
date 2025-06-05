#!/bin/bash

# ===================================================================================
#                              WARP INTEGRATION FUNCTIONS
# ===================================================================================

# Check if panel is installed and running
check_panel_installation() {
    # Check if panel directory exists
    if [ ! -d /opt/remnawave ]; then
        show_error "$(t warp_panel_not_found)"
        echo -e "${YELLOW}$(t update_install_first)${NC}"
        echo
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 1
    fi

    # Check if panel container is running
    if ! docker ps --format '{{.Names}}' | grep -q '^remnawave$'; then
        show_error "$(t warp_panel_not_running)"
        echo -e "${YELLOW}$(t cli_ensure_panel_running)${NC}"
        echo
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 1
    fi

    # Check if credentials file exists
    if [ ! -f /opt/remnawave/credentials.txt ]; then
        show_error "$(t warp_credentials_not_found)"
        echo
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 1
    fi

    return 0
}

# Extract credentials from credentials.txt
extract_panel_credentials() {
    local credentials_file="/opt/remnawave/credentials.txt"
    
    # Extract admin username and password
    PANEL_USERNAME=$(grep "REMNAWAVE ADMIN USERNAME:" "$credentials_file" | cut -d':' -f2 | xargs)
    PANEL_PASSWORD=$(grep "REMNAWAVE ADMIN PASSWORD:" "$credentials_file" | cut -d':' -f2 | xargs)
    PANEL_DOMAIN=$(grep "PANEL URL:" "$credentials_file" | cut -d'/' -f3 | cut -d'?' -f1)
    
    # Fallback to SUPERADMIN if REMNAWAVE ADMIN not found (old installs)
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

# Authenticate with panel and get token
authenticate_panel() {
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

# Show WARP terms and get user agreement
show_warp_terms() {
    clear
    echo -e "${BOLD_GREEN}$(t warp_terms_title)${NC}"
    echo
    echo -e "${YELLOW}$(t warp_terms_text)${NC}"
    echo -e "${BLUE}$(t warp_terms_url)${NC}"
    echo
    
    if ! prompt_yes_no "$(t warp_terms_confirm)" "$YELLOW"; then
        show_info "$(t warp_terms_declined)"
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 1
    fi
    
    return 0
}

# Download and install wgcf
install_wgcf() {
    local wgcf_version="2.2.26"
    local wgcf_arch="linux_amd64"
    local wgcf_url="https://github.com/ViRb3/wgcf/releases/download/v${wgcf_version}/wgcf_${wgcf_version}_${wgcf_arch}"
    local temp_file=$(mktemp)
    
    # Download wgcf
    (wget -q "$wgcf_url" -O "$temp_file") &
    spinner $! "$(t warp_downloading_wgcf)"
    
    if [ $? -ne 0 ] || [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        show_error "$(t warp_failed_download)"
        return 1
    fi
    
    # Install wgcf
    (sudo mv "$temp_file" /usr/bin/wgcf && sudo chmod +x /usr/bin/wgcf) &
    spinner $! "$(t warp_installing_wgcf)"
    
    if [ $? -ne 0 ]; then
        show_error "$(t warp_failed_install)"
        return 1
    fi
    
    return 0
}

# Register WARP account and generate config
generate_warp_config() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Register WARP account
    (echo "Yes" | wgcf register) &
    spinner $! "$(t warp_registering_account)"
    
    if [ $? -ne 0 ] || [ ! -f "wgcf-account.toml" ]; then
        cd - >/dev/null
        rm -rf "$temp_dir"
        show_error "$(t warp_failed_register)"
        return 1
    fi
    
    # Generate WireGuard config
    (wgcf generate) &
    spinner $! "$(t warp_generating_config)"
    
    if [ $? -ne 0 ] || [ ! -f "wgcf-profile.conf" ]; then
        cd - >/dev/null
        rm -rf "$temp_dir"
        show_error "$(t warp_failed_generate)"
        return 1
    fi
    
    # Extract keys from config
    WARP_PRIVATE_KEY=$(grep "PrivateKey" wgcf-profile.conf | cut -d'=' -f2 | xargs)
    WARP_PUBLIC_KEY=$(grep "PublicKey" wgcf-profile.conf | cut -d'=' -f2 | xargs)
    
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    if [ -z "$WARP_PRIVATE_KEY" ] || [ -z "$WARP_PUBLIC_KEY" ]; then
        show_error "$(t warp_failed_generate)"
        return 1
    fi
    
    return 0
}

# Get current XRAY configuration from panel
get_current_xray_config() {
    local panel_url="127.0.0.1:3000"
    local temp_file=$(mktemp)
    
    make_api_request "GET" "http://$panel_url/api/xray" "$PANEL_TOKEN" "$PANEL_DOMAIN" "" >"$temp_file" 2>&1 &
    spinner $! "$(t warp_getting_current_config)"
    local response=$(cat "$temp_file")
    rm -f "$temp_file"
    
    if [ -z "$response" ]; then
        show_error "$(t warp_failed_get_config)"
        return 1
    fi
    
    # Extract config from response
    CURRENT_CONFIG=$(echo "$response" | jq -r '.response.config')
    if [ -z "$CURRENT_CONFIG" ] || [ "$CURRENT_CONFIG" = "null" ]; then
        show_error "$(t warp_failed_get_config)"
        return 1
    fi
    
    return 0
}

# Check if WARP is already configured
check_warp_already_configured() {
    if echo "$CURRENT_CONFIG" | jq -e '.outbounds[] | select(.tag == "warp")' >/dev/null 2>&1; then
        show_warning "$(t warp_already_configured)"
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 1
    fi
    return 0
}

# Add WARP outbound to XRAY configuration
add_warp_outbound() {
    local warp_outbound=$(cat <<EOF
{
  "tag": "warp",
  "protocol": "wireguard",
  "settings": {
    "secretKey": "$WARP_PRIVATE_KEY",
    "DNS": "1.1.1.1",
    "kernelMode": false,
    "address": ["172.16.0.2/32"],
    "peers": [
      {
        "publicKey": "$WARP_PUBLIC_KEY",
        "endpoint": "engage.cloudflareclient.com:2408"
      }
    ]
  }
}
EOF
)

    # Add WARP outbound to existing outbounds
    UPDATED_CONFIG=$(echo "$CURRENT_CONFIG" | jq --argjson warp_outbound "$warp_outbound" '.outbounds += [$warp_outbound]')

    if [ $? -ne 0 ]; then
        show_error "$(t warp_failed_update_config)"
        return 1
    fi

    return 0
}

# Add WARP routing rules
add_warp_routing() {
    local warp_routing_rule=$(cat <<EOF
{
  "outboundTag": "warp",
  "domain": [
    "geosite:google-gemini",
    "openai.com",
    "ipinfo.io",
    "spotify.com",
    "canva.com"
  ],
  "type": "field"
}
EOF
)

    # Add WARP routing rule to existing rules
    UPDATED_CONFIG=$(echo "$UPDATED_CONFIG" | jq --argjson warp_rule "$warp_routing_rule" '.routing.rules += [$warp_rule]')

    if [ $? -ne 0 ]; then
        show_error "$(t warp_failed_update_config)"
        return 1
    fi

    return 0
}

# Update XRAY configuration with WARP
update_xray_with_warp() {
    local panel_url="127.0.0.1:3000"
    local config_file=$(mktemp)

    # Save updated config to temporary file
    echo "$UPDATED_CONFIG" > "$config_file"

    # Update XRAY configuration
    if ! update_xray_config "$panel_url" "$PANEL_TOKEN" "$PANEL_DOMAIN" "$config_file"; then
        rm -f "$config_file"
        show_error "$(t warp_failed_update_config)"
        return 1
    fi

    # Clean up temporary file
    rm -f "$config_file"
    return 0
}

# Main WARP integration function
add_warp_integration() {
    clear
    echo -e "${BOLD_GREEN}$(t warp_title)${NC}"
    echo

    # Check panel installation
    show_info "$(t warp_checking_installation)" "$ORANGE"
    if ! check_panel_installation; then
        return 0
    fi

    # Show terms and get agreement
    if ! show_warp_terms; then
        return 0
    fi

    # Extract credentials
    if ! extract_panel_credentials; then
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Authenticate with panel
    if ! authenticate_panel; then
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Get current XRAY configuration
    if ! get_current_xray_config; then
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Check if WARP is already configured
    if ! check_warp_already_configured; then
        return 0
    fi

    # Install wgcf if not present
    if ! command -v wgcf &> /dev/null; then
        if ! install_wgcf; then
            echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
            read -r
            return 0
        fi
    fi

    # Generate WARP configuration
    if ! generate_warp_config; then
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Add WARP outbound
    if ! add_warp_outbound; then
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Add WARP routing rules
    if ! add_warp_routing; then
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Update XRAY configuration
    show_info "$(t warp_updating_config)" "$ORANGE"
    if ! update_xray_with_warp; then
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Show success message
    echo
    show_success "$(t warp_success)"
    echo
    echo -e "${GREEN}$(t warp_success_details)${NC}"
    echo
    echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
    read -r
}
