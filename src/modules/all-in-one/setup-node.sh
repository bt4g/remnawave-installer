#!/bin/bash

# ===================================================================================
#                              REMNAWAVE NODE INSTALLATION
# ===================================================================================

setup_node_all_in_one() {
    local SCRIPT_SUB_DOMAIN=$1
    local SELF_STEAL_PORT=$2
    local panel_url=$3
    local token=$4
    local NODE_PORT=$5

    mkdir -p "$LOCAL_REMNANODE_DIR" && cd "$LOCAL_REMNANODE_DIR"
    
    # Create docker-compose.yml
    cat > docker-compose.yml << EOL
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
    create_makefile "$LOCAL_REMNANODE_DIR"

    # Get public key
    local temp_file=$(mktemp)
    make_api_request "GET" "http://$panel_url/api/keygen" "$token" "$SCRIPT_SUB_DOMAIN" > "$temp_file" 2>&1 &
    spinner $! "Getting public key..."
    api_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$api_response" ]; then
        echo -e "${BOLD_RED}Error: Failed to get public key.${NC}"
        return 1
    fi

    pubkey=$(echo "$api_response" | jq -r '.response.pubKey')
    if [ -z "$pubkey" ]; then
        echo -e "${BOLD_RED}Error: Failed to extract public key from response.${NC}"
        return 1
    fi

    local CERTIFICATE="SSL_CERT=\"$pubkey\""

    echo -e "### APP ###\nAPP_PORT=$NODE_PORT\n$CERTIFICATE" >.env
}
