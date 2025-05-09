#!/bin/bash

vless_configuration_all_in_one() {
  local panel_url="$1"
  local panel_domain="$2"
  local token="$3"
  local SELF_STEAL_PORT="$4"
  local NODE_PORT="$5"
  local config_file="$REMNAWAVE_DIR/config.json"

  NODE_HOST="172.17.0.1"

  local keys_result=$(generate_vless_keys)
  if [ $? -ne 0 ]; then
    return 1
  fi

  local private_key=$(echo "$keys_result" | cut -d':' -f1)

  generate_vless_config "$config_file" "$panel_domain" "$SELF_STEAL_PORT" "$private_key"

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

  if ! create_vless_host "$panel_url" "$token" "$panel_domain" "$inbound_uuid" "$panel_domain"; then
    return 1
  fi
}
