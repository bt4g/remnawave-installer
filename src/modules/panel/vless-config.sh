#!/bin/bash

# ===================================================================================
#                           PANEL-ONLY SHARED FUNCTIONS
# ===================================================================================

# VLESS configuration for panel-only installations
configure_vless_panel_only() {
    local panel_url="127.0.0.1:3000"
    local config_file="$REMNAWAVE_DIR/config.json"

    # Collect node host info
    NODE_HOST=$(simple_read_domain_or_ip "Enter the IP address or domain of the node server (if different from Selfsteal domain)" "$SELF_STEAL_DOMAIN")

    # Generate VLESS keys
    local keys_result=$(generate_vless_keys)
    if [ $? -ne 0 ]; then
        return 1
    fi

    local private_key=$(echo "$keys_result" | cut -d':' -f1)

    # Generate Xray configuration
    generate_xray_config "$config_file" "$SELF_STEAL_DOMAIN" "$CADDY_LOCAL_PORT" "$private_key"

    # Update Xray configuration on panel
    if ! update_xray_config "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$config_file"; then
        return 1
    fi

    # Create node entry in panel
    if ! create_node "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$NODE_HOST" "$NODE_PORT"; then
        return 1
    fi

    # Get inbound UUID
    local inbound_uuid=$(get_inbounds "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN")
    if [ -z "$inbound_uuid" ]; then
        return 1
    fi

    # Create host entry
    if ! create_host "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$inbound_uuid" "$SELF_STEAL_DOMAIN"; then
        return 1
    fi

    # Create default user
    if ! create_user "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "remnawave" "$inbound_uuid"; then
        return 1
    fi

    # Display public key for manual node setup
    local pubkey=$(get_public_key "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN")
    if [ -n "$pubkey" ]; then
        echo
        echo -e "${GREEN}Public key (required for node installation):${NC}"
        echo
        echo -e "SSL_CERT=\"$pubkey\""
        echo
    fi
}
