#!/bin/bash

# ===================================================================================
#                                REMNAWAVE API FUNCTIONS
# ===================================================================================

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

    local temp_result=$(mktemp)

    {
        local start_time=$(date +%s)
        local end_time=$((start_time + max_wait))

        while [ $(date +%s) -lt $end_time ]; do
            response=$(make_api_request "POST" "$api_url" "" "$panel_domain" "{\"username\":\"$username\",\"password\":\"$password\"}")
            if [ -z "$response" ]; then
                reg_error="$(t api_empty_server_response)"
            elif [[ "$response" == *"accessToken"* ]]; then
                reg_token=$(echo "$response" | jq -r '.response.accessToken')
                echo "$reg_token" >"$temp_result"
                exit 0
            else
                reg_error="$response"
            fi
            sleep 1
        done
        echo "${reg_error:-$(t api_registration_failed)}" >"$temp_result"
        exit 1
    } &

    local pid=$!

    spinner "$pid" "$(t spinner_registering_user) $username..."

    wait $pid
    local status=$?

    local result=$(cat "$temp_result")
    rm -f "$temp_result"

    echo "$result"
    return $status
}

get_public_key() {
    local panel_url="$1"
    local token="$2"
    local panel_domain="$3"

    local temp_file=$(mktemp)

    make_api_request "GET" "http://$panel_url/api/keygen" "$token" "$panel_domain" "" >"$temp_file" 2>&1 &
    spinner $! "$(t spinner_getting_public_key)"
    api_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$api_response" ]; then
        echo -e "${BOLD_RED}$(t api_failed_get_public_key)${NC}"
        return 1
    fi

    local pubkey=$(echo "$api_response" | jq -r '.response.pubKey')
    if [ -z "$pubkey" ]; then
        echo -e "${BOLD_RED}$(t api_failed_extract_public_key)${NC}"
        return 1
    fi

    # Return public key
    echo "$pubkey"
}

# Create node
create_node() {
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
    spinner $! "$(t spinner_creating_node)"
    node_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$node_response" ]; then
        echo -e "${BOLD_RED}$(t api_empty_response_creating_node)${NC}"
        return 1
    fi

    if echo "$node_response" | jq -e '.response.uuid' >/dev/null; then
        return 0
    else
        echo -e "${BOLD_RED}$(t api_failed_create_node)${NC}"
        echo
        echo "$(t api_request_body_was)"
        echo "$new_node_data"
        echo
        echo "$(t api_response):"
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

    make_api_request "GET" "http://$panel_url/api/inbounds" "$token" "$panel_domain" "" >"$temp_file" 2>&1 &
    spinner $! "$(t spinner_getting_inbounds)"
    inbounds_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$inbounds_response" ]; then
        echo -e "${BOLD_RED}$(t api_empty_response_getting_inbounds)${NC}"
        return 1
    fi

    local inbound_uuid=$(echo "$inbounds_response" | jq -r '.response[0].uuid')
    if [ -z "$inbound_uuid" ]; then
        echo -e "${BOLD_RED}$(t api_failed_extract_uuid)${NC}"
        return 1
    fi

    # Return UUID
    echo "$inbound_uuid"
}

# Create host
create_host() {
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
    "alpn": "h2,http/1.1",
    "fingerprint": "chrome",
    "allowInsecure": false,
    "isDisabled": false
}
EOF
    )

    make_api_request "POST" "http://$panel_url/api/hosts" "$token" "$panel_domain" "$host_data" >"$temp_file" 2>&1 &
    spinner $! "$(t spinner_creating_host) UUID: $inbound_uuid..."
    host_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$host_response" ]; then
        echo -e "${BOLD_RED}$(t api_empty_response_creating_host)${NC}"
        return 1
    fi

    if echo "$host_response" | jq -e '.response.uuid' >/dev/null; then
        return 0
    else
        echo -e "${BOLD_RED}$(t api_failed_create_host)${NC}"
        return 1
    fi
}

# Create user
create_user() {
    local panel_url="$1"
    local token="$2"
    local panel_domain="$3"
    local username="$4"
    local inbound_uuid="$5"

    local temp_file=$(mktemp)
    local temp_headers=$(mktemp)

    local user_data=$(
        cat <<EOF
{
    "username": "$username",
    "status": "ACTIVE",
    "trafficLimitBytes": 0,
    "trafficLimitStrategy": "NO_RESET",
    "activeUserInbounds": [
        "$inbound_uuid"
    ],
    "expireAt": "2099-12-31T23:59:59.000Z",
    "description": "Default user created during installation",
    "hwidDeviceLimit": 0
}
EOF
    )

    # Make request with status code check
    {
        local host_only=$(echo "http://$panel_url/api/users" | sed 's|http://||' | cut -d'/' -f1)

        local headers=(
            -H "Content-Type: application/json"
            -H "Host: $panel_domain"
            -H "X-Forwarded-For: $host_only"
            -H "X-Forwarded-Proto: https"
            -H "Authorization: Bearer $token"
        )

        curl -s -w "%{http_code}" -X "POST" "http://$panel_url/api/users" "${headers[@]}" -d "$user_data" -D "$temp_headers" >"$temp_file"
    } &

    spinner $! "$(t creating_user) $username..."

    # Read response and status code
    local full_response=$(cat "$temp_file")
    local status_code="${full_response: -3}"   # Last 3 characters
    local user_response="${full_response%???}" # Everything except last 3 characters

    rm -f "$temp_file" "$temp_headers"

    if [ -z "$user_response" ]; then
        echo -e "${BOLD_RED}$(t api_empty_response_creating_user)${NC}"
        return 1
    fi

    # Check for 201 status code
    if [ "$status_code" != "201" ]; then
        echo -e "${BOLD_RED}$(t api_failed_create_user_status) $status_code${NC}"
        echo
        echo "$(t api_request_body_was)"
        echo "$user_data"
        echo
        echo "$(t api_response):"
        echo "$user_response"
        return 1
    fi

    if echo "$user_response" | jq -e '.response.uuid' >/dev/null; then
        # Extract user data and save to global variables
        USER_UUID=$(echo "$user_response" | jq -r '.response.uuid')
        USER_SHORT_UUID=$(echo "$user_response" | jq -r '.response.shortUuid')
        USER_SUBSCRIPTION_UUID=$(echo "$user_response" | jq -r '.response.subscriptionUuid')
        USER_VLESS_UUID=$(echo "$user_response" | jq -r '.response.vlessUuid')
        USER_TROJAN_PASSWORD=$(echo "$user_response" | jq -r '.response.trojanPassword')
        USER_SS_PASSWORD=$(echo "$user_response" | jq -r '.response.ssPassword')
        USER_SUBSCRIPTION_URL=$(echo "$user_response" | jq -r '.response.subscriptionUrl')

        return 0
    else
        echo -e "${BOLD_RED}$(t api_failed_create_user_format)${NC}"
        echo
        echo "$(t api_request_body_was)"
        echo "$user_data"
        echo
        echo "$(t api_response):"
        echo "$user_response"
        return 1
    fi
}

# Common user registration
register_panel_user() {
    REG_TOKEN=$(register_user "127.0.0.1:3000" "$PANEL_DOMAIN" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -z "$REG_TOKEN" ]; then
        show_error "$(t api_failed_register_user)"
        exit 1
    fi
}
