#!/bin/bash

# Color definitions for output
BOLD_BLUE=$(tput setaf 4)
BOLD_GREEN=$(tput setaf 2)
LIGHT_GREEN=$(tput setaf 10)
BOLD_BLUE_MENU=$(tput setaf 6)
ORANGE=$(tput setaf 3)
BOLD_RED=$(tput setaf 1)
BLUE=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

# Script version
VERSION="1.0"

# Main directories
REMNAWAVE_DIR="/opt/remnawave"
REMNANODE_ROOT_DIR="/opt/remnanode"
REMNANODE_DIR="/opt/remnanode/node"
SELFSTEAL_DIR="/opt/remnanode/selfsteal"
LOCAL_REMNANODE_DIR="$REMNAWAVE_DIR/node" # Local node directory (with panel)

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

# Function to check and remove previous installation
remove_previous_installation() {
    # Check for previous installation
    local containers=("remnawave-subscription-page" "remnawave" "remnawave-db" "remnawave-redis" "remnanode" "caddy-remnawave")
    local container_exists=false

    # Check if any of the containers exist
    for container in "${containers[@]}"; do
        if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$container"; then
            container_exists=true
            break
        fi
    done

    if [ -d "$REMNAWAVE_DIR" ] || [ "$container_exists" = true ]; then
        show_warning "Previous RemnaWave installation detected."
        if prompt_yes_no "To continue, you need to remove previous Remnawave installations. Confirm removal?" "$ORANGE"; then
            # Check for Caddy and stop it
            if [ -f "$REMNAWAVE_DIR/caddy/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f caddy/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Stopping Caddy container"
            fi
            # Check for subscription page and stop it
            if [ -f "$REMNAWAVE_DIR/subscription-page/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f subscription-page/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Stopping remnawave-subscription-page container"
            fi
            # Check for node and stop it
            if [ -f "$LOCAL_REMNANODE_DIR/docker-compose.yml" ]; then
                cd $LOCAL_REMNANODE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Stopping Remnawave node container"
            fi
            # Check for panel and stop it
            if [ -f "$REMNAWAVE_DIR/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Stopping Remnawave panel containers"
            fi
            # Check for panel and stop it
            if [ -f "$REMNAWAVE_DIR/panel/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Stopping Remnawave panel containers"
            fi

            # Check for remaining containers and stop/remove them
            for container in "${containers[@]}"; do
                if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
                    docker stop "$container" >/dev/null 2>&1 && docker rm "$container" >/dev/null 2>&1 &
                    spinner $! "Stopping and removing container $container"
                fi
            done

            # Remove remaining Docker images
            docker rmi $(docker images -q) -f >/dev/null 2>&1 &
            spinner $! "Removing Docker images"

            # Remove directory
            rm -rf $REMNAWAVE_DIR >/dev/null 2>&1 &
            spinner $! "Removing directory $REMNAWAVE_DIR"
            # Remove Docker volumes
            docker volume rm remnawave-db-data remnawave-redis-data >/dev/null 2>&1 &
            spinner $! "Removing Docker volumes: remnawave-db-data and remnawave-redis-data"
            show_success "Previous installation removed."
        else
            return 0
        fi
    fi
}

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

restart_panel() {
    local no_wait=${1:-false} # Optional parameter to skip waiting for user input
    # Check for panel directory
    if [ ! -d /opt/remnawave ]; then
        show_error "Error: panel directory not found at /opt/remnawave!"
        show_error "Please install Remnawave panel first."
    else
        # Check for docker-compose.yml in panel directory
        if [ ! -f /opt/remnawave/docker-compose.yml ]; then
            show_error "Error: docker-compose.yml not found in panel directory!"
            show_error "Panel installation may be corrupted or incomplete."
        else
            # Variable to track subscription-page directory existence
            SUBSCRIPTION_PAGE_EXISTS=false

            # Check for subscription-page directory
            if [ -d /opt/remnawave/subscription-page ] && [ -f /opt/remnawave/subscription-page/docker-compose.yml ]; then
                SUBSCRIPTION_PAGE_EXISTS=true
            fi

            # Stop subscription page if it exists
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd /opt/remnawave/subscription-page && docker compose down >/dev/null 2>&1 &
                spinner $! "Stopping remnawave-subscription-page container"
            fi

            # Stop panel
            cd /opt/remnawave && docker compose down >/dev/null 2>&1 &
            spinner $! "Restarting panel..."

            # Start panel
            cd /opt/remnawave && docker compose up -d >/dev/null 2>&1 &
            spinner $! "Restarting panel..."

            # Start subscription page if it exists
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd /opt/remnawave/subscription-page && docker compose up -d >/dev/null 2>&1 &
                spinner $! "Restarting panel..."
            fi
            show_info "Panel restarted"
        fi
    fi
    if [ "$no_wait" != "true" ]; then
        echo -e "${BOLD_GREEN}Press Enter to continue...${NC}"
        read
    fi
}

start_container() {
    local directory="$1"      # Directory with docker-compose.yml
    local container_name="$2" # Container name to check in docker ps
    local service_name="$3"   # Service name for messages
    local wait_time=${4:-1}   # Wait time in seconds

    # Change to the required directory
    cd "$directory"

    # Run the whole process in the background using a subshell
    (
        docker compose up -d >/dev/null 2>&1
        sleep $wait_time
    ) &

    local bg_pid=$!

    # Show spinner for the entire startup and wait process
    spinner $bg_pid "Starting container ${service_name}..."

    # Check container status
    if ! docker ps | grep -q "$container_name"; then
        echo -e "${BOLD_RED}Container $service_name did not start. Check the configuration.${NC}"
        echo -e "${ORANGE}You can check logs later using 'make logs' in directory $directory.${NC}"
        return 1
    else
        # echo -e "${BOLD_GREEN}$service_name started successfully.${NC}"
        # echo ""
        return 0
    fi
}

generate_secure_password() {
    local length="${1:-16}"
    local password=""
    local special_chars='!%^&*_+.,'
    local uppercase_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local lowercase_chars='abcdefghijklmnopqrstuvwxyz'
    local number_chars='0123456789'
    local alphanumeric_chars="${uppercase_chars}${lowercase_chars}${number_chars}"

    # Generate the initial password from letters and digits only
    if command -v openssl &>/dev/null; then
        password="$(openssl rand -base64 48 | tr -dc "$alphanumeric_chars" | head -c "$length")"
    else
        # If openssl is unavailable, fallback to /dev/urandom
        password="$(head -c 100 /dev/urandom | tr -dc "$alphanumeric_chars" | head -c "$length")"
    fi

    # Check for presence of each character type and add missing ones
    # If no uppercase character, add one
    if ! [[ "$password" =~ [$uppercase_chars] ]]; then
        local position=$((RANDOM % length))
        local one_uppercase="$(echo "$uppercase_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_uppercase}${password:$((position + 1))}"
    fi

    # If no lowercase character, add one
    if ! [[ "$password" =~ [$lowercase_chars] ]]; then
        local position=$((RANDOM % length))
        local one_lowercase="$(echo "$lowercase_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_lowercase}${password:$((position + 1))}"
    fi

    # If no digit, add one
    if ! [[ "$password" =~ [$number_chars] ]]; then
        local position=$((RANDOM % length))
        local one_number="$(echo "$number_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_number}${password:$((position + 1))}"
    fi

    # Add 1 to 3 special characters (depending on password length), but no more than 25% of password length
    local special_count=$((length / 4))
    special_count=$((special_count > 0 ? special_count : 1))
    special_count=$((special_count < 3 ? special_count : 3))

    for ((i = 0; i < special_count; i++)); do
        # Choose a random position, avoiding first and last character
        local position=$((RANDOM % (length - 2) + 1))
        local one_special="$(echo "$special_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_special}${password:$((position + 1))}"
    done

    echo "$password"
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

# Create a common Makefile for managing services
create_makefile() {
    local directory="$1"
    cat >"$directory/Makefile" <<'EOF'
.PHONY: start stop restart logs

start:
	docker compose up -d && docker compose logs -f -t
stop:
	docker compose down
restart:
	docker compose down && docker compose up -d
logs:
	docker compose logs -f -t
EOF
}

# ===================================================================================
#                                VALIDATION FUNCTIONS
# ===================================================================================

# Function to validate and clean domain name or IP address
# Leaves only valid characters: letters, digits, dots, and dashes
# Usage:
#   validate_domain "example.com"
validate_domain() {
    local input="$1"
    local max_length="${2:-253}" # Maximum domain length by standard

    # Check for IP address
    if [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Check each octet of IP address
        local valid_ip=true
        IFS='.' read -r -a octets <<<"$input"
        for octet in "${octets[@]}"; do
            if [[ ! "$octet" =~ ^[0-9]+$ ]] || [ "$octet" -gt 255 ]; then
                valid_ip=false
                break
            fi
        done

        if [ "$valid_ip" = true ]; then
            echo "$input"
            return 0
        fi
    fi

    # Remove all characters except letters, digits, dots, and dashes
    local cleaned_domain=$(echo "$input" | tr -cd 'a-zA-Z0-9.-')

    # Проверка на пустую строку после очистки
    if [ -z "$cleaned_domain" ]; then
        echo ""
        return 1
    fi

    # Check for maximum length
    if [ ${#cleaned_domain} -gt $max_length ]; then
        cleaned_domain=${cleaned_domain:0:$max_length}
    fi

    # Check domain format (basic check)
    # Domain must contain at least one dot and not start/end with dot or dash
    if
        [[ ! "$cleaned_domain" =~ \. ]] ||
            [[ "$cleaned_domain" =~ ^[\.-] ]] ||
            [[ "$cleaned_domain" =~ [\.-]$ ]]
    then
        echo "$cleaned_domain"
        return 1
    fi

    echo "$cleaned_domain"
    return 0
}

# Safe reading of user input with validation
# Usage:
#   read_domain "Enter domain:" "example.com"
read_domain() {
    local prompt="$1"
    local default_value="$2"
    local max_attempts="${3:-3}"
    local result=""
    local attempts=0

    while [ $attempts -lt $max_attempts ]; do
        # Show prompt with default value if present
        local prompt_formatted_text=""
        if [ -n "$default_value" ]; then
            prompt_formatted_text="${ORANGE}${prompt} [$default_value]:${NC}"
        else
            prompt_formatted_text="${ORANGE}${prompt}:${NC}"
        fi

        read -p "$prompt_formatted_text" input

        # Если ввод пустой и есть дефолтное значение, используем его
        if [ -z "$input" ] && [ -n "$default_value" ]; then
            result="$default_value"
            break
        fi

        # Validate input
        result=$(validate_domain "$input")
        local status=$?

        if [ $status -eq 0 ]; then
            break
        else
            echo -e "${BOLD_RED}Invalid domain or IP address format. Please use only letters, digits, dots, and dashes.${NC}" >&2
            echo -e "${BOLD_RED}Domain must contain at least one dot and not start/end with dot or dash.${NC}" >&2
            echo -e "${BOLD_RED}IP address must be in format X.X.X.X, where X is a number from 0 to 255.${NC}" >&2
            ((attempts++))
        fi
    done

    if [ $attempts -eq $max_attempts ]; then
        echo -e "${BOLD_RED}Maximum number of attempts exceeded. Using default value: $default_value${NC}" >&2
        result="$default_value"
    fi

    echo "$result"
}

# Function for validating and cleaning the port
# Leaves only numeric characters and checks that the value is in the range 1-65535
# Usage:
#   validate_port "8080"
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
            show_info_e "Port $port is available."
            echo "$port"
            return 0
        fi
        ((port++))
        # Limit to 65535 just in case
        if [ "$port" -gt 65535 ]; then
            show_info_e "Failed to find an available port!"
            return 1
        fi
    done
}

# Function for safe port reading with validation
# Usage:
#   read_port "Enter port:" "8080"
#   read_port "Enter port:" "8080" true    # Skip port availability check
read_port() {
    local prompt="$1"
    local default_value="${2:-}"
    local skip_availability_check="${3:-false}"
    local result=""
    local attempts=0
    local max_attempts=3

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
        result=$(validate_port "$result")
        local status=$?

        if [ $status -eq 0 ]; then
            # Check if port is available (if check is not disabled)
            if [ "$skip_availability_check" = true ] || is_port_available "$result"; then
                break
            else
                show_info_e "Port ${result} is already in use."
                prompt_formatted_text="${ORANGE}Do you want to automatically find an available port? [y/N]:${NC}"
                read -p "$prompt_formatted_text" answer
                if [[ "$answer" =~ ^[yY] ]]; then
                    result="$(find_available_port "$result")"
                    break
                else
                    show_info_e "Please choose another port."
                    ((attempts++))
                fi
            fi
        else
            # Display message depending on return code
            case $status in
            1) show_info_e "Invalid input (not a number). Please enter a valid port." ;;
            2) show_info_e "Invalid port. Enter a number from 1 to 65535." ;;
            esac
            ((attempts++))
        fi
    done

    if [ $attempts -eq $max_attempts ]; then
        show_info_e "Maximum number of attempts exceeded. Using default port."
        if [ -n "$default_value" ]; then
            result="$default_value"
            if [ "$skip_availability_check" = false ] && ! is_port_available "$result"; then
                result="$(find_available_port "$result")"
            fi
        else
            # If there is no default value, use a random available port
            local random_start=$((RANDOM % 10000 + 10000))
            result="$(find_available_port "$random_start")"
        fi
    fi

    # Output the result ONCE here
    echo "$result"
}

generate_readable_login() {
    # Consonants and vowels for more readable combinations
    consonants="bcdfghjklmnpqrstvwxz"
    vowels="aeiouy"

    # Random length from 6 to 10 characters
    length=$((6 + RANDOM % 5))

    # Initialize empty string for login
    login=""

    # Generate login, alternating consonants and vowels
    for ((i = 0; i < length; i++)); do
        if ((i % 2 == 0)); then
            # Pick a random consonant
            rand_index=$((RANDOM % ${#consonants}))
            login="${login}${consonants:rand_index:1}"
        else
            # Pick a random vowel
            rand_index=$((RANDOM % ${#vowels}))
            login="${login}${vowels:rand_index:1}"
        fi
    done

    echo "$login"
}

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
generate_vless_config() {
    local config_file="$1"
    local self_steal_domain="$2"
    local self_steal_port="$3"
    local private_key="$4"
    local public_key="$5"

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
          "dest": "127.0.0.1:$self_steal_port",
          "show": false,
          "xver": 1,
          "shortIds": [
            "$short_id"
          ],
          "publicKey": "$public_key",
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

# Function to check if the domain points to the current server
check_domain_points_to_server() {
    local domain="$1"
    local show_warning="${2:-true}"   # Show warning by default
    local allow_cf_proxy="${3:-true}" # Allow Cloudflare proxying by default

    # Get domain's IP
    local domain_ip=""
    domain_ip=$(dig +short A "$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

    # Get public IP of the current server
    local server_ip=""
    server_ip=$(curl -s -4 ifconfig.me || curl -s -4 api.ipify.org || curl -s -4 ipinfo.io/ip)

    # If unable to get IPs, exit
    if [ -z "$domain_ip" ] || [ -z "$server_ip" ]; then
        if [ "$show_warning" = true ]; then
            show_warning "Failed to determine domain or server IP address."
            show_warning "Make sure that the domain $domain is properly configured and points to the server ($server_ip)."
        fi
        return 1
    fi

    # Load current Cloudflare ranges
    local cf_ranges
    cf_ranges=$(curl -s https://www.cloudflare.com/ips-v4) || true # если curl не сработал, переменная останется пустой

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
            return 0
        else
            # Proxying not allowed — warn
            if [ "$show_warning" = true ]; then
                echo ""
                show_warning "Domain $domain points to Cloudflare IP ($domain_ip)."
                show_warning "Disable Cloudflare proxying - selfsteal domain proxying is not allowed."
                if prompt_yes_no "Continue installation despite incorrect domain configuration?" "$ORANGE"; then
                    return 1
                else
                    return 2
                fi
            fi
            return 1
        fi
    else
        # If not Cloudflare, check if domain IP matches server IP
        if [ "$domain_ip" != "$server_ip" ]; then
            if [ "$show_warning" = true ]; then
                echo ""
                show_warning "Domain $domain points to IP address $domain_ip, which differs from the server IP ($server_ip)."
                show_warning "For proper operation, the domain must point to the current server."
                if prompt_yes_no "Continue installation despite incorrect domain configuration?" "$ORANGE"; then
                    return 1
                else
                    return 2
                fi
            fi
            return 1
        fi
    fi

    return 0 # All correct
}
