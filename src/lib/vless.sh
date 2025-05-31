#!/bin/bash

# ===================================================================================
#                                VLESS CONFIGURATION
# ===================================================================================

# Generate keys for VLESS Reality
generate_vless_keys() {
  local temp_file=$(mktemp)

  # Generate x25519 keys using Docker
  docker run --rm ghcr.io/xtls/xray-core x25519 >"$temp_file" 2>&1 &
  spinner $! "Generating x25519 keys..."
  keys=$(cat "$temp_file")

  local private_key=$(echo "$keys" | grep "Private key:" | awk '{print $3}')
  local public_key=$(echo "$keys" | grep "Public key:" | awk '{print $3}')
  rm -f "$temp_file"

  if [ -z "$private_key" ] || [ -z "$public_key" ]; then
    echo -e "${BOLD_RED}Error: Failed to generate keys.${NC}"
    return 1
  fi

  # Return keys via echo
  echo "$private_key:$public_key"
}

# Create VLESS Xray configuration
generate_xray_config() {
  local config_file="$1"
  local self_steal_domain="$2"
  local CADDY_LOCAL_PORT="$3"
  local private_key="$4"

  local short_id=$(openssl rand -hex 8)

  cat >"$config_file" <<EOL
{
  "log": {
    "loglevel": "debug"
  },
  "inbounds": [
    {
      "tag": "VLESS TCP REALITY",
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "127.0.0.1:$CADDY_LOCAL_PORT",
          "show": false,
          "xver": 1,
          "shortIds": [
            "$short_id"
          ],
          "privateKey": "$private_key",
          "serverNames": [
              "$self_steal_domain"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    },
    {
      "tag": "BLOCK",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "type": "field",
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "domain": [
          "geosite:private"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "BLOCK"
      }
    ]
  }
}
EOL
}

# Update Xray configuration
update_xray_config() {
  local panel_url="$1"
  local token="$2"
  local panel_domain="$3"
  local config_file="$4"

  local temp_file=$(mktemp)
  local new_config=$(cat "$config_file")

  make_api_request "PUT" "http://$panel_url/api/xray" "$token" "$panel_domain" "$new_config" >"$temp_file" 2>&1 &
  spinner $! "Updating Xray configuration..."
  local update_response=$(cat "$temp_file")
  rm -f "$temp_file"

  if [ -z "$update_response" ]; then
    echo -e "${BOLD_RED}Error: Empty response from server when updating Xray config.${NC}"
    return 1
  fi

  if echo "$update_response" | jq -e '.response.config' >/dev/null; then
    return 0
  else
    echo -e "${BOLD_RED}Error: Failed to update Xray configuration.${NC}"
    return 1
  fi
}
