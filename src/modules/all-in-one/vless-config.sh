#!/bin/bash

# ===================================================================================
#                           ALL-IN-ONE SHARED FUNCTIONS
# ===================================================================================

# VLESS configuration for all-in-one installations
configure_vless_all_in_one() {
    local panel_url="127.0.0.1:3000"
    local config_file="$REMNAWAVE_DIR/config.json"
    local node_host="172.17.0.1"  # Docker bridge IP
    
    # Generate VLESS keys
    local keys_result=$(generate_vless_keys)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local private_key=$(echo "$keys_result" | cut -d':' -f1)
    
    # Generate Xray configuration
    generate_xray_config "$config_file" "$PANEL_DOMAIN" "$CADDY_LOCAL_PORT" "$private_key"
    
    # Update Xray configuration on panel
    if ! update_xray_config "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$config_file"; then
        return 1
    fi
    
    # Create node entry in panel
    if ! create_node "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$node_host" "$NODE_PORT"; then
        return 1
    fi
    
    # Get inbound UUID
    local inbound_uuid=$(get_inbounds "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN")
    if [ -z "$inbound_uuid" ]; then
        return 1
    fi
    
    # Create host entry
    if ! create_host "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$inbound_uuid" "$PANEL_DOMAIN"; then
        return 1
    fi

    # Create default user
    if ! create_user "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "remnawave" "$inbound_uuid"; then
        return 1
    fi
}


