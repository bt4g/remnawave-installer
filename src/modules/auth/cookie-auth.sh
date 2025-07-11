# Start Caddy with cookie auth
start_caddy_cookie_auth() {
  if ! start_container "$REMNAWAVE_DIR/caddy" "Caddy"; then
    show_info "$(t services_installation_stopped)" "$BOLD_RED"
    exit 1
  fi
}

generate_cookie_auth_secrets() {
  PANEL_SECRET_KEY=$(generate_nonce 64)
}

# Save credentials for cookie auth
save_credentials_cookie_auth() {
  CREDENTIALS_FILE="$REMNAWAVE_DIR/credentials.txt"
  echo "PANEL URL: https://$PANEL_DOMAIN?caddy=$PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"
  echo >>"$CREDENTIALS_FILE"
  echo "REMNAWAVE ADMIN USERNAME: $SUPERADMIN_USERNAME" >>"$CREDENTIALS_FILE"
  echo "REMNAWAVE ADMIN PASSWORD: $SUPERADMIN_PASSWORD" >>"$CREDENTIALS_FILE"

  chmod 600 "$CREDENTIALS_FILE"
}

display_cookie_auth_results() {
  local installation_type="${1:-panel}" # Default to panel if not specified
  local secure_panel_url="https://$PANEL_DOMAIN/auth/login?caddy=$PANEL_SECRET_KEY"

  # Calculate width based on longest line
  local max_width=${#secure_panel_url}
  if [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$installation_type" = "all-in-one" ]; then
    if [ ${#USER_SUBSCRIPTION_URL} -gt $max_width ]; then
      max_width=${#USER_SUBSCRIPTION_URL}
    fi
  fi
  local effective_width=$((max_width + 3))
  local border_line=$(printf '─%.0s' $(seq 1 $effective_width))

  print_text_line() {
    local text="$1"
    local padding=$((effective_width - ${#text} - 1))
    echo -e "\033[1m│ $text$(printf '%*s' $padding)│\033[0m"
  }

  print_empty_line() {
    echo -e "\033[1m│$(printf '%*s' $effective_width)│\033[0m"
  }

  echo -e "\033[1m┌${border_line}┐\033[0m"

  print_text_line "$(t results_secure_login_link)"
  print_empty_line
  print_text_line "$secure_panel_url"
  print_empty_line

  # Show subscription URL only for all-in-one installation
  if [ "$installation_type" = "all-in-one" ] && [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$USER_SUBSCRIPTION_URL" != "null" ]; then
    print_text_line "$(t results_user_subscription_url)"
    print_text_line "$USER_SUBSCRIPTION_URL"
    print_empty_line
  fi

  print_text_line "$(t results_admin_login) $SUPERADMIN_USERNAME"
  print_text_line "$(t results_admin_password) $SUPERADMIN_PASSWORD"
  print_empty_line
  echo -e "\033[1m└${border_line}┘\033[0m"

  echo
  show_success "$(t success_credentials_saved) $CREDENTIALS_FILE"
  echo -e "${BOLD_BLUE}$(t info_installation_directory) ${NC}$REMNAWAVE_DIR/"
  echo

  # Show QR code for subscription URL if available
  if [ "$installation_type" = "all-in-one" ] && [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$USER_SUBSCRIPTION_URL" != "null" ]; then
    generate_qr_code "$USER_SUBSCRIPTION_URL" "$(t qr_subscription_url)"
    echo
  fi

  cd ~

  echo -e "${BOLD_GREEN}$(t success_installation_complete)${NC}"
  read -r
}
