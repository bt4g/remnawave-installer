#!/bin/bash

# ===================================================================================
#                                SYSTEM FUNCTIONS
# ===================================================================================

# Install common dependencies for all components
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

    # Adding Docker repository (if not exists)
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

    # Building package list for installation
    local base_deps=(curl jq make dnsutils ufw unattended-upgrades
        docker-ce docker-ce-cli containerd.io
        docker-buildx-plugin docker-compose-plugin
        lsb-release)

    local all_deps=()
    for pkg in "${base_deps[@]}" "${extra_deps[@]}"; do
        [[ " ${all_deps[*]} " != *" $pkg "* ]] && all_deps+=("$pkg")
    done

    # Filtering only missing packages
    local missing_deps=()
    for dep in "${all_deps[@]}"; do
        if ! dpkg -s "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    # Installing missing packages
    if [ ${#missing_deps[@]} -gt 0 ]; then
        (sudo apt-get install -y --no-install-recommends "${missing_deps[@]}" -qq >/dev/null 2>&1) &
        spinner $! "Installing dependencies (${#missing_deps[@]} packages)"
    fi

    # Configuring and starting Docker
    (sudo systemctl enable --now docker >/dev/null 2>&1) &
    spinner $! "Starting Docker service"

    # Adding user to docker group
    if ! id -nG "$USER" | grep -qw docker; then
        (sudo usermod -aG docker "$USER" >/dev/null 2>&1) &
        spinner $! "Adding user to docker group"
        show_info "User $USER added to docker group."
    fi

    # Configuring UFW Firewall
    local ssh_port
    ssh_port=$(grep -E "^[[:space:]]*Port[[:space:]]+" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
    [ -z "$ssh_port" ] && ssh_port=22
    (ufw --force reset &&
        ufw allow "${ssh_port}/tcp" comment 'SSH' &&
        ufw allow 443/tcp comment 'HTTPS' &&
        ufw allow 80/tcp comment 'HTTP' &&
        ufw --force enable) >/dev/null 2>&1 &
    spinner $! "Configuring UFW Firewall"

    # Configuring Unattended Upgrades
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

# Create directory with proper permissions
create_dir() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        show_info "Created directory: $dir_path"
    fi
}

# Common preparation steps
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
