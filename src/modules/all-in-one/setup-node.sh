#!/bin/bash

# ===================================================================================
#                              REMNAWAVE NODE INSTALLATION
# ===================================================================================

setup_node_all_in_one() {
  local panel_url=$1
  local token=$2
  local NODE_PORT=$3

  create_dir "$LOCAL_REMNANODE_DIR"

  cd "$LOCAL_REMNANODE_DIR"

  cat >docker-compose.yml <<EOL
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

  create_makefile "$LOCAL_REMNANODE_DIR"

  local pubkey=$(get_public_key "$panel_url" "$token" "$PANEL_DOMAIN")

  if [ -z "$pubkey" ]; then
    return 1
  fi

  local CERTIFICATE="SSL_CERT=\"$pubkey\""

  echo -e "### APP ###\nAPP_PORT=$NODE_PORT\n$CERTIFICATE" >.env
}

setup_and_start_all_in_one_node() {
  setup_node_all_in_one "127.0.0.1:3000" "$REG_TOKEN" "$NODE_PORT"

  if ! start_container "$LOCAL_REMNANODE_DIR" "Remnawave Node"; then
    show_info "Installation stopped" "$BOLD_RED"
    exit 1
  fi
}
