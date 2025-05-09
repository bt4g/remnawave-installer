#!/bin/bash

# ===================================================================================
#                                API REQUEST FUNCTIONS
# ===================================================================================

# Function to perform API request with Bearer token
# Parameters:
#   $1 - method (GET, POST, PUT, DELETE)
#   $2 - full URL
#   $3 - Bearer token for authorization
#   $4 - host domain (for Host header)
#   $5 - request data in JSON format (optional, only for POST/PUT)
make_api_request() {
    local method=$1
    local url=$2
    local token=$3
    local panel_domain=$4
    local data=$5

    local headers=(
        -H "Content-Type: application/json"
        -H "Host: $panel_domain"
        -H "X-Forwarded-For: ${url#http://}"
        -H "X-Forwarded-Proto: https"
    )
    if [ -n "$token" ]; then
        headers+=(-H "Authorization: Bearer $token")
    fi

    if [ -n "$data" ]; then
        curl -s -X "$method" "$url" "${headers[@]}" -d "$data"
    else
        curl -s -X "$method" "$url" "${headers[@]}"
    fi
}

# Function to register a user via API
register_user() {
    local panel_url="$1"
    local panel_domain="$2"
    local username="$3"
    local password="$4"
    local api_url="http://${panel_url}/api/auth/register"

    local reg_token=""
    local reg_error=""
    local response=""
    local max_wait=180
    local start_time=$(date +%s)
    local end_time=$((start_time + max_wait))

    while [ $(date +%s) -lt $end_time ]; do
        response=$(make_api_request "POST" "$api_url" "" "$panel_domain" "{\"username\":\"$username\",\"password\":\"$password\"}")
        if [ -z "$response" ]; then
            reg_error="Empty server response"
        elif [[ "$response" == *"accessToken"* ]]; then
            reg_token=$(echo "$response" | jq -r '.response.accessToken')
            echo "$reg_token"
            return 0
        else
            reg_error="$response"
        fi
        sleep 1
    done
    # Если не удалось зарегистрироваться за 180 секунд, вывести последнюю ошибку или ответ
    echo "${reg_error:-Registration failed: unknown error}"
    return 1
}

# Get public API key
get_public_key() {
    local panel_url="$1"
    local token="$2"
    local panel_domain="$3"

    local temp_file=$(mktemp)

    make_api_request "GET" "http://$panel_url/api/keygen" "$token" "$panel_domain" >"$temp_file" 2>&1 &
    spinner $! "Getting public key..."
    api_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$api_response" ]; then
        echo -e "${BOLD_RED}Error: Failed to get public key.${NC}"
        return 1
    fi

    local pubkey=$(echo "$api_response" | jq -r '.response.pubKey')
    if [ -z "$pubkey" ]; then
        echo -e "${BOLD_RED}Error: Failed to extract public key from response.${NC}"
        return 1
    fi

    # Return public key
    echo "$pubkey"
}

# Create node
create_vless_node() {
    local panel_url="$1"
    local token="$2"
    local panel_domain="$3"
    local node_host="$4"
    local node_port="$5"

    local node_name="VLESS-NODE"
    local temp_file=$(mktemp)

    local new_node_data=$(
        cat <<EOF
{
    "name": "$node_name",
    "address": "$node_host",
    "port": $node_port,
    "isTrafficTrackingActive": false,
    "trafficLimitBytes": 0,
    "notifyPercent": 0,
    "trafficResetDay": 31,
    "excludedInbounds": [],
    "countryCode": "XX",
    "consumptionMultiplier": 1.0
}
EOF
    )

    make_api_request "POST" "http://$panel_url/api/nodes" "$token" "$panel_domain" "$new_node_data" >"$temp_file" 2>&1 &
    spinner $! "Creating node..."
    node_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$node_response" ]; then
        echo -e "${BOLD_RED}Error: Empty response from server when creating node.${NC}"
        return 1
    fi

    if echo "$node_response" | jq -e '.response.uuid' >/dev/null; then
        return 0
    else
        echo -e "${BOLD_RED}Error: Failed to create node, response:${NC}"
        echo
        echo "Request body was:"
        echo "$new_node_data"
        echo
        echo "Response:"
        echo
        echo "$node_response"
        return 1
    fi
}

# Get list of inbounds
get_inbounds() {
    local panel_url="$1"
    local token="$2"
    local panel_domain="$3"

    local temp_file=$(mktemp)

    make_api_request "GET" "http://$panel_url/api/inbounds" "$token" "$panel_domain" >"$temp_file" 2>&1 &
    spinner $! "Getting list of inbounds..."
    inbounds_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$inbounds_response" ]; then
        echo -e "${BOLD_RED}Error: Empty response from server when getting inbounds.${NC}"
        return 1
    fi

    local inbound_uuid=$(echo "$inbounds_response" | jq -r '.response[0].uuid')
    if [ -z "$inbound_uuid" ]; then
        echo -e "${BOLD_RED}Error: Failed to extract UUID from response.${NC}"
        return 1
    fi

    # Return UUID
    echo "$inbound_uuid"
}

# Create host
create_vless_host() {
    local panel_url="$1"
    local token="$2"
    local panel_domain="$3"
    local inbound_uuid="$4"
    local self_steal_domain="$5"

    local temp_file=$(mktemp)

    local host_data=$(
        cat <<EOF
{
    "inboundUuid": "$inbound_uuid",
    "remark": "VLESS TCP REALITY",
    "address": "$self_steal_domain",
    "port": 443,
    "path": "",
    "sni": "$self_steal_domain",
    "host": "$self_steal_domain",
    "alpn": "h2",
    "fingerprint": "chrome",
    "allowInsecure": false,
    "isDisabled": false
}
EOF
    )

    make_api_request "POST" "http://$panel_url/api/hosts" "$token" "$panel_domain" "$host_data" >"$temp_file" 2>&1 &
    spinner $! "Creating host for UUID: $inbound_uuid..."
    host_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$host_response" ]; then
        echo -e "${BOLD_RED}Error: Empty response from server when creating host.${NC}"
        return 1
    fi

    if echo "$host_response" | jq -e '.response.uuid' >/dev/null; then
        return 0
    else
        echo -e "${BOLD_RED}Error: Failed to create host.${NC}"
        return 1
    fi
}
