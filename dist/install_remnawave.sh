#!/bin/bash

# Remnawave Installer 

# Including module: constants.sh

BOLD_BLUE=$(tput setaf 4)
BOLD_GREEN=$(tput setaf 2)
BOLD_YELLOW=$(tput setaf 11)
LIGHT_GREEN=$(tput setaf 10)
BOLD_BLUE_MENU=$(tput setaf 6)
ORANGE=$(tput setaf 3)
BOLD_RED=$(tput setaf 1)
BLUE=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

VERSION="1.5.0b"

REMNAWAVE_DIR="/opt/remnawave"
REMNANODE_ROOT_DIR="/opt/remnanode"
REMNANODE_DIR="/opt/remnanode/node"
SELFSTEAL_DIR="/opt/remnanode/selfsteal"

LOCAL_REMNANODE_DIR="$REMNAWAVE_DIR/node"

# Including module: system.sh


install_dependencies() {
    set -euo pipefail
    IFS=$'\n\t'

    local extra_deps=("$@")
    show_info "Checking dependencies..."

    (sudo apt-get update -y -qq) &
    spinner $! "Updating package list"

    local distro
    distro=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
    local codename
    codename=$(lsb_release -cs)

    if [[ "$distro" != "ubuntu" && "$distro" != "debian" ]]; then
        show_error "Distribution $distro is not supported by this script for Docker CE."
        exit 1
    fi

    if ! grep -Rq '^deb .*\bdocker\.com/linux' /etc/apt/sources.list.d /etc/apt/sources.list 2>/dev/null; then
        (sudo mkdir -p /etc/apt/keyrings &&
            curl -fsSL "https://download.docker.com/linux/${distro}/gpg" |
            sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null &&
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${distro} ${codename} stable" |
            sudo tee /etc/apt/sources.list.d/docker-stable.list >/dev/null &&
            sudo apt-get update -y -qq >/dev/null 2>&1) &
        spinner $! "Adding Docker repository"
    fi

    local base_deps=(curl jq make dnsutils ufw unattended-upgrades
        docker-ce docker-ce-cli containerd.io
        docker-buildx-plugin docker-compose-plugin
        lsb-release)

    local all_deps=()
    for pkg in "${base_deps[@]}" "${extra_deps[@]}"; do
        [[ " ${all_deps[*]} " != *" $pkg "* ]] && all_deps+=("$pkg")
    done

    local missing_deps=()
    for dep in "${all_deps[@]}"; do
        if ! dpkg -s "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        (sudo apt-get install -y --no-install-recommends "${missing_deps[@]}" -qq >/dev/null 2>&1) &
        spinner $! "Installing dependencies (${#missing_deps[@]} packages)"
    fi

    (sudo systemctl enable --now docker >/dev/null 2>&1) &
    spinner $! "Starting Docker service"

    if ! id -nG "$USER" | grep -qw docker; then
        (sudo usermod -aG docker "$USER" >/dev/null 2>&1) &
        spinner $! "Adding user to docker group"
        show_info "User $USER added to docker group."
    fi

    local ssh_port
    ssh_port=$(grep -E "^[[:space:]]*Port[[:space:]]+" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
    [ -z "$ssh_port" ] && ssh_port=22
    (ufw --force reset &&
        ufw allow "${ssh_port}/tcp" comment 'SSH' &&
        ufw allow 443/tcp comment 'HTTPS' &&
        ufw allow 80/tcp comment 'HTTP' &&
        ufw --force enable) >/dev/null 2>&1 &
    spinner $! "Configuring UFW Firewall"

    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true |
        sudo debconf-set-selections
    sudo dpkg-reconfigure -f noninteractive unattended-upgrades

    sudo sed -i '/^Unattended-Upgrade::SyslogEnable/ d' \
        /etc/apt/apt.conf.d/50unattended-upgrades
    echo 'Unattended-Upgrade::SyslogEnable "true";' |
        sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null

    sudo systemctl restart unattended-upgrades

    show_success "All dependencies installed successfully"
}

create_dir() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        show_info "Created directory: $dir_path"
    fi
}

prepare_installation() {
    local extra_deps=("$@")
    clear_screen
    install_dependencies "${extra_deps[@]}"

    if ! remove_previous_installation; then
        show_info "Installation cancelled. Returning to main menu."
        return 1
    fi

    mkdir -p "$REMNAWAVE_DIR/caddy"
    cd "$REMNAWAVE_DIR"
    return 0
}

# Including module: containers.sh


remove_previous_installation() {
    local from_menu=${1:-false} # Optional parameter to indicate if called from menu
    local containers=("remnawave-subscription-page" "remnawave" "remnawave-db" "remnawave-redis" "remnanode" "caddy-remnawave" "caddy-selfsteal")
    local container_exists=false

    for container in "${containers[@]}"; do
        if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$container"; then
            container_exists=true
            break
        fi
    done

    if [ -d "$REMNAWAVE_DIR" ] || [ "$container_exists" = true ]; then
        if [ "$from_menu" = true ]; then
            show_warning "RemnaWave installation detected."
            if prompt_yes_no "Are you sure you want to completely DELETE Remnawave? IT WILL REMOVE ALL DATA!!! Continue?" "$ORANGE"; then
                :
            else
                return 1
            fi
        else
            show_warning "Previous RemnaWave installation detected."
            if prompt_yes_no "To continue, you need to DELETE previous Remnawave installation. IT WILL REMOVE ALL DATA!!! Continue?" "$ORANGE"; then
                :
            else
                return 1
            fi
        fi

        if [ -f "$REMNAWAVE_DIR/caddy/docker-compose.yml" ]; then
            cd $REMNAWAVE_DIR && docker compose -f caddy/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Caddy container"
        fi
        if [ -f "$REMNAWAVE_DIR/subscription-page/docker-compose.yml" ]; then
            cd $REMNAWAVE_DIR && docker compose -f subscription-page/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping remnawave-subscription-page container"
        fi

        if [ -f "$REMNAWAVE_DIR/docker-compose.yml" ]; then
            cd $REMNAWAVE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Remnawave panel containers"
        fi
        if [ -f "$REMNAWAVE_DIR/panel/docker-compose.yml" ]; then
            cd $REMNAWAVE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Remnawave panel containers"
        fi
        if [ -f "$SELFSTEAL_DIR/docker-compose.yml" ]; then
            cd $SELFSTEAL_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Caddy Selfsteal container"
        fi
        if [ -f "$REMNANODE_DIR/docker-compose.yml" ]; then
            cd $REMNANODE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
            spinner $! "Stopping Remnawave node container"
        fi

        for container in "${containers[@]}"; do
            if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
                docker stop "$container" >/dev/null 2>&1 && docker rm "$container" >/dev/null 2>&1 &
                spinner $! "Stopping and removing container $container"
            fi
        done

        docker rmi $(docker images -q) -f >/dev/null 2>&1 &
        spinner $! "Removing Docker images"

        rm -rf $REMNAWAVE_DIR >/dev/null 2>&1 &
        spinner $! "Removing directory $REMNAWAVE_DIR"
        docker volume rm remnawave-db-data remnawave-redis-data remnawave-caddy-ssl-data >/dev/null 2>&1 &
        spinner $! "Removing Docker volumes: remnawave-db-data and remnawave-redis-data and remnawave-caddy-ssl-data"

        if [ "$from_menu" = true ]; then
            show_success "Remnawave has been completely removed from your system. Press any key to continue..."
            read
        else
            show_success "Previous installation removed."
        fi
    elif [ "$from_menu" = true ]; then
        echo
        show_info "No Remnawave installation detected on this system."
        echo -e "${BOLD_GREEN}Press any key to continue...${NC}"
        read
    fi
}

restart_panel() {
    local no_wait=${1:-false} # Optional parameter to skip waiting for user input
    echo ''
    if [ ! -d /opt/remnawave ]; then
        show_error "Error: panel directory not found at /opt/remnawave!"
        show_error "Please install Remnawave panel first."
    else
        if [ ! -f /opt/remnawave/docker-compose.yml ]; then
            show_error "Error: docker-compose.yml not found in panel directory!"
            show_error "Panel installation may be corrupted or incomplete."
        else
            SUBSCRIPTION_PAGE_EXISTS=false

            if [ -d /opt/remnawave/subscription-page ] && [ -f /opt/remnawave/subscription-page/docker-compose.yml ]; then
                SUBSCRIPTION_PAGE_EXISTS=true
            fi

            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd /opt/remnawave/subscription-page && docker compose down >/dev/null 2>&1 &
                spinner $! "Stopping remnawave-subscription-page container"
            fi

            cd /opt/remnawave && docker compose down >/dev/null 2>&1 &
            spinner $! "Restarting panel..."

            show_info "Starting main panel..." "$ORANGE"
            if ! start_container "/opt/remnawave" "Remnawave Panel"; then
                return 1
            fi

            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                show_info "Starting subscription page..." "$ORANGE"
                if ! start_container "/opt/remnawave/subscription-page" "Subscription Page"; then
                    return 1
                fi
            fi

            show_success "Panel restarted successfully"
        fi
    fi
    if [ "$no_wait" != "true" ]; then
        echo -e "${BOLD_GREEN}Press Enter to continue...${NC}"
        read
    fi
}

start_container() {
    local compose_dir="$1" display_name="$2"
    local max_wait=20 poll=1 tmp_log compose_file
    tmp_log=$(mktemp /tmp/docker-stack-XXXX.log)

    if [[ -z "$compose_dir" || -z "$display_name" ]]; then
        printf "${BOLD_RED}Error:${NC} provide directory and display name\n" >&2
        return 2
    fi
    if [[ ! -d "$compose_dir" ]]; then
        printf "${BOLD_RED}Error:${NC} directory “%s” not found\n" "$compose_dir" >&2
        return 2
    fi
    if [[ -f "$compose_dir/docker-compose.yml" ]]; then
        compose_file="$compose_dir/docker-compose.yml"
    elif [[ -f "$compose_dir/docker-compose.yaml" ]]; then
        compose_file="$compose_dir/docker-compose.yaml"
    else
        printf "${BOLD_RED}Error:${NC} docker-compose.yml not found in “%s”\n" "$compose_dir" >&2
        return 2
    fi
    if ! command -v docker >/dev/null 2>&1; then
        printf "${BOLD_RED}Error:${NC} Docker is not installed or not in PATH\n" >&2
        return 2
    fi
    if ! docker info >/dev/null 2>&1; then
        printf "${BOLD_RED}Error:${NC} Docker daemon is not running\n" >&2
        return 2
    fi

    (docker compose -f "$compose_file" up -d --force-recreate) \
        >"$tmp_log" 2>&1 &
    spinner $! "Launching “$display_name”"
    wait $!

    local output
    output=$(<"$tmp_log")

    if echo "$output" | grep -qiE 'toomanyrequests.*rate limit'; then
        printf "${BOLD_RED}✖ Docker Hub rate limit while pulling images for “%s”.${NC}\n" "$display_name" >&2
        printf "${BOLD_YELLOW}Cause:${NC} pull rate limit exceeded.\n" >&2
        echo -e "${ORANGE}Possible solutions:${NC}" >&2
        echo -e "${GREEN}1. Wait ~6 h and retry${NC}" >&2
        echo -e "${GREEN}2. docker login${NC}" >&2
        echo -e "${GREEN}3. Use VPN / other IP${NC}" >&2
        echo -e "${GREEN}4. Set up a mirror${NC}\n" >&2
        rm -f "$tmp_log"
        return 1
    fi

    mapfile -t services < <(docker compose -f "$compose_file" config --services)

    local all_ok=true elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        all_ok=true
        for svc in "${services[@]}"; do
            cid=$(docker compose -f "$compose_file" ps -q "$svc")
            state=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null)
            if [[ "$state" != "running" ]]; then
                all_ok=false
                break
            fi
        done
        $all_ok && break
        sleep $poll
        ((elapsed += poll))
    done

    if $all_ok; then
        printf "${BOLD_GREEN}✔ “%s” is up (services: %s).${NC}\n" \
            "$display_name" "$(
                IFS=,
                echo "${services[*]}"
            )"
        echo
        rm -f "$tmp_log"
        return 0
    fi

    printf "${BOLD_RED}✖ “%s” failed to start entirely.${NC}\n" "$display_name" >&2
    printf "${BOLD_RED}→ docker compose output:${NC}\n" >&2
    cat "$tmp_log" >&2
    printf "\n${BOLD_RED}→ Problematic services status:${NC}\n" >&2
    docker compose -f "$compose_file" ps >&2
    rm -f "$tmp_log"
    return 1
}

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

start_services() {
    echo
    show_info "Starting containers..." "$BOLD_GREEN"

    if ! start_container "$REMNAWAVE_DIR" "Remnawave/backend"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi

    if ! start_container "$REMNAWAVE_DIR/subscription-page" "Subscription page"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi
}

# Including module: display.sh


draw_info_box() {
    local title="$1"
    local subtitle="$2"

    local width=54

    echo -e "${BOLD_GREEN}"
    printf "┌%s┐\n" "$(printf '─%.0s' $(seq 1 $width))"

    local title_padding_left=$(((width - ${#title}) / 2))
    local title_padding_right=$((width - title_padding_left - ${#title}))
    printf "│%*s%s%*s│\n" "$title_padding_left" "" "$title" "$title_padding_right" ""

    local subtitle_padding_left=$(((width - ${#subtitle}) / 2))
    local subtitle_padding_right=$((width - subtitle_padding_left - ${#subtitle}))
    printf "│%*s%s%*s│\n" "$subtitle_padding_left" "" "$subtitle" "$subtitle_padding_right" ""

    printf "│%*s│\n" "$width" ""

    local version_text="  • Version: "
    local version_value="$VERSION"
    local version_value_colored="${ORANGE}${version_value}${BOLD_GREEN}"
    local version_value_length=${#version_value}
    local remaining_space=$((width - ${#version_text} - version_value_length))
    printf "│%s%s%*s│\n" "$version_text" "$version_value_colored" "$remaining_space" ""

    printf "│%*s│\n" "$width" ""

    printf "└%s┘\n" "$(printf '─%.0s' $(seq 1 $width))"
    echo -e "${NC}"
}

clear_screen() {
    clear
}

draw_section_header() {
    local title="$1"
    local width=${2:-50}

    echo -e "${BOLD_RED}\033[1m┌$(printf '─%.0s' $(seq 1 $width))┐\033[0m${NC}"

    local padding_left=$(((width - ${#title}) / 2))
    local padding_right=$((width - padding_left - ${#title}))
    echo -e "${BOLD_RED}\033[1m│$(printf ' %.0s' $(seq 1 $padding_left))$title$(printf ' %.0s' $(seq 1 $padding_right))│\033[0m${NC}"

    echo -e "${BOLD_RED}\033[1m└$(printf '─%.0s' $(seq 1 $width))┘\033[0m${NC}"
    echo
}

draw_menu_options() {
    local options=("$@")
    local idx=1

    for option in "${options[@]}"; do
        echo -e "${ORANGE}$idx. $option${NC}"
        ((idx++))
    done
    echo
}

show_success() {
    local message="$1"
    local output_fd="${2:-1}" # Default to stdout (1)
    echo -e "${BOLD_GREEN}✓ ${message}${NC}" >&$output_fd
    echo >&$output_fd
}

show_error() {
    local message="$1"
    local output_fd="${2:-2}" # Default to stderr (2)
    echo -e "${BOLD_RED}✗ ${message}${NC}" >&$output_fd
    echo >&$output_fd
}

show_warning() {
    local message="$1"
    local output_fd="${2:-2}" # Default to stderr (2)
    echo -e "${BOLD_YELLOW}⚠  ${message}${NC}" >&$output_fd
    echo >&$output_fd
}

show_info() {
    local message="$1"
    local color="${2:-$ORANGE}"
    local output_fd="${3:-2}" # Default to stderr (2)
    echo -e "${color}${message}${NC}" >&$output_fd
    echo >&$output_fd
}

draw_separator() {
    local width=${1:-50}
    local char=${2:-"-"}

    printf "%s\n" "$(printf "$char%.0s" $(seq 1 $width))"
}

show_progress() {
    local message="$1"
    local progress_char=${2:-"."}
    local count=${3:-3}

    echo -ne "${message}"
    for ((i = 0; i < count; i++)); do
        echo -ne "${progress_char}"
        sleep 0.5
    done
    echo
}

draw_info_row() {
    local label="$1"
    local value="$2"
    local label_color="${3:-$ORANGE}"
    local value_color="${4:-$GREEN}"
    local width=${5:-50}

    local label_display="${label_color}${label}:${NC}"
    local value_display="${value_color}${value}${NC}"

    echo -e "${label_display} ${value_display}"
}

center_text() {
    local text="$1"
    local width=${2:-$(tput cols)}
    local padding_left=$(((width - ${#text}) / 2))

    printf "%${padding_left}s%s\n" "" "$text"
}

draw_completion_message() {
    local title="$1"
    local message="$2"
    local width=${3:-70}

    draw_separator "$width" "="
    center_text "$title" "$width"
    echo
    echo -e "$message"
    draw_separator "$width" "="
}

spinner() {
    local pid=$1
    local text=$2
    local spinstr='⣷⣯⣟⡿⢿⣻⣽⣾'
    local text_code="$BOLD_GREEN"
    local bg_code=""
    local effect_code="\033[1m"
    local delay=0.12
    local reset_code="$NC"

    printf "${effect_code}${text_code}${bg_code}%s${reset_code}" "$text" >/dev/tty

    while kill -0 "$pid" 2>/dev/null; do
        for ((i = 0; i < ${#spinstr}; i++)); do
            printf "\r${effect_code}${text_code}${bg_code}[%s] %s${reset_code}" "$(echo -n "${spinstr:$i:1}")" "$text" >/dev/tty
            sleep $delay
        done
    done

    printf "\r\033[K" >/dev/tty
}

# Including module: input.sh


prompt_input() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"

    echo -ne "${prompt_color}${prompt_text}${NC}" >&2
    read input_value
    echo >&2

    echo "$input_value"
}

prompt_password() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"

    echo -ne "${prompt_color}${prompt_text}${NC}" >&2
    stty -echo
    read password_value
    stty echo
    echo >&2

    echo "$password_value"
}

prompt_yes_no() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"
    local default="${3:-}"

    local prompt_suffix=" (y/n): "
    [ -n "$default" ] && prompt_suffix=" (y/n) [$default]: "

    while true; do
        echo -ne "${prompt_color}${prompt_text}${prompt_suffix}${NC}" >&2

        while read -t 0.1; do read -n 1; done

        read answer
        echo >&2

        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

        [ -z "$answer" ] && answer="$default"

        if [ "$answer" = "y" ] || [ "$answer" = "yes" ]; then
            return 0
        elif [ "$answer" = "n" ] || [ "$answer" = "no" ]; then
            return 1
        else
            echo -e "${BOLD_RED}Please enter 'y' or 'n'.${NC}" >&2
            echo ''
        fi
    done
}

prompt_menu_option() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"
    local min="${3:-1}"
    local max="$4"

    local selected_option
    while true; do
        echo -ne "${prompt_color}${prompt_text} (${min}-${max}): ${NC}" >&2
        read selected_option
        echo >&2

        if [[ "$selected_option" =~ ^[0-9]+$ ]] &&
            [ "$selected_option" -ge "$min" ] &&
            [ "$selected_option" -le "$max" ]; then
            break
        else
            echo -e "${BOLD_RED}Plfease enter a number between ${min} and ${max}.${NC}" >&2
        fi
    done

    echo "$selected_option"
}

validate_password_strength() {
    local password="$1"
    local min_length=${2:-8}

    local length=${#password}

    if [ "$length" -lt "$min_length" ]; then
        echo "Password must contain at least $min_length characters."
        return 1
    fi

    if ! [[ "$password" =~ [0-9] ]]; then
        echo "Password must contain at least one digit."
        return 1
    fi

    if ! [[ "$password" =~ [a-z] ]]; then
        echo "Password must contain at least one lowercase letter."
        return 1
    fi

    if ! [[ "$password" =~ [A-Z] ]]; then
        echo "Password must contain at least one uppercase letter."
        return 1
    fi

    return 0
}

prompt_secure_password() {
    local prompt_text="$1"
    local confirm_text="${2:-Please confirm your password}"
    local min_length=${3:-8}

    local password1 password2 error_message

    while true; do
        password1=$(prompt_password "$prompt_text")

        error_message=$(validate_password_strength "$password1" "$min_length")
        if [ $? -ne 0 ]; then
            echo -e "${BOLD_RED}${error_message} Please try again.${NC}" >&2
            continue
        fi

        password2=$(prompt_password "$confirm_text")

        if [ "$password1" = "$password2" ]; then
            break
        else
            echo -e "${BOLD_RED}Passwords do not match. Please try again.${NC}" >&2
        fi
    done

    echo "$password1"
}

# Including module: network.sh


validate_port() {
    local port="$1"

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo -e "${BOLD_RED}Error: Port must be a number.${NC}" >&2
        return 1
    fi

    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${BOLD_RED}Error: Port must be between 1 and 65535.${NC}" >&2
        return 1
    fi

    echo "$port"
}

is_port_available() {
    local port="$1"

    if ss -tuln | grep -q ":$port "; then
        return 1 # Port is in use
    else
        return 0 # Port is available
    fi
}

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

is_ip_in_cidrs() {
    local ip="$1"
    shift
    local cidrs=("$@")

    function ip2dec() {
        local a b c d
        IFS=. read -r a b c d <<<"$1"
        echo $(((a << 24) + (b << 16) + (c << 8) + d))
    }

    function in_cidr() {
        local ip_dec mask base_ip cidr_ip cidr_mask
        ip_dec=$(ip2dec "$1")
        base_ip="${2%/*}"
        mask="${2#*/}"

        cidr_ip=$(ip2dec "$base_ip")
        cidr_mask=$((0xFFFFFFFF << (32 - mask) & 0xFFFFFFFF))

        if (((ip_dec & cidr_mask) == (cidr_ip & cidr_mask))); then
            return 0
        else
            return 1
        fi
    }

    for range in "${cidrs[@]}"; do
        if in_cidr "$ip" "$range"; then
            return 0
        fi
    done

    return 1
}

prompt_email() {
    local prompt="$1"
    local result=""

    while true; do
        prompt_formatted_text="${ORANGE}${prompt}: ${NC}"
        read -p "$prompt_formatted_text" result

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

get_available_port() {
    local default_port="$1"
    local port_name="$2" # For display purposes only

    local port=$(validate_port "$default_port")

    if is_port_available "$port"; then
        show_info "Using default $port_name port: $port"
        echo "$port"
        return 0
    else
        show_info "Default $port_name port $port is already in use. Finding available port..."
        local available_port=$(find_available_port "$((port + 1))")

        if [ $? -eq 0 ]; then
            show_info "Using $port_name port: $available_port"
            echo "$available_port"
            return 0
        else
            show_error "Failed to find an available port for $port_name!"
            echo "$default_port"
            return 1
        fi
    fi
}

check_required_port() {
    local required_port="$1"

    local port=$(validate_port "$required_port")

    if is_port_available "$port"; then
        echo "$port"
        return 0
    else
        return 1
    fi
}

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

        if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            echo -e "${BOLD_RED}Invalid domain format. Please try again.${NC}" >&2
            continue
        fi

        local domain_ip=""
        domain_ip=$(dig +short A "$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

        local server_ip=""
        server_ip=$(curl -s -4 ifconfig.me || curl -s -4 api.ipify.org || curl -s -4 ipinfo.io/ip)

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

        local cf_ranges
        cf_ranges=$(curl -s https://www.cloudflare.com/ips-v4) || true # if curl fails, variable remains empty

        local cf_array=()
        if [ -n "$cf_ranges" ]; then
            IFS=$'\n' read -r -d '' -a cf_array <<<"$cf_ranges"
        fi

        if [ ${#cf_array[@]} -gt 0 ] && is_ip_in_cidrs "$domain_ip" "${cf_array[@]}"; then
            if [ "$allow_cf_proxy" = true ]; then
                break
            else
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
            if [ "$expect_different_ip" = "true" ]; then
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
                    if [ "$show_warning" = true ]; then
                        :
                    fi
                    break
                fi
            else
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

# Including module: crypto.sh


generate_secure_password() {
    local length="${1:-16}"
    local password=""
    local special_chars='!%^&*_+.,'
    local uppercase_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local lowercase_chars='abcdefghijklmnopqrstuvwxyz'
    local number_chars='0123456789'
    local alphanumeric_chars="${uppercase_chars}${lowercase_chars}${number_chars}"

    if command -v openssl &>/dev/null; then
        password="$(openssl rand -base64 48 | tr -dc "$alphanumeric_chars" | head -c "$length")"
    else
        password="$(head -c 100 /dev/urandom | tr -dc "$alphanumeric_chars" | head -c "$length")"
    fi

    if ! [[ "$password" =~ [$uppercase_chars] ]]; then
        local position=$((RANDOM % length))
        local one_uppercase="$(echo "$uppercase_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_uppercase}${password:$((position + 1))}"
    fi

    if ! [[ "$password" =~ [$lowercase_chars] ]]; then
        local position=$((RANDOM % length))
        local one_lowercase="$(echo "$lowercase_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_lowercase}${password:$((position + 1))}"
    fi

    if ! [[ "$password" =~ [$number_chars] ]]; then
        local position=$((RANDOM % length))
        local one_number="$(echo "$number_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_number}${password:$((position + 1))}"
    fi

    local special_count=$((length / 4))
    special_count=$((special_count > 0 ? special_count : 1))
    special_count=$((special_count < 3 ? special_count : 3))

    for ((i = 0; i < special_count; i++)); do
        local position=$((RANDOM % (length - 2) + 1))
        local one_special="$(echo "$special_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_special}${password:$((position + 1))}"
    done

    echo "$password"
}

generate_readable_login() {
    local length="${1:-8}"
    local consonants=('b' 'c' 'd' 'f' 'g' 'h' 'j' 'k' 'l' 'm' 'n' 'p' 'r' 's' 't' 'v' 'w' 'x' 'z')
    local vowels=('a' 'e' 'i' 'o' 'u' 'y')
    local login=""
    local type="consonant"

    while [ ${#login} -lt $length ]; do
        if [ "$type" = "consonant" ]; then
            login+=${consonants[$RANDOM % ${#consonants[@]}]}
            type="vowel"
        else
            login+=${vowels[$RANDOM % ${#vowels[@]}]}
            type="consonant"
        fi
    done

    local add_number=$((RANDOM % 2))
    if [ $add_number -eq 1 ]; then
        login+=$((RANDOM % 100))
    fi

    echo "$login"
}

generate_nonce() {
    local length="${1:-64}"
    local nonce=""
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    while [ ${#nonce} -lt $length ]; do
        nonce+="${chars:$((RANDOM % ${#chars})):1}"
    done

    echo "$nonce"
}

generate_custom_path() {
    local length="${1:-36}"
    local path=""
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"

    while [ ${#path} -lt $length ]; do
        path+="${chars:$((RANDOM % ${#chars})):1}"
    done

    echo "$path"
}

generate_secrets() {
    JWT_AUTH_SECRET=$(openssl rand -hex 32 | tr -d '\n')
    JWT_API_TOKENS_SECRET=$(openssl rand -hex 32 | tr -d '\n')
    DB_USER="remnawave_$(openssl rand -hex 4 | tr -d '\n')"
    DB_PASSWORD=$(generate_secure_password 16)
    DB_NAME="remnawave_db"
    METRICS_PASS=$(generate_secure_password 16)
    SUPERADMIN_USERNAME=$(generate_readable_login)
    SUPERADMIN_PASSWORD=$(generate_secure_password 28)
}

# Including module: http.sh


make_api_request() {
    local method=$1
    local url=$2
    local token=$3
    local panel_domain=$4
    local data=$5
    local cookie=${6:-""}

    local host_only=$(echo "${url#http://}" | cut -d'/' -f1)

    local headers=(
        -H "Content-Type: application/json"
        -H "Host: $panel_domain"
        -H "X-Forwarded-For: $host_only"
        -H "X-Forwarded-Proto: https"
    )

    if [ -n "$token" ]; then
        headers+=(-H "Authorization: Bearer $token")
    fi

    if [ -n "$cookie" ]; then
        headers+=(-H "Cookie: $cookie")
    fi

    if [ "$method" = "GET" ]; then
        curl -s -X "$method" "$url" "${headers[@]}"
    else
        if [ -n "$data" ]; then
            curl -s -X "$method" "$url" "${headers[@]}" -d "$data"
        else
            curl -s -X "$method" "$url" "${headers[@]}"
        fi
    fi
}

# Including module: remnawave-api.sh


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
                reg_error="Empty server response"
            elif [[ "$response" == *"accessToken"* ]]; then
                reg_token=$(echo "$response" | jq -r '.response.accessToken')
                echo "$reg_token" >"$temp_result"
                exit 0
            else
                reg_error="$response"
            fi
            sleep 1
        done
        echo "${reg_error:-Registration failed: unknown error}" >"$temp_result"
        exit 1
    } &

    local pid=$!

    spinner "$pid" "Registering user $username..."

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

    echo "$pubkey"
}

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

get_inbounds() {
    local panel_url="$1"
    local token="$2"
    local panel_domain="$3"

    local temp_file=$(mktemp)

    make_api_request "GET" "http://$panel_url/api/inbounds" "$token" "$panel_domain" "" >"$temp_file" 2>&1 &
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

    echo "$inbound_uuid"
}

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

    spinner $! "Creating user: $username..."

    local full_response=$(cat "$temp_file")
    local status_code="${full_response: -3}"   # Last 3 characters
    local user_response="${full_response%???}" # Everything except last 3 characters

    rm -f "$temp_file" "$temp_headers"

    if [ -z "$user_response" ]; then
        echo -e "${BOLD_RED}Error: Empty response from server when creating user.${NC}"
        return 1
    fi

    if [ "$status_code" != "201" ]; then
        echo -e "${BOLD_RED}Error: Failed to create user. HTTP status: $status_code${NC}"
        echo
        echo "Request body was:"
        echo "$user_data"
        echo
        echo "Response:"
        echo "$user_response"
        return 1
    fi

    if echo "$user_response" | jq -e '.response.uuid' >/dev/null; then
        USER_UUID=$(echo "$user_response" | jq -r '.response.uuid')
        USER_SHORT_UUID=$(echo "$user_response" | jq -r '.response.shortUuid')
        USER_SUBSCRIPTION_UUID=$(echo "$user_response" | jq -r '.response.subscriptionUuid')
        USER_VLESS_UUID=$(echo "$user_response" | jq -r '.response.vlessUuid')
        USER_TROJAN_PASSWORD=$(echo "$user_response" | jq -r '.response.trojanPassword')
        USER_SS_PASSWORD=$(echo "$user_response" | jq -r '.response.ssPassword')
        USER_SUBSCRIPTION_URL=$(echo "$user_response" | jq -r '.response.subscriptionUrl')

        return 0
    else
        echo -e "${BOLD_RED}Error: Failed to create user, invalid response format:${NC}"
        echo
        echo "Request body was:"
        echo "$user_data"
        echo
        echo "Response:"
        echo "$user_response"
        return 1
    fi
}

register_panel_user() {
    REG_TOKEN=$(register_user "127.0.0.1:3000" "$PANEL_DOMAIN" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -z "$REG_TOKEN" ]; then
        show_error "Failed to register user."
        exit 1
    fi
}

# Including module: config.sh


update_file() {
    local env_file="$1"
    shift

    if [ "$#" -eq 0 ] || [ $(($# % 2)) -ne 0 ]; then
        echo "Error: invalid number of arguments. Should be even number of keys and values." >&2
        return 1
    fi

    local keys=()
    local values=()

    while [ "$#" -gt 0 ]; do
        keys+=("$1")
        values+=("$2")
        shift 2
    done

    local temp_file=$(mktemp)

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

    mv "$temp_file" "$env_file"
}

collect_telegram_config() {
    if prompt_yes_no "Do you want to enable Telegram notifications?"; then
        IS_TELEGRAM_NOTIFICATIONS_ENABLED=true
        TELEGRAM_BOT_TOKEN=$(prompt_input "Enter your Telegram bot token: " "$ORANGE")
        TELEGRAM_NOTIFY_USERS_CHAT_ID=$(prompt_input "Enter the users chat ID: " "$ORANGE")
        TELEGRAM_NOTIFY_NODES_CHAT_ID=$(prompt_input "Enter the nodes chat ID: " "$ORANGE")

        if prompt_yes_no "Do you want to use Telegram topics?"; then
            TELEGRAM_NOTIFY_USERS_THREAD_ID=$(prompt_input "Enter the users thread ID: " "$ORANGE")
            TELEGRAM_NOTIFY_NODES_THREAD_ID=$(prompt_input "Enter the nodes thread ID: " "$ORANGE")
        fi
    else
        show_warning "Skipping Telegram integration."
        IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
        TELEGRAM_BOT_TOKEN="change-me"
        TELEGRAM_NOTIFY_USERS_CHAT_ID="change-me"
        TELEGRAM_NOTIFY_NODES_CHAT_ID="change-me"
        TELEGRAM_NOTIFY_USERS_THREAD_ID=""
        TELEGRAM_NOTIFY_NODES_THREAD_ID=""
    fi
}

check_domain_uniqueness() {
    local new_domain="$1"
    local domain_type="$2"
    local existing_domains=("${@:3}")

    for existing_domain in "${existing_domains[@]}"; do
        if [ -n "$existing_domain" ] && [ "$new_domain" = "$existing_domain" ]; then
            show_error "Domain '$new_domain' is already used for another service!"
            show_error "Each domain must be unique: panel domain, subscription domain, and selfsteal domain must all be different."
            return 1
        fi
    done
    return 0
}

collect_domain_config() {
    PANEL_DOMAIN=$(prompt_domain "Enter the main domain for your panel (e.g., panel.example.com)")

    while true; do
        SUB_DOMAIN=$(prompt_domain "Enter the subscription domain (e.g., sub.example.com)")

        if check_domain_uniqueness "$SUB_DOMAIN" "subscription" "$PANEL_DOMAIN"; then
            break
        fi
        show_warning "Please enter a different subscription domain."
    done
}

collect_ports_all_in_one() {
    CADDY_LOCAL_PORT=$(get_available_port "9443" "Caddy")
    NODE_PORT=$(get_available_port "2222" "Node API")
}

collect_ports_separate_installation() {

    if CADDY_LOCAL_PORT=$(check_required_port "9443"); then
        show_info "Required Caddy port 9443 is available"
    else
        show_error "Required Caddy port 9443 is already in use!"
        show_error "For separate panel and node installation, port 9443 must be available."
        show_error "Please free up port 9443 and try again."
        show_error "Installation cannot continue with occupied port 9443"
        return 1
    fi

    if NODE_PORT=$(check_required_port "2222"); then
        show_info "Required Node API port 2222 is available"
    else
        show_error "Required Node API port 2222 is already in use!"
        show_error "For separate panel and node installation, port 2222 must be available."
        show_error "Please free up port 2222 and try again."
        show_error "Installation cannot continue with occupied port 2222"
        return 1
    fi
}

setup_panel_environment() {
    curl -s -o .env https://raw.githubusercontent.com/remnawave/backend/refs/heads/dev/.env.sample

    update_file ".env" \
        "JWT_AUTH_SECRET" "$JWT_AUTH_SECRET" \
        "JWT_API_TOKENS_SECRET" "$JWT_API_TOKENS_SECRET" \
        "IS_TELEGRAM_NOTIFICATIONS_ENABLED" "$IS_TELEGRAM_NOTIFICATIONS_ENABLED" \
        "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN" \
        "TELEGRAM_NOTIFY_USERS_CHAT_ID" "$TELEGRAM_NOTIFY_USERS_CHAT_ID" \
        "TELEGRAM_NOTIFY_NODES_CHAT_ID" "$TELEGRAM_NOTIFY_NODES_CHAT_ID" \
        "TELEGRAM_NOTIFY_USERS_THREAD_ID" "$TELEGRAM_NOTIFY_USERS_THREAD_ID" \
        "TELEGRAM_NOTIFY_NODES_THREAD_ID" "$TELEGRAM_NOTIFY_NODES_THREAD_ID" \
        "SUB_PUBLIC_DOMAIN" "$SUB_DOMAIN" \
        "DATABASE_URL" "postgresql://$DB_USER:$DB_PASSWORD@remnawave-db:5432/$DB_NAME" \
        "POSTGRES_USER" "$DB_USER" \
        "POSTGRES_PASSWORD" "$DB_PASSWORD" \
        "POSTGRES_DB" "$DB_NAME" \
        "METRICS_PASS" "$METRICS_PASS"
}

setup_panel_docker_compose() {
    cat >>docker-compose.yml <<"EOF"
services:
  remnawave-db:
    image: postgres:17
    container_name: 'remnawave-db'
    hostname: remnawave-db
    restart: always
    env_file:
      - .env
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - TZ=UTC
    ports:
      - '127.0.0.1:6767:5432'
    volumes:
      - remnawave-db-data:/var/lib/postgresql/data
    networks:
      - remnawave-network
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}']
      interval: 3s
      timeout: 10s
      retries: 3

  remnawave:
    image: remnawave/backend:dev
    container_name: 'remnawave'
    hostname: remnawave
    restart: always
    ports:
      - '127.0.0.1:3000:3000'
    env_file:
      - .env
    networks:
      - remnawave-network
    depends_on:
      remnawave-db:
        condition: service_healthy
      remnawave-redis:
        condition: service_healthy

  remnawave-redis:
    image: valkey/valkey:8.0.2-alpine
    container_name: remnawave-redis
    hostname: remnawave-redis
    restart: always
    networks:
      - remnawave-network
    volumes:
      - remnawave-redis-data:/data
    healthcheck:
      test: [ "CMD", "valkey-cli", "ping" ]
      interval: 3s
      timeout: 10s
      retries: 3

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16
    external: false

volumes:
  remnawave-db-data:
    driver: local
    external: false
    name: remnawave-db-data
  remnawave-redis-data:
    driver: local
    external: false
    name: remnawave-redis-data
EOF
}

# Including module: validation.sh


validate_ip() {
    local input="$1"

    input=$(echo "$input" | tr -d ' ')

    if [ -z "$input" ]; then
        return 1
    fi

    if [[ $input =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
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

validate_domain_name() {
    local input="$1"
    local max_length="${2:-253}" # Maximum domain length by standard

    input=$(echo "$input" | tr -d ' ')

    if [ -z "$input" ]; then
        return 1
    fi

    if [ ${#input} -gt $max_length ]; then
        return 1
    fi

    if [[ $input =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$ ]] &&
        [[ ! $input =~ \.\. ]]; then
        echo "$input"
        return 0
    fi

    return 1
}

validate_domain() {
    local input="$1"
    local max_length="${2:-253}"

    local result=$(validate_ip "$input")
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    result=$(validate_domain_name "$input" "$max_length")
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    return 1
}

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

validate_ssl_certificate() {
    local certificate="$1"

    if [ -z "$certificate" ]; then
        return 1
    fi

    if [[ ! "$certificate" =~ ^SSL_CERT= ]]; then
        return 1
    fi

    local cert_value="${certificate#SSL_CERT=}"

    cert_value="${cert_value#\"}"
    cert_value="${cert_value%\"}"

    if [ -z "$cert_value" ]; then
        return 1
    fi

    if ! echo "$cert_value" | base64 -d >/dev/null 2>&1; then
        return 1
    fi

    local decoded_json
    if ! decoded_json=$(echo "$cert_value" | base64 -d 2>/dev/null); then
        return 1
    fi

    if ! echo "$decoded_json" | jq -e '.nodeCertPem and .nodeKeyPem and .caCertPem and .jwtPublicKey' >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

simple_read_domain_or_ip() {
    local prompt="$1"
    local default_value="$2"
    local validation_type="${3:-both}" # Can be 'domain_only', 'ip_only', or 'both'
    local result=""
    local attempts=0
    local max_attempts=10

    while [ $attempts -lt $max_attempts ]; do
        local prompt_formatted_text=""
        if [ -n "$default_value" ]; then
            prompt_formatted_text="${ORANGE}${prompt} [$default_value]:${NC}"
        else
            prompt_formatted_text="${ORANGE}${prompt}:${NC}"
        fi

        read -p "$prompt_formatted_text" input

        if [ -z "$input" ] && [ -n "$default_value" ]; then
            result="$default_value"
            break
        fi

        if [ -z "$input" ]; then
            echo -e "${BOLD_RED}Input cannot be empty. Please enter a valid domain or IP address.${NC}" >&2
            ((attempts++))
            continue
        fi

        if [ "$validation_type" = "ip_only" ]; then
            result=$(validate_ip "$input")
            local status=$?

            if [ $status -eq 0 ]; then
                break
            else
                echo -e "${BOLD_RED}Invalid IP address format. IP must be in format X.X.X.X, where X is a number from 0 to 255.${NC}" >&2
            fi
        elif [ "$validation_type" = "domain_only" ]; then
            result=$(validate_domain_name "$input")
            local status=$?

            if [ $status -eq 0 ]; then
                break
            else
                echo -e "${BOLD_RED}Invalid domain name format. Domain must contain at least one dot and not start/end with dot or dash.${NC}" >&2
                echo -e "${BOLD_RED}Use only letters, digits, dots, and dashes.${NC}" >&2
            fi
        else
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
        if [ -n "$default_value" ]; then
            echo -e "${BOLD_RED}Maximum number of attempts exceeded. Using default value: $default_value${NC}" >&2
            result="$default_value"
        else
            echo -e "${BOLD_RED}Maximum number of attempts exceeded. No valid input provided.${NC}" >&2
            echo -e "${BOLD_RED}Installation cannot continue without a valid domain or IP address.${NC}" >&2
            return 1
        fi
    fi

    echo >&2
    echo "$result"
}

# Including module: misc.sh


generate_qr_code() {
    local url="$1"
    local title="${2:-QR Code}"

    if [ -z "$url" ]; then
        return 1
    fi

    if command -v qrencode &>/dev/null; then
        echo -e "\033[1m$title:\033[0m"
        echo

        local qr_output=$(qrencode -t ANSIUTF8 "$url" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$qr_output" ]; then
            echo "$qr_output" | while IFS= read -r line; do
                printf "    %s\n" "$line"
            done
        else
            echo "QR code generation failed"
        fi
        echo
    else
        :
    fi
}

# Including module: vless.sh


generate_vless_keys() {
  local temp_file=$(mktemp)

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

  echo "$private_key:$public_key"
}

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

# Including module: delete-admin.sh

delete_admin() {
    clear
    local env_file="/opt/remnawave/.env"

    if [ -f "$env_file" ]; then
        POSTGRES_USER=$(grep -oP '^POSTGRES_USER=\K.*' "$env_file")
        POSTGRES_PASSWORD=$(grep -oP '^POSTGRES_PASSWORD=\K.*' "$env_file")
        POSTGRES_DB=$(grep -oP '^POSTGRES_DB=\K.*' "$env_file")
    else
        echo -e "${RED}.env file not found at path $env_file${NC}"
        echo -e "${RED}Trying default database credentials${NC}"
        POSTGRES_USER="postgres"
        POSTGRES_PASSWORD="postgres"
        POSTGRES_DB="postgres"
    fi

    local CONTAINER_NAME="remnawave-db"
    local TABLE_NAME="admin"

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${RED}Container $CONTAINER_NAME is not running!${NC}"
        echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
        read -r
        return 1
    fi

    echo -e "${YELLOW}You are about to delete the superadmin record from table $TABLE_NAME${NC}"
    echo
    read -p "Continue? (y/yes): " CONFIRM

    if [[ "${CONFIRM,,}" != "y" && "${CONFIRM,,}" != "yes" ]]; then
        echo
        echo -e "${YELLOW}Operation cancelled${NC}"
        echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
        read -r
        return 0
    fi

    local SQL_QUERY="DELETE FROM $TABLE_NAME WHERE ctid IN (SELECT ctid FROM $TABLE_NAME LIMIT 1);"

    echo
    echo "Deleting superadmin from table $TABLE_NAME..."
    local RESULT=$(docker exec $CONTAINER_NAME psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$SQL_QUERY")

    if [[ $? -eq 0 ]]; then
        if [[ $RESULT == *"DELETE 0"* ]]; then
            echo
            echo -e "${YELLOW}No superadmin records found in table $TABLE_NAME${NC}"
        else
            echo -e "${GREEN}Record successfully deleted${NC}"
        fi
    else
        echo
        echo -e "${RED}Error deleting record${NC}"
    fi

    echo
    echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Including module: enable-bbr.sh

enable_bbr() {
  if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf && grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo
    show_warning "BBR already added to /etc/sysctl.conf"
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    local current_qdisc=$(sysctl -n net.core.default_qdisc)
    if [[ "$current_cc" == "bbr" && "$current_qdisc" == "fq" ]]; then
      show_info "BBR is active and working"
    else
      show_info "BBR is configured in configuration, but not active. Applying settings..."
      sysctl -p
    fi
    show_info "Press Enter to continue"
    read -r
  else
    echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
    sysctl -p
    show_info "BBR successfully enabled. Press Enter to continue"
    read -r
  fi
}

# Including module: show-credentials.sh

show_panel_credentials() {
    clear
    draw_info_box "Panel Access Credentials" "Remnawave Panel Login Information"
    
    local credentials_file="/opt/remnawave/credentials.txt"
    
    if [ -f "$credentials_file" ]; then
        echo -e "${BOLD_GREEN}Panel access credentials found:${NC}"
        echo
        echo -e "${BOLD_BLUE_MENU}═══ CREDENTIALS ═══${NC}"
        echo
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*$ ]]; then
                echo
            elif [[ "$line" =~ ^[[:space:]]*#.*$ ]] || [[ "$line" =~ ^[[:space:]]*\[.*\][[:space:]]*$ ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ "$line" =~ .*:.*$ ]]; then
                local key=$(echo "$line" | cut -d':' -f1)
                local value=$(echo "$line" | cut -d':' -f2-)
                echo -e "${ORANGE}$key:${GREEN}$value${NC}"
            else
                echo -e "${NC}$line"
            fi
        done < "$credentials_file"
        
        echo
        echo -e "${BOLD_BLUE_MENU}═══════════════════${NC}"
    else
        echo -e "${BOLD_RED}Credentials file not found!${NC}"
        echo
        echo -e "${YELLOW}The credentials file does not exist at: ${ORANGE}$credentials_file${NC}"
        echo
        echo -e "${YELLOW}This usually means:${NC}"
        echo -e "  • Panel is not installed yet"
        echo -e "  • Installation was not completed successfully"
        echo -e "  • Credentials file was manually deleted"
        echo
        echo -e "${YELLOW}Try installing the panel first using options 1, 2, 4, or 5 from the main menu.${NC}"
    fi
    
    echo
    echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Including module: full-auth.sh


collect_full_auth_config() {
    AUTHP_ADMIN_EMAIL=$(prompt_email "Enter the admin email for Caddy Auth")
}

generate_full_auth_secrets() {
    CUSTOM_LOGIN_ROUTE=$(generate_custom_path)
    AUTHP_ADMIN_USER=$(generate_readable_login)
    AUTHP_ADMIN_SECRET=$(generate_secure_password 25)
}

start_caddy_full_auth() {
    if ! start_container "$REMNAWAVE_DIR/caddy" "Caddy"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi
}

save_credentials_full_auth() {
    CREDENTIALS_FILE="$REMNAWAVE_DIR/credentials.txt"
    echo "PANEL URL: https://$PANEL_DOMAIN/$CUSTOM_LOGIN_ROUTE" >>"$CREDENTIALS_FILE"
    echo >>"$CREDENTIALS_FILE"
    echo "REMNAWAVE ADMIN USERNAME: $SUPERADMIN_USERNAME" >>"$CREDENTIALS_FILE"
    echo "REMNAWAVE ADMIN PASSWORD: $SUPERADMIN_PASSWORD" >>"$CREDENTIALS_FILE"
    echo >>"$CREDENTIALS_FILE"
    echo "CADDY AUTH USERNAME: $AUTHP_ADMIN_USER" >>"$CREDENTIALS_FILE"
    echo "CADDY AUTH PASSWORD: $AUTHP_ADMIN_SECRET" >>"$CREDENTIALS_FILE"
    echo "CADDY AUTH EMAIL: $AUTHP_ADMIN_EMAIL" >>"$CREDENTIALS_FILE"
    echo >>"$CREDENTIALS_FILE"

    chmod 600 "$CREDENTIALS_FILE"
}

display_full_auth_results() {
    local installation_type="${1:-panel}"
    local caddy_auth_url="https://$PANEL_DOMAIN/$CUSTOM_LOGIN_ROUTE/auth"

    local max_width=${#caddy_auth_url}
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

    print_text_line "Auth Portal page:"
    print_text_line "$caddy_auth_url"
    print_empty_line

    if [ "$installation_type" = "all-in-one" ] && [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$USER_SUBSCRIPTION_URL" != "null" ]; then
        print_text_line "Subscription URL:"
        print_text_line "$USER_SUBSCRIPTION_URL"
        print_empty_line
    fi

    print_text_line "Caddy auth login: $AUTHP_ADMIN_USER"
    print_text_line "Caddy auth password: $AUTHP_ADMIN_SECRET"
    print_empty_line
    print_text_line "Remnawave admin login: $SUPERADMIN_USERNAME"
    print_text_line "Remnawave admin password: $SUPERADMIN_PASSWORD"
    print_empty_line
    echo -e "\033[1m└${border_line}┘\033[0m"

    echo
    show_success "Credentials saved in file: $CREDENTIALS_FILE"
    echo -e "${BOLD_BLUE}Installation directory: ${NC}$REMNAWAVE_DIR/"
    echo

    if [ "$installation_type" = "all-in-one" ] && [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$USER_SUBSCRIPTION_URL" != "null" ]; then
        generate_qr_code "$USER_SUBSCRIPTION_URL" "Subscription URL QR Code"
        echo
    fi

    cd ~

    echo -e "${BOLD_GREEN}Installation complete. Press Enter to continue...${NC}"
    read -r
}

# Including module: cookie-auth.sh
start_caddy_cookie_auth() {
  if ! start_container "$REMNAWAVE_DIR/caddy" "Caddy"; then
    show_info "Installation stopped" "$BOLD_RED"
    exit 1
  fi
}

generate_cookie_auth_secrets() {
  PANEL_SECRET_KEY=$(generate_nonce 64)
}

save_credentials_cookie_auth() {
  CREDENTIALS_FILE="$REMNAWAVE_DIR/credentials.txt"
  echo "PANEL URL: https://$PANEL_DOMAIN?caddy=$PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"
  echo >>"$CREDENTIALS_FILE"
  echo "SUPERADMIN USERNAME: $SUPERADMIN_USERNAME" >>"$CREDENTIALS_FILE"
  echo "SUPERADMIN PASSWORD: $SUPERADMIN_PASSWORD" >>"$CREDENTIALS_FILE"

  chmod 600 "$CREDENTIALS_FILE"
}

display_cookie_auth_results() {
  local installation_type="${1:-panel}" # Default to panel if not specified
  local secure_panel_url="https://$PANEL_DOMAIN/auth/login?caddy=$PANEL_SECRET_KEY"

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

  print_text_line "Secure login link (with secret key):"
  print_empty_line
  print_text_line "$secure_panel_url"
  print_empty_line

  if [ "$installation_type" = "all-in-one" ] && [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$USER_SUBSCRIPTION_URL" != "null" ]; then
    print_text_line "User subscription URL:"
    print_text_line "$USER_SUBSCRIPTION_URL"
    print_empty_line
  fi

  print_text_line "Admin login: $SUPERADMIN_USERNAME"
  print_text_line "Admin password: $SUPERADMIN_PASSWORD"
  print_empty_line
  echo -e "\033[1m└${border_line}┘\033[0m"

  echo
  show_success "Credentials saved in file: $CREDENTIALS_FILE"
  echo -e "${BOLD_BLUE}Installation directory: ${NC}$REMNAWAVE_DIR/"
  echo

  if [ "$installation_type" = "all-in-one" ] && [ -n "$USER_SUBSCRIPTION_URL" ] && [ "$USER_SUBSCRIPTION_URL" != "null" ]; then
    generate_qr_code "$USER_SUBSCRIPTION_URL" "Subscription URL QR Code"
    echo
  fi

  cd ~

  echo -e "${BOLD_GREEN}Installation complete. Press Enter to continue...${NC}"
  read -r
}

# Including module: static-site.sh

create_static_site() {
  local directory="$1"

  mkdir -p $directory/html/assets

  (
    curl -s -o $directory/html/index.html https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/index.html
    curl -s -o $directory/html/assets/index-BilmB03J.css https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-BilmB03J.css
    curl -s -o $directory/html/assets/index-CRT2NuFx.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-CRT2NuFx.js
    curl -s -o $directory/html/assets/index-legacy-D44yECni.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-legacy-D44yECni.js
    curl -s -o $directory/html/assets/polyfills-legacy-B97CwC2N.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/polyfills-legacy-B97CwC2N.js
    curl -s -o $directory/html/assets/vendor-DHVSyNSs.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-DHVSyNSs.js
    curl -s -o $directory/html/assets/vendor-legacy-Cq-AagHX.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-legacy-Cq-AagHX.js
  ) >/dev/null 2>&1 &

  download_pid=$!
  spinner !$download_pid "Downloading static files for the selfsteal site..."
}

# Including module: subscription-page.sh

setup_remnawave-subscription-page() {
    mkdir -p $REMNAWAVE_DIR/subscription-page

    cd $REMNAWAVE_DIR/subscription-page

    cat >docker-compose.yml <<EOF
services:
    remnawave-subscription-page:
        image: remnawave/subscription-page:latest
        container_name: remnawave-subscription-page
        hostname: remnawave-subscription-page
        restart: always
        environment:
            - REMNAWAVE_PANEL_URL=http://remnawave:3000
            - SUBSCRIPTION_PAGE_PORT=3010
            - META_TITLE="Subscription Page Title"
            - META_DESCRIPTION="Subscription Page Description"
        ports:
            - '127.0.0.1:3010:3010'
        networks:
            - remnawave-network

networks:
    remnawave-network:
        driver: bridge
        external: true
EOF

    create_makefile "$REMNAWAVE_DIR/subscription-page"
}

# Including module: vless-config.sh


configure_vless_panel_only() {
    local panel_url="127.0.0.1:3000"
    local config_file="$REMNAWAVE_DIR/config.json"

    NODE_HOST=$(simple_read_domain_or_ip "Enter the IP address or domain of the node server (if different from Selfsteal domain)" "$SELF_STEAL_DOMAIN")

    local keys_result=$(generate_vless_keys)
    if [ $? -ne 0 ]; then
        return 1
    fi

    local private_key=$(echo "$keys_result" | cut -d':' -f1)

    generate_xray_config "$config_file" "$SELF_STEAL_DOMAIN" "$CADDY_LOCAL_PORT" "$private_key"

    if ! update_xray_config "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$config_file"; then
        return 1
    fi

    if ! create_node "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$NODE_HOST" "$NODE_PORT"; then
        return 1
    fi

    local inbound_uuid=$(get_inbounds "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN")
    if [ -z "$inbound_uuid" ]; then
        return 1
    fi

    if ! create_host "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$inbound_uuid" "$SELF_STEAL_DOMAIN"; then
        return 1
    fi

    if ! create_user "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "remnawave" "$inbound_uuid"; then
        return 1
    fi

    local pubkey=$(get_public_key "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN")
    if [ -n "$pubkey" ]; then
        echo
        echo -e "${GREEN}Public key (required for node installation):${NC}"
        echo
        echo -e "SSL_CERT=\"$pubkey\""
        echo
    fi
}

# Including module: caddy-cookie-auth.sh

setup_caddy_for_panel() {
	local BACKEND_URL=127.0.0.1:3000
	local SUB_BACKEND_URL=127.0.0.1:3010
	cd $REMNAWAVE_DIR/caddy

	cat >docker-compose.yml <<EOF
services:
  caddy:
    image: caddy:2.9.1
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/www/html
      - ./logs:/var/log/caddy
      - remnawave-caddy-ssl-data:/data
    environment:
      - CADDY_LOCAL_PORT=$CADDY_LOCAL_PORT
      - SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN
      - PANEL_DOMAIN=$PANEL_DOMAIN
      - SUB_DOMAIN=$SUB_DOMAIN
      - BACKEND_URL=$BACKEND_URL
      - SUB_BACKEND_URL=$SUB_BACKEND_URL
      - PANEL_SECRET_KEY=$PANEL_SECRET_KEY
    network_mode: "host"

volumes:
  remnawave-caddy-ssl-data:
    driver: local
    external: false
    name: remnawave-caddy-ssl-data
EOF

	cat >Caddyfile <<"EOF"
{
	admin   off
}

https://{$SELF_STEAL_DOMAIN} {
	root * /var/www/html
	try_files {path} /index.html
	file_server
}

https://{$PANEL_DOMAIN} {
	@has_token_param {
		query caddy={$PANEL_SECRET_KEY}
	}

	handle @has_token_param {
		header +Set-Cookie "caddy={$PANEL_SECRET_KEY}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000"
	}

	@unauthorized {
		not header Cookie *caddy={$PANEL_SECRET_KEY}*
		not query caddy={$PANEL_SECRET_KEY}
	}

	handle @unauthorized {
		root * /var/www/html
		try_files {path} /index.html
		file_server
	}

	reverse_proxy {$BACKEND_URL} {
		header_up X-Real-IP {remote}
		header_up Host {host}
	}
}

https://{$SUB_DOMAIN} {
	handle {
		reverse_proxy {$SUB_BACKEND_URL} {
			header_up X-Real-IP {remote}
			header_up Host {host}
		}
	}
}

:{$CADDY_LOCAL_PORT} {
	tls internal
	respond 204
}

:80 {
	bind 0.0.0.0
	respond 204
}
EOF

	create_makefile "$REMNAWAVE_DIR/caddy"

	create_static_site "$REMNAWAVE_DIR/caddy"
}

# Including module: caddy-full-auth.sh

setup_caddy_panel_only_full_auth() {
    cd $REMNAWAVE_DIR/caddy

    cat >Caddyfile <<"EOF"
{
    admin   off
    auto_https disable_redirects
    order authenticate before respond
    order authorize before respond

    security {
        local identity store localdb {
            realm local
            path /data/.local/caddy/users.json
        }

        authentication portal remnawaveportal {
            crypto default token lifetime {$AUTH_TOKEN_LIFETIME}
            enable identity store localdb
            cookie domain {$REMNAWAVE_PANEL_DOMAIN}
            ui {
                links {
                    "Remnawave" "/dashboard/home" icon "las la-tachometer-alt"
                    "My Identity" "/{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/whoami" icon "las la-user"
                    "API Keys" "/{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/settings/apikeys" icon "las la-key"
                    "MFA" "/{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/settings/mfa" icon "lab la-keycdn"
                }
            }
            transform user {
                match origin local
                require mfa
                action add role authp/admin
            }
        }

        authorization policy panelpolicy {
            set auth url /restricted
            disable auth redirect
            allow roles authp/admin
            with api key auth portal remnawaveportal realm local

            acl rule {
                comment "Accept"
                match role authp/admin
                allow stop log info
            }
            acl rule {
                comment "Deny"
                match any
                deny log warn
            }
        }
    }
}

http://{$REMNAWAVE_PANEL_DOMAIN} {
    redir https://{$REMNAWAVE_PANEL_DOMAIN}{uri} permanent
}

https://{$REMNAWAVE_PANEL_DOMAIN} {

    @login_path {
        path /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE} /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/ /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/auth
    }
    handle @login_path {
        rewrite * /auth
        request_header +X-Forwarded-Prefix /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}
        authenticate with remnawaveportal
    }

    handle_path /restricted* {
        abort
    }

    route /api/* {
        authorize with panelpolicy
        reverse_proxy http://127.0.0.1:3000
    }

    route /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}* {
        authenticate with remnawaveportal
    }

    route /* {
        authorize with panelpolicy
        reverse_proxy http://127.0.0.1:3000
    }

    handle_errors {
        @unauth {
            expression {http.error.status_code} == 401
        }
        handle @unauth {
            respond * 204
        }
    }
}

http://{$CADDY_SUB_DOMAIN} {
    redir https://{$CADDY_SUB_DOMAIN}{uri} permanent
}

https://{$CADDY_SUB_DOMAIN} {
    handle {
        reverse_proxy http://127.0.0.1:3010 {
            header_up X-Real-IP {remote}
            header_up Host {host}
        }
    }
    handle_errors {
        handle {
            respond * 204
        }
    }
}
EOF

    cat >docker-compose.yml <<EOF
services:
    remnawave-caddy:
        image: remnawave/caddy-with-auth:latest
        container_name: 'remnawave-caddy'
        hostname: remnawave-caddy
        restart: always
        environment:
            - AUTH_TOKEN_LIFETIME=3600
            - REMNAWAVE_PANEL_DOMAIN=$PANEL_DOMAIN
            - REMNAWAVE_CUSTOM_LOGIN_ROUTE=$CUSTOM_LOGIN_ROUTE
            - AUTHP_ADMIN_USER=$AUTHP_ADMIN_USER
            - AUTHP_ADMIN_EMAIL=$AUTHP_ADMIN_EMAIL
            - AUTHP_ADMIN_SECRET=$AUTHP_ADMIN_SECRET
            - HTTPS_PORT=$CADDY_LOCAL_PORT
            - CADDY_SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN
            - CADDY_SUB_DOMAIN=$SUB_DOMAIN
        volumes:
            - ./Caddyfile:/etc/caddy/Caddyfile
            - ./html:/var/www/html
            - remnawave-caddy-ssl-data:/data
        network_mode: "host"

volumes:
    remnawave-caddy-ssl-data:
        driver: local
        external: false
        name: remnawave-caddy-ssl-data
EOF

    create_makefile "$REMNAWAVE_DIR/caddy"
    create_static_site "$REMNAWAVE_DIR/caddy"
}

# Including module: setup.sh


generate_secrets_panel_only() {
    local auth_type=$1

    generate_secrets
    if [ "$auth_type" = "full" ]; then
        generate_full_auth_secrets
    else
        if [ "$auth_type" = "cookie" ]; then
            generate_cookie_auth_secrets
        fi
    fi
}

collect_selfsteal_domain_for_panel() {
    while true; do
        SELF_STEAL_DOMAIN=$(prompt_domain "Enter Selfsteal domain (will be used on node server), e.g. domain.example.com" "$ORANGE" true false true)

        if check_domain_uniqueness "$SELF_STEAL_DOMAIN" "selfsteal" "$PANEL_DOMAIN" "$SUB_DOMAIN"; then
            break
        fi
        show_warning "Please enter a different domain for selfsteal service."
        echo
    done
}

collect_config_panel_only() {
    local auth_type=$1

    collect_telegram_config
    collect_domain_config
    collect_selfsteal_domain_for_panel

    if ! collect_ports_separate_installation; then
        return 1
    fi

    if [ "$auth_type" = "full" ]; then
        collect_full_auth_config
    fi
}

setup_caddy_panel_only() {
    local auth_type=$1

    if [ "$auth_type" = "cookie" ]; then
        setup_caddy_for_panel "$PANEL_SECRET_KEY"
    else
        if [ "$auth_type" = "full" ]; then
            setup_caddy_panel_only_full_auth
        fi
    fi
}

start_caddy_panel_only() {
    local auth_type=$1

    if [ "$auth_type" = "cookie" ]; then
        start_caddy_cookie_auth
    else
        if [ "$auth_type" = "full" ]; then
            start_caddy_full_auth
        fi
    fi
}

save_and_display_panel_only() {
    local auth_type=$1

    if [ "$auth_type" = "cookie" ]; then
        save_credentials_cookie_auth
        display_cookie_auth_results "panel"
    else
        if [ "$auth_type" = "full" ]; then
            save_credentials_full_auth
            display_full_auth_results "panel"
        fi
    fi
}

install_panel_only() {
    local auth_type=$1

    if [[ "$auth_type" != "cookie" && "$auth_type" != "full" ]]; then
        show_error "Invalid auth type: $auth_type. Must be 'cookie' or 'full'"
        return 1
    fi

    if ! prepare_installation; then
        return 1
    fi

    generate_secrets_panel_only $auth_type

    if ! collect_config_panel_only $auth_type; then
        return 1
    fi

    setup_panel_docker_compose

    setup_panel_environment

    create_makefile "$REMNAWAVE_DIR"

    setup_caddy_panel_only $auth_type
    setup_remnawave-subscription-page

    start_services
    start_caddy_panel_only $auth_type

    register_panel_user
    configure_vless_panel_only

    save_and_display_panel_only $auth_type
}

# Including module: selfsteal.sh


setup_selfsteal() {
    mkdir -p $SELFSTEAL_DIR/html && cd $SELFSTEAL_DIR

    cat >.env <<EOF
SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN
CADDY_LOCAL_PORT=$CADDY_LOCAL_PORT
EOF

    cat >Caddyfile <<'EOF'
{
    admin   off
    https_port {$CADDY_LOCAL_PORT}
    default_bind 127.0.0.1
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
}

http://{$SELF_STEAL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
    root * /var/www/html
    try_files {path} /index.html
    file_server
}


:{$CADDY_LOCAL_PORT} {
    tls internal
    respond 204
}

:80 {
    bind 0.0.0.0
    respond 204
}
EOF

    cat >docker-compose.yml <<EOF
services:
  caddy:
    image: caddy:2.9.1
    container_name: caddy-selfsteal
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/www/html
      - remnawave-caddy-ssl-data:/data
    env_file:
      - .env
    network_mode: "host"

volumes:
    remnawave-caddy-ssl-data:
        driver: local
        external: false
        name: remnawave-caddy-ssl-data
EOF

    create_makefile "$SELFSTEAL_DIR"

    create_static_site "$SELFSTEAL_DIR"

    mkdir -p logs

    if ! start_container "$SELFSTEAL_DIR" "Caddy"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi

    CADDY_STATUS=$(docker compose ps --services --filter "status=running" | grep -q "caddy" && echo "running" || echo "stopped")

    if [ "$CADDY_STATUS" = "running" ]; then
        echo -e "${LIGHT_GREEN}• Domain: ${BOLD_GREEN}$SELF_STEAL_DOMAIN${NC}"
        echo -e "${LIGHT_GREEN}• Port: ${BOLD_GREEN}$CADDY_LOCAL_PORT${NC}"
        echo -e "${LIGHT_GREEN}• Directory: ${BOLD_GREEN}$SELFSTEAL_DIR${NC}"
        echo
    fi

    unset SELF_STEAL_DOMAIN
    unset CADDY_LOCAL_PORT
}

# Including module: node.sh

create_node_docker_compose() {
    mkdir -p $REMNANODE_DIR && cd $REMNANODE_DIR
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
}

collect_node_selfsteal_domain() {
    SELF_STEAL_DOMAIN=$(prompt_domain "Enter Selfsteal domain, e.g. domain.example.com" "$ORANGE" true false false)
}

check_node_ports() {
    if CADDY_LOCAL_PORT=$(check_required_port "9443"); then
        show_info "Required Caddy port 9443 is available"
    else
        show_error "Required Caddy port 9443 is already in use!"
        show_error "For separate node installation, port 9443 must be available."
        show_error "Please free up port 9443 and try again."
        show_error "Installation cannot continue with occupied port 9443"
        exit 1
    fi

    if NODE_PORT=$(check_required_port "2222"); then
        show_info "Required Node API port 2222 is available"
    else
        show_error "Required Node API port 2222 is already in use!"
        show_error "For separate node installation, port 2222 must be available."
        show_error "Please free up port 2222 and try again."
        show_error "Installation cannot continue with occupied port 2222"
        exit 1
    fi
}

collect_node_ssl_certificate() {
    while true; do
        echo -e "${ORANGE}Enter the server certificate in format SSL_CERT=\"...\" (paste the content and press Enter twice): ${NC}"
        CERTIFICATE=""
        while IFS= read -r line; do
            if [ -z "$line" ]; then
                if [ -n "$CERTIFICATE" ]; then
                    break
                fi
            else
                CERTIFICATE="${CERTIFICATE}${line}"
            fi
        done

        if validate_ssl_certificate "$CERTIFICATE"; then
            echo -e "${BOLD_GREEN}✓ SSL certificate format is valid${NC}"
            echo
            break
        else
            echo -e "${BOLD_RED}✗ Invalid SSL certificate format. Please try again.${NC}"
            echo -e "${YELLOW}Expected format: SSL_CERT=\"...eyJub2RlQ2VydFBldW0iOiAi...\"${NC}"
            echo
        fi
    done
}

create_node_env_file() {
    echo -e "### APP ###" >.env
    echo -e "APP_PORT=$NODE_PORT" >>.env
    echo -e "$CERTIFICATE" >>.env
}

start_node_and_show_results() {
    if ! start_container "$REMNANODE_DIR" "Remnawave Node"; then
        show_info "Installation stopped" "$BOLD_RED"
        exit 1
    fi

    echo -e "${LIGHT_GREEN}• Node port: ${BOLD_GREEN}$NODE_PORT${NC}"
    echo -e "${LIGHT_GREEN}• Node directory: ${BOLD_GREEN}$REMNANODE_DIR${NC}"
    echo
}

collect_panel_ip() {
    while true; do
        PANEL_IP=$(simple_read_domain_or_ip "Enter the IP address of the panel server (for configuring firewall)" "" "ip_only")
        if [ -n "$PANEL_IP" ]; then
            break
        fi
    done
}

allow_ufw_node_port_from_panel_ip() {
    echo "Allow connections from panel server to node port 2222..."
    echo
    ufw allow from "$PANEL_IP" to any port 2222 proto tcp
    echo
    ufw reload >/dev/null 2>&1
}

setup_node() {
    clear

    if ! prepare_installation; then
        return 1
    fi

    create_node_docker_compose

    create_makefile "$REMNANODE_DIR"

    collect_node_selfsteal_domain

    collect_panel_ip

    allow_ufw_node_port_from_panel_ip

    check_node_ports

    collect_node_ssl_certificate

    create_node_env_file

    setup_selfsteal

    start_node_and_show_results

    unset CERTIFICATE
    unset NODE_PORT

    echo -e "\n${BOLD_GREEN}Press Enter to return to the main menu...${NC}"
    read -r
}

# Including module: vless-config.sh


configure_vless_all_in_one() {
    local panel_url="127.0.0.1:3000"
    local config_file="$REMNAWAVE_DIR/config.json"
    local node_host="172.17.0.1"  # Docker bridge IP
    
    local keys_result=$(generate_vless_keys)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local private_key=$(echo "$keys_result" | cut -d':' -f1)
    
    generate_xray_config "$config_file" "$PANEL_DOMAIN" "$CADDY_LOCAL_PORT" "$private_key"
    
    if ! update_xray_config "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$config_file"; then
        return 1
    fi
    
    if ! create_node "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$node_host" "$NODE_PORT"; then
        return 1
    fi
    
    local inbound_uuid=$(get_inbounds "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN")
    if [ -z "$inbound_uuid" ]; then
        return 1
    fi
    
    if ! create_host "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "$inbound_uuid" "$PANEL_DOMAIN"; then
        return 1
    fi

    if ! create_user "$panel_url" "$REG_TOKEN" "$PANEL_DOMAIN" "remnawave" "$inbound_uuid"; then
        return 1
    fi
}



# Including module: setup-node.sh


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

# Including module: caddy-cookie-auth.sh

create_docker_compose_cookie_auth() {
	local BACKEND_URL=127.0.0.1:3000
	local SUB_BACKEND_URL=127.0.0.1:3010

	cat >docker-compose.yml <<EOF
services:
  caddy:
    image: caddy:2.9.1
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/www/html
      - ./logs:/var/log/caddy
      - remnawave-caddy-ssl-data:/data
    environment:
      - CADDY_LOCAL_PORT=$CADDY_LOCAL_PORT
      - SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN
      - PANEL_DOMAIN=$PANEL_DOMAIN
      - SUB_DOMAIN=$SUB_DOMAIN
      - BACKEND_URL=$BACKEND_URL
      - SUB_BACKEND_URL=$SUB_BACKEND_URL
      - PANEL_SECRET_KEY=$PANEL_SECRET_KEY
    network_mode: "host"

volumes:
  remnawave-caddy-ssl-data:
    driver: local
    external: false
    name: remnawave-caddy-ssl-data
EOF
}

create_Caddyfile_cookie_auth() {

	cat >Caddyfile <<"EOF"
{
	admin   off
	https_port {$CADDY_LOCAL_PORT}
	default_bind 127.0.0.1
	servers {
		listener_wrappers {
			proxy_protocol {
				allow 127.0.0.1/32
			}
			tls
		}
	}
	auto_https disable_redirects
}

http://{$SELF_STEAL_DOMAIN} {
	bind 0.0.0.0
	redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
	root * /var/www/html
	try_files {path} /index.html
	file_server
}

http://{$PANEL_DOMAIN} {
	bind 0.0.0.0
	redir https://{$PANEL_DOMAIN}{uri} permanent
}

https://{$PANEL_DOMAIN} {
	@has_token_param {
		query caddy={$PANEL_SECRET_KEY}
	}

	handle @has_token_param {
		header +Set-Cookie "caddy={$PANEL_SECRET_KEY}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=2592000"
	}

	@unauthorized {
		not header Cookie *caddy={$PANEL_SECRET_KEY}*
		not query caddy={$PANEL_SECRET_KEY}
	}

	handle @unauthorized {
		root * /var/www/html
		try_files {path} /index.html
		file_server
	}

	reverse_proxy {$BACKEND_URL} {
		header_up X-Real-IP {remote}
		header_up Host {host}
	}
}

http://{$SUB_DOMAIN} {
	bind 0.0.0.0
	redir https://{$SUB_DOMAIN}{uri} permanent
}

https://{$SUB_DOMAIN} {
	handle {
		reverse_proxy {$SUB_BACKEND_URL} {
			header_up X-Real-IP {remote}
			header_up Host {host}
		}
	}
}

:{$CADDY_LOCAL_PORT} {
	tls internal
	respond 204
}

:80 {
	bind 0.0.0.0
	respond 204
}
EOF

}

setup_caddy_all_in_one_cookie_auth() {
	cd $REMNAWAVE_DIR/caddy

	create_docker_compose_cookie_auth

	create_Caddyfile_cookie_auth

	create_makefile "$REMNAWAVE_DIR/caddy"

	create_static_site "$REMNAWAVE_DIR/caddy"
}

# Including module: caddy-full-auth.sh

setup_caddy_all_in_one_full_auth() {
	cd $REMNAWAVE_DIR/caddy

	cat >Caddyfile <<"EOF"
{
    admin   off
    https_port {$HTTPS_PORT}
    default_bind 127.0.0.1
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
    order authenticate before respond
    order authorize before respond

    security {
        local identity store localdb {
            realm local
            path /data/.local/caddy/users.json
        }

        authentication portal remnawaveportal {
            crypto default token lifetime {$AUTH_TOKEN_LIFETIME}
            enable identity store localdb
            cookie domain {$REMNAWAVE_PANEL_DOMAIN}
            ui {
                links {
                    "Remnawave" "/dashboard/home" icon "las la-tachometer-alt"
                    "My Identity" "/{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/whoami" icon "las la-user"
                    "API Keys" "/{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/settings/apikeys" icon "las la-key"
                    "MFA" "/{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/settings/mfa" icon "lab la-keycdn"
                }
            }
            transform user {
                match origin local
                require mfa
                action add role authp/admin
            }
        }

        authorization policy panelpolicy {
            set auth url /restricted
            disable auth redirect
            allow roles authp/admin
            with api key auth portal remnawaveportal realm local

            acl rule {
                comment "Accept"
                match role authp/admin
                allow stop log info
            }
            acl rule {
                comment "Deny"
                match any
                deny log warn
            }
        }
    }
}

http://{$REMNAWAVE_PANEL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$REMNAWAVE_PANEL_DOMAIN}{uri} permanent
}

https://{$REMNAWAVE_PANEL_DOMAIN} {

    @login_path {
        path /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE} /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/ /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}/auth
    }
    handle @login_path {
        rewrite * /auth
        request_header +X-Forwarded-Prefix /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}
        authenticate with remnawaveportal
    }

    handle_path /restricted* {
        abort
    }

    route /api/* {
        authorize with panelpolicy
        reverse_proxy http://127.0.0.1:3000
    }

    route /{$REMNAWAVE_CUSTOM_LOGIN_ROUTE}* {
        authenticate with remnawaveportal
    }

    route /* {
        authorize with panelpolicy
        reverse_proxy http://127.0.0.1:3000
    }

    handle_errors {
        @unauth {
            expression {http.error.status_code} == 401
        }
        handle @unauth {
            respond * 204
        }
    }
}

http://{$CADDY_SELF_STEAL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$CADDY_SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$CADDY_SELF_STEAL_DOMAIN} {
    root * /var/www/html
    try_files {path} /index.html
    file_server
}

http://{$CADDY_SUB_DOMAIN} {
    bind 0.0.0.0
    redir https://{$CADDY_SUB_DOMAIN}{uri} permanent
}

https://{$CADDY_SUB_DOMAIN} {
    handle {
        reverse_proxy http://127.0.0.1:3010 {
            header_up X-Real-IP {remote}
            header_up Host {host}
        }
    }
    handle_errors {
        handle {
            respond * 204
        }
    }
}

:{$HTTPS_PORT} {
    tls internal
    respond 204
}

:80 {
    bind 0.0.0.0
    respond 204
}
EOF

	cat >docker-compose.yml <<EOF
services:
    remnawave-caddy:
        image: remnawave/caddy-with-auth:latest
        container_name: 'remnawave-caddy'
        hostname: remnawave-caddy
        restart: always
        environment:
            - AUTH_TOKEN_LIFETIME=3600
            - REMNAWAVE_PANEL_DOMAIN=$PANEL_DOMAIN
            - REMNAWAVE_CUSTOM_LOGIN_ROUTE=$CUSTOM_LOGIN_ROUTE
            - AUTHP_ADMIN_USER=$AUTHP_ADMIN_USER
            - AUTHP_ADMIN_EMAIL=$AUTHP_ADMIN_EMAIL
            - AUTHP_ADMIN_SECRET=$AUTHP_ADMIN_SECRET
            - HTTPS_PORT=$CADDY_LOCAL_PORT
            - CADDY_SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN
            - CADDY_SUB_DOMAIN=$SUB_DOMAIN
        volumes:
            - ./Caddyfile:/etc/caddy/Caddyfile
            - ./html:/var/www/html
            - remnawave-caddy-ssl-data:/data
        network_mode: "host"

volumes:
    remnawave-caddy-ssl-data:
        driver: local
        external: false
        name: remnawave-caddy-ssl-data
EOF

	create_makefile "$REMNAWAVE_DIR/caddy"

	mkdir -p $REMNAWAVE_DIR/caddy/html/assets

	(
		curl -s -o ./html/index.html https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/index.html

		curl -s -o ./html/assets/index-BilmB03J.css https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-BilmB03J.css
		curl -s -o ./html/assets/index-CRT2NuFx.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-CRT2NuFx.js
		curl -s -o ./html/assets/index-legacy-D44yECni.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-legacy-D44yECni.js
		curl -s -o ./html/assets/polyfills-legacy-B97CwC2N.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/polyfills-legacy-B97CwC2N.js
		curl -s -o ./html/assets/vendor-DHVSyNSs.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-DHVSyNSs.js
		curl -s -o ./html/assets/vendor-legacy-Cq-AagHX.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-legacy-Cq-AagHX.js
	) >/dev/null 2>&1 &

	download_pid=$!
}

# Including module: setup.sh


generate_secrets_all_in_one() {
    local auth_type=$1

    generate_secrets
    if [ "$auth_type" = "full" ]; then
        generate_full_auth_secrets
    else
        if [ "$auth_type" = "cookie" ]; then
            generate_cookie_auth_secrets
        fi
    fi
}

setup_caddy_all_in_one() {
    local auth_type=$1

    if [ "$auth_type" = "full" ]; then
        setup_caddy_all_in_one_full_auth
    else
        if [ "$auth_type" = "cookie" ]; then
            setup_caddy_all_in_one_cookie_auth
        fi
    fi
}

start_caddy_all_in_one() {
    local auth_type=$1

    if [ "$auth_type" = "full" ]; then
        start_caddy_full_auth
    else
        if [ "$auth_type" = "cookie" ]; then
            start_caddy_cookie_auth
        fi
    fi

}

save_credentials_all_in_one() {
    local auth_type=$1

    if [ "$auth_type" = "full" ]; then
        save_credentials_full_auth
    else
        if [ "$auth_type" = "cookie" ]; then
            save_credentials_cookie_auth
        fi
    fi
}

display_results_all_in_one() {
    local auth_type=$1

    if [ "$auth_type" = "full" ]; then
        display_full_auth_results "all-in-one"
    else
        if [ "$auth_type" = "cookie" ]; then
            display_cookie_auth_results "all-in-one"
        fi
    fi
}

collect_selfsteal_domain_for_all_in_one() {
    while true; do
        SELF_STEAL_DOMAIN=$(prompt_domain "Enter Selfsteal domain (will be used on node server), e.g. domain.example.com" "$ORANGE" true false false)

        if check_domain_uniqueness "$SELF_STEAL_DOMAIN" "selfsteal" "$PANEL_DOMAIN" "$SUB_DOMAIN"; then
            break
        fi
        show_warning "Please enter a different domain for selfsteal service."
        echo
    done
}

install_remnawave_all_in_one() {
    local auth_type=$1

    if ! prepare_installation "qrencode"; then
        return 1
    fi

    generate_secrets_all_in_one $auth_type

    collect_telegram_config
    collect_domain_config
    collect_selfsteal_domain_for_all_in_one

    if [ "$auth_type" = "full" ]; then
        collect_full_auth_config
    fi

    collect_ports_all_in_one

    allow_ufw_node_port_from_panel

    setup_panel_docker_compose

    setup_panel_environment

    create_makefile "$REMNAWAVE_DIR"

    setup_caddy_all_in_one $auth_type

    setup_remnawave-subscription-page

    start_services

    start_caddy_all_in_one $auth_type

    register_panel_user
    configure_vless_all_in_one

    setup_and_start_all_in_one_node

    save_credentials_all_in_one $auth_type

    display_results_all_in_one $auth_type
}


if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (sudo)"
    exit 1
fi

clear


main() {

    while true; do
        draw_info_box "Remnawave Panel" "Automatic installation by uphantom"

        echo -e "  ${BOLD_BLUE_MENU}═══ COMPONENT INSTALLATION ═══${NC}"
        echo
        echo
        echo -e "  ${YELLOW}[PANEL ONLY]:${NC}"
        echo
        echo -e "  ${GREEN}1. ${NC}Panel with FULL Caddy security (recommended)"
        echo -e "  ${GREEN}2. ${NC}Panel with SIMPLE cookie security"
        echo
        echo
        echo -e "  ${YELLOW}[NODE ONLY]:${NC}"
        echo
        echo -e "  ${GREEN}3. ${NC}Node only (for separate server)"
        echo
        echo
        echo -e "  ${YELLOW}[ALL-IN-ONE]:${NC}"
        echo
        echo -e "  ${GREEN}4. ${NC}Panel + Node with FULL Caddy security"
        echo -e "  ${GREEN}5. ${NC}Panel + Node with SIMPLE cookie security"
        echo

        echo -e "  ${BOLD_BLUE_MENU}═══ PANEL MANAGEMENT ═══${NC}"
        echo
        echo -e "  ${GREEN}6. ${NC}Restart panel"
        echo -e "  ${GREEN}7. ${NC}Remove panel"
        echo -e "  ${GREEN}8. ${NC}Reset admin login and password"
        echo -e "  ${GREEN}9. ${NC}Show panel access credentials"
        echo

        echo -e "  ${BOLD_BLUE_MENU}═══ SYSTEM MANAGEMENT ═══${NC}"
        echo
        echo -e "  ${GREEN}10. ${NC}Enable BBR"
        echo

        echo -e "  ${BOLD_BLUE_MENU}═══ EXIT ═══${NC}"
        echo
        echo -e "  ${GREEN}0. ${NC}Exit from script"
        echo
        echo -ne "${BOLD_BLUE_MENU}Select option (0-10): ${NC}"
        read choice

        case $choice in
        1)
            install_panel_only "full"
            ;;
        2)
            install_panel_only "cookie"
            ;;
        3)
            setup_node
            ;;
        4)
            install_remnawave_all_in_one "full"
            ;;
        5)
            install_remnawave_all_in_one "cookie"
            ;;
        6)
            restart_panel
            ;;
        7)
            remove_previous_installation true
            ;;
        8)
            delete_admin
            ;;
        9)
            show_panel_credentials
            ;;
        10)
            enable_bbr
            ;;
        0)
            echo "Exiting."
            break
            ;;
        *)
            clear
            draw_info_box "Remnawave Panel" "Automatic installation by uphantom"
            echo -e "${BOLD_RED}Invalid choice, please try again.${NC}"
            sleep 1
            ;;
        esac
    done
}

main
