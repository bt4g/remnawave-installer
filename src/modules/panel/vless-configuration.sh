#!/bin/bash

vless_configuration() {
  local panel_url="$1"
  local panel_domain="$2"
  local token="$3"

  local config_file="$REMNAWAVE_DIR/config.json"

  local keys_result=$(generate_vless_keys)
  if [ $? -ne 0 ]; then
    return 1
  fi

  local private_key=$(echo "$keys_result" | cut -d':' -f1)

  generate_vless_config "$config_file" "$SELF_STEAL_DOMAIN" "$SELF_STEAL_PORT" "$private_key"

  if ! update_xray_config "$panel_url" "$token" "$panel_domain" "$config_file"; then
    return 1
  fi

  if ! create_vless_node "$panel_url" "$token" "$panel_domain" "$NODE_HOST" "$NODE_PORT"; then
    return 1
  fi

  local inbound_uuid=$(get_inbounds "$panel_url" "$token" "$panel_domain")
  if [ -z "$inbound_uuid" ]; then
    return 1
  fi

  if ! create_vless_host "$panel_url" "$token" "$panel_domain" "$inbound_uuid" "$SELF_STEAL_DOMAIN"; then
    return 1
  fi

  local pubkey=$(get_public_key "$panel_url" "$token" "$panel_domain")
  if [ -z "$pubkey" ]; then
    return 1
  fi

  echo
  echo -e "${GREEN}Public key (required for node installation):${NC}"
  echo
  echo -e "SSL_CERT=\"$pubkey\""
  echo
}
