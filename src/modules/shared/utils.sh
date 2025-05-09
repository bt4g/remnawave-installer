#!/bin/bash

# ===================================================================================
#                                UTILITY FUNCTIONS
# ===================================================================================

# Display a message about successful panel installation
display_panel_installation_complete_message() {
    local secure_panel_url="https://$SCRIPT_PANEL_DOMAIN/auth/login?caddy=$PANEL_SECRET_KEY"
    local effective_width=$((${#secure_panel_url} + 3))
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

    print_text_line "Your panel domain:"
    print_text_line "https://$SCRIPT_PANEL_DOMAIN"
    print_empty_line
    print_text_line "Secure login link (with secret key):"
    print_text_line "$secure_panel_url"
    print_empty_line
    print_text_line "Your subscription domain:"
    print_text_line "https://$SCRIPT_SUB_DOMAIN"
    print_empty_line
    print_text_line "Admin login: $SUPERADMIN_USERNAME"
    print_text_line "Admin password: $SUPERADMIN_PASSWORD"
    print_empty_line
    echo -e "\033[1m└${border_line}┘\033[0m"

    echo
    show_success "Credentials saved in file: $CREDENTIALS_FILE"
    echo -e "${BOLD_BLUE}Installation directory: ${NC}$REMNAWAVE_DIR/"
    echo

    cd ~

    echo -e "${BOLD_GREEN}Installation complete. Press Enter to continue...${NC}"
    read -r
}

# Function for safely updating .env file with multiple keys
update_file() {
    local env_file="$1"
    shift

    # Check for parameters
    if [ "$#" -eq 0 ] || [ $(($# % 2)) -ne 0 ]; then
        echo "Error: invalid number of arguments. Should be even number of keys and values." >&2
        return 1
    fi

    # Convert arguments to key and value arrays
    local keys=()
    local values=()

    while [ "$#" -gt 0 ]; do
        keys+=("$1")
        values+=("$2")
        shift 2
    done

    # Create a temporary file
    local temp_file=$(mktemp)

    # Process file line by line and replace needed lines
    while IFS= read -r line || [[ -n "$line" ]]; do
        local key_found=false
        for i in "${!keys[@]}"; do
            if [[ "$line" =~ ^${keys[$i]}= ]]; then
                echo "${keys[$i]}=${values[$i]}" >>"$temp_file"
                key_found=true
                break
            fi
        done

        if [ "$key_found" = false ]; then
            echo "$line" >>"$temp_file"
        fi
    done <"$env_file"

    # Replace original file
    mv "$temp_file" "$env_file"
}
