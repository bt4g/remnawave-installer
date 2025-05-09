#!/bin/bash

# ===================================================================================
#                                VALIDATION FUNCTIONS
# ===================================================================================

# Validate an IP address
validate_ip() {
    local input="$1"

    # Trim spaces
    input=$(echo "$input" | tr -d ' ')

    # If empty, fail
    if [ -z "$input" ]; then
        return 1
    fi

    # Check for IP pattern
    if [[ $input =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Validate each octet is <= 255
        IFS='.' read -r -a octets <<<"$input"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        echo "$input"
        return 0
    fi

    return 1
}

# Validate a domain name
validate_domain_name() {
    local input="$1"
    local max_length="${2:-253}" # Maximum domain length by standard

    # Trim spaces
    input=$(echo "$input" | tr -d ' ')

    # If empty, fail
    if [ -z "$input" ]; then
        return 1
    fi

    # Check length
    if [ ${#input} -gt $max_length ]; then
        return 1
    fi

    # Domain pattern validation - must contain at least one dot and not start/end with dot or dash
    if [[ $input =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$ ]] &&
        [[ ! $input =~ \.\. ]]; then
        echo "$input"
        return 0
    fi

    return 1
}

# Validate either an IP address or domain name
validate_domain() {
    local input="$1"
    local max_length="${2:-253}"

    # Try as IP first
    local result=$(validate_ip "$input")
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    # Try as domain name
    result=$(validate_domain_name "$input" "$max_length")
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    return 1
}

# Request numeric value with validation
prompt_number() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"
    local min="${3:-1}"
    local max="${4:-}"

    local number
    while true; do
        echo -ne "${prompt_color}${prompt_text}: ${NC}" >&2
        read number
        echo >&2

        # Number validation
        if [[ "$number" =~ ^[0-9]+$ ]]; then
            if [ -n "$min" ] && [ "$number" -lt "$min" ]; then
                echo -e "${BOLD_RED}Value must be at least ${min}.${NC}" >&2
                continue
            fi

            if [ -n "$max" ] && [ "$number" -gt "$max" ]; then
                echo -e "${BOLD_RED}Value must be at most ${max}.${NC}" >&2
                continue
            fi

            break
        else
            echo -e "${BOLD_RED}Please enter a valid numeric value.${NC}" >&2
        fi
    done

    echo "$number"
}

# Function for validating and cleaning the port
validate_port() {
    local input="$1"
    local default_port="$2"

    # Remove all characters except digits
    local cleaned_port=$(echo "$input" | tr -cd '0-9')

    # Check for empty string after cleaning
    if [ -z "$cleaned_port" ] && [ -n "$default_port" ]; then
        echo "$default_port"
        return 0
    elif [ -z "$cleaned_port" ]; then
        echo ""
        return 1
    fi

    # Check port range
    if [ "$cleaned_port" -lt 1 ] || [ "$cleaned_port" -gt 65535 ]; then
        if [ -n "$default_port" ]; then
            echo "$default_port"
            return 0
        else
            echo ""
            return 1
        fi
    fi

    echo "$cleaned_port"
    return 0
}

# Check if the port is available
is_port_available() {
    local port=$1
    # Try to open a temporary server on the port
    # If returns 0, port is available; if 1 - occupied
    (echo >/dev/tcp/localhost/$port) >/dev/null 2>&1
    if [ $? -eq 1 ]; then
        return 0 # Port is available
    else
        return 1 # Port is occupied
    fi
}

# Find available port, starting from the specified one
find_available_port() {
    local port="$1"

    # Try sequentially until we find an available one
    while true; do
        if is_port_available "$port"; then
            show_info "Port $port is available."
            echo "$port"
            return 0
        fi
        ((port++))
        # Limit to 65535 just in case
        if [ "$port" -gt 65535 ]; then
            show_info "Failed to find an available port!"
            return 1
        fi
    done
}

# Function for safe port reading with validation
read_port() {
    local prompt="$1"
    local default_value="${2:-}"
    local skip_availability_check="${3:-false}"
    local result=""
    local attempts=0
    local max_attempts=10

    while [ $attempts -lt $max_attempts ]; do
        # Display prompt with default value
        if [ -n "$default_value" ]; then
            prompt_formatted_text="${ORANGE}${prompt} [$default_value]:${NC}"
            read -p "$prompt_formatted_text" result
        else
            prompt_formatted_text="${ORANGE}${prompt}:${NC}"
            read -p "$prompt_formatted_text" result
        fi

        # If input is empty and default value exists, use it
        if [ -z "$result" ] && [ -n "$default_value" ]; then
            result="$default_value"
        fi

        # Port validation - store result in variable
        result=$(validate_port "$result" "$default_value")
        local status=$?

        if [ $status -ne 0 ]; then
            echo -e "${BOLD_RED}Invalid port number. Please use a number between 1 and 65535.${NC}" >&2
            ((attempts++))
            continue
        fi

        # Check port availability if needed
        if [ "$skip_availability_check" != "true" ]; then
            if ! is_port_available "$result"; then
                echo -e "${BOLD_RED}Port $result is already in use.${NC}" >&2
                # Try to find an available port
                local next_port=$((result + 1))
                local available_port=$(find_available_port "$next_port")
                if [ $? -eq 0 ]; then
                    echo -e "${ORANGE}Would you like to use port $available_port instead?${NC}" >&2
                    if prompt_yes_no "Use port $available_port instead?" "$ORANGE"; then
                        result="$available_port"
                        break
                    fi
                else
                    echo -e "${BOLD_RED}Failed to find an available port.${NC}" >&2
                fi
                ((attempts++))
                continue
            fi
        fi

        # If we made it here, all checks passed
        break
    done

    if [ $attempts -eq $max_attempts ]; then
        echo -e "${BOLD_RED}Maximum number of attempts exceeded. Using default value: $default_value${NC}" >&2
        result="$default_value"
    fi
    # Add a newline for better formatting between prompts
    echo "" >&2

    echo "$result"
}

simple_read_domain_or_ip() {
    local prompt="$1"
    local default_value="$2"
    local validation_type="${3:-both}" # Can be 'domain_only', 'ip_only', or 'both'
    local result=""
    local attempts=0
    local max_attempts=10

    while [ $attempts -lt $max_attempts ]; do
        # Show prompt with default value if present
        local prompt_formatted_text=""
        if [ -n "$default_value" ]; then
            prompt_formatted_text="${ORANGE}${prompt} [$default_value]:${NC}"
        else
            prompt_formatted_text="${ORANGE}${prompt}:${NC}"
        fi

        read -p "$prompt_formatted_text" input

        # If input is empty and we have a default value, use it
        if [ -z "$input" ] && [ -n "$default_value" ]; then
            result="$default_value"
            break
        fi

        # Perform validation based on validation_type
        if [ "$validation_type" = "ip_only" ]; then
            # Only validate as IP address
            result=$(validate_ip "$input")
            local status=$?

            if [ $status -eq 0 ]; then
                break
            else
                echo -e "${BOLD_RED}Invalid IP address format. IP must be in format X.X.X.X, where X is a number from 0 to 255.${NC}" >&2
            fi
        elif [ "$validation_type" = "domain_only" ]; then
            # Only validate as domain name
            result=$(validate_domain_name "$input")
            local status=$?

            if [ $status -eq 0 ]; then
                break
            else
                echo -e "${BOLD_RED}Invalid domain name format. Domain must contain at least one dot and not start/end with dot or dash.${NC}" >&2
                echo -e "${BOLD_RED}Use only letters, digits, dots, and dashes.${NC}" >&2
            fi
        else
            # Default: validate as either domain or IP
            result=$(validate_domain "$input")
            local status=$?

            if [ $status -eq 0 ]; then
                break
            else
                echo -e "${BOLD_RED}Invalid domain or IP address format.${NC}" >&2
                echo -e "${BOLD_RED}Domain must contain at least one dot and not start/end with dot or dash.${NC}" >&2
                echo -e "${BOLD_RED}IP address must be in format X.X.X.X, where X is a number from 0 to 255.${NC}" >&2
            fi
        fi

        ((attempts++))
    done

    if [ $attempts -eq $max_attempts ]; then
        echo -e "${BOLD_RED}Maximum number of attempts exceeded. Using default value: $default_value${NC}" >&2
        result="$default_value"
    fi

    echo "$result"
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

# Request domain with validation and IP verification
prompt_domain() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"
    local show_warning="${3:-true}"
    local allow_cf_proxy="${4:-true}"

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
                    echo ""
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
            # If not Cloudflare, check if domain IP matches server IP
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
    done

    echo "$domain"
    echo ""
}
