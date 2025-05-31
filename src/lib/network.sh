#!/bin/bash

# ===================================================================================
#                                NETWORK FUNCTIONS
# ===================================================================================

# Validate port number
validate_port() {
    local port="$1"

    # Check if port is a number
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo -e "${BOLD_RED}Error: Port must be a number.${NC}" >&2
        return 1
    fi

    # Check port range
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${BOLD_RED}Error: Port must be between 1 and 65535.${NC}" >&2
        return 1
    fi

    echo "$port"
}

# Check if port is available
is_port_available() {
    local port="$1"

    # Check if port is in use
    if ss -tuln | grep -q ":$port "; then
        return 1 # Port is in use
    else
        return 0 # Port is available
    fi
}

# Find next available port starting from given port
find_available_port() {
    local start_port="$1"
    local max_attempts=100
    local current_port="$start_port"

    for ((i = 0; i < max_attempts; i++)); do
        if is_port_available "$current_port"; then
            echo "$current_port"
            return 0
        fi
        ((current_port++))
    done

    return 1 # No available port found
}

# Function to check if IP is in any of the CIDR ranges (Cloudflare or any other passed as array)
is_ip_in_cidrs() {
    local ip="$1"
    shift
    local cidrs=("$@")

    # Helper function to convert IP (format x.x.x.x) to 32-bit number
    function ip2dec() {
        local a b c d
        IFS=. read -r a b c d <<<"$1"
        echo $(((a << 24) + (b << 16) + (c << 8) + d))
    }

    # Function to check if IP is in CIDR
    function in_cidr() {
        local ip_dec mask base_ip cidr_ip cidr_mask
        ip_dec=$(ip2dec "$1")
        base_ip="${2%/*}"
        mask="${2#*/}"

        cidr_ip=$(ip2dec "$base_ip")
        cidr_mask=$((0xFFFFFFFF << (32 - mask) & 0xFFFFFFFF))

        # Если (ip_dec & cidr_mask) == (cidr_ip & cidr_mask), IP попадает в диапазон
        if (((ip_dec & cidr_mask) == (cidr_ip & cidr_mask))); then
            return 0
        else
            return 1
        fi
    }

    # Check IP against all ranges; if it matches at least one, return 0
    for range in "${cidrs[@]}"; do
        if in_cidr "$ip" "$range"; then
            return 0
        fi
    done

    return 1
}

# Request email with validation
prompt_email() {
    local prompt="$1"
    local result=""

    while true; do
        # Display prompt
        prompt_formatted_text="${ORANGE}${prompt}: ${NC}"
        read -p "$prompt_formatted_text" result

        # Email validation
        if [[ "$result" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo -e "${BOLD_RED}Invalid email format.${NC}" >&2
            if prompt_yes_no "Proceed with this value? Current value: $result" "$ORANGE"; then
                break
            fi
        fi
    done

    echo >&2

    echo "$result"
}

# Get an available port starting from the specified default
get_available_port() {
    local default_port="$1"
    local port_name="$2" # For display purposes only

    # Validate the default port
    local port=$(validate_port "$default_port")

    # Check if port is available
    if is_port_available "$port"; then
        show_info "Using default $port_name port: $port"
        echo "$port"
        return 0
    else
        # Find next available port
        show_info "Default $port_name port $port is already in use. Finding available port..."
        local available_port=$(find_available_port "$((port + 1))")

        if [ $? -eq 0 ]; then
            show_info "Using $port_name port: $available_port"
            echo "$available_port"
            return 0
        else
            show_error "Failed to find an available port for $port_name!"
            # Return the default as fallback
            echo "$default_port"
            return 1
        fi
    fi
}

check_required_port() {
    local required_port="$1"

    # Validate the port
    local port=$(validate_port "$required_port")

    if is_port_available "$port"; then
        echo "$port"
        return 0
    else
        return 1
    fi
}

# Request domain with validation and IP verification
prompt_domain() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"
    local show_warning="${3:-true}"
    local allow_cf_proxy="${4:-true}"
    local expect_different_ip="${5:-false}" # For separate installation, domain should point to different server

    local domain
    while true; do
        echo -ne "${prompt_color}${prompt_text}: ${NC}" >&2
        read domain
        echo >&2

        # Base domain validation
        if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            echo -e "${BOLD_RED}Invalid domain format. Please try again.${NC}" >&2
            continue
        fi

        # Get domain's IP
        local domain_ip=""
        domain_ip=$(dig +short A "$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

        # Get public IP of the current server
        local server_ip=""
        server_ip=$(curl -s -4 ifconfig.me || curl -s -4 api.ipify.org || curl -s -4 ipinfo.io/ip)

        # If unable to get IPs, warn and ask if user wants to continue
        if [ -z "$domain_ip" ] || [ -z "$server_ip" ]; then
            if [ "$show_warning" = true ]; then
                show_warning "Failed to determine domain or server IP address." 2
                show_warning "Make sure that the domain $domain is properly configured and points to the server ($server_ip)." 2
                if prompt_yes_no "Continue with this domain despite being unable to verify its IP address?" "$ORANGE"; then
                    break
                else
                    continue
                fi
            fi
        fi

        # Load current Cloudflare ranges
        local cf_ranges
        cf_ranges=$(curl -s https://www.cloudflare.com/ips-v4) || true # if curl fails, variable remains empty

        # If loaded successfully, convert to array
        local cf_array=()
        if [ -n "$cf_ranges" ]; then
            # Convert received lines to array
            IFS=$'\n' read -r -d '' -a cf_array <<<"$cf_ranges"
        fi

        # Check if domain_ip is in Cloudflare ranges
        if [ ${#cf_array[@]} -gt 0 ] && is_ip_in_cidrs "$domain_ip" "${cf_array[@]}"; then
            # IP is Cloudflare
            if [ "$allow_cf_proxy" = true ]; then
                # Proxying allowed — all good
                break
            else
                # Proxying not allowed — warn
                if [ "$show_warning" = true ]; then
                    echo
                    show_warning "Domain $domain points to Cloudflare IP ($domain_ip)." 2
                    show_warning "Disable Cloudflare proxying - selfsteal domain proxying is not allowed." 2
                    if prompt_yes_no "Continue with this domain despite Cloudflare proxy configuration issue?" "$ORANGE"; then
                        break
                    else
                        continue
                    fi
                fi
            fi
        else
            # Check if domain IP matches server IP based on expectation
            if [ "$expect_different_ip" = "true" ]; then
                # For separate installation, domain should NOT point to current server
                if [ "$domain_ip" = "$server_ip" ]; then
                    if [ "$show_warning" = true ]; then
                        show_warning "Domain $domain points to this server IP ($server_ip)." 2
                        show_warning "For separate installation, selfsteal domain should point to the node server, not the panel server." 2
                        if prompt_yes_no "Continue with this domain despite it pointing to the current server?" "$ORANGE"; then
                            break
                        else
                            continue
                        fi
                    fi
                else
                    # Domain points to different server - this is expected for separate installation
                    if [ "$show_warning" = true ]; then
                        :
                    fi
                    break
                fi
            else
                # Normal case: domain should point to current server
                if [ "$domain_ip" != "$server_ip" ]; then
                    if [ "$show_warning" = true ]; then
                        show_warning "Domain $domain points to IP address $domain_ip, which differs from the server IP ($server_ip)." 2
                        if prompt_yes_no "Continue with this domain despite the IP address mismatch?" "$ORANGE"; then
                            break
                        else
                            continue
                        fi
                    fi
                else
                    # Domain points to server IP - all good
                    break
                fi
            fi
        fi
    done

    echo "$domain"
    echo
}

allow_ufw_node_port_from_panel() {
    local panel_subnet=172.30.0.0/16
    ufw allow from "$panel_subnet" to any port $NODE_PORT proto tcp
    ufw reload
}
