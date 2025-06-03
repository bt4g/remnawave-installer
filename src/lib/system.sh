#!/bin/bash

# ===================================================================================
#                                SYSTEM FUNCTIONS
# ===================================================================================

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

install_dependencies() {
    local extra_deps=("$@")

    # Detect distro (quietly)
    if ! command -v lsb_release &>/dev/null; then
        sudo apt-get update -qq >/dev/null
        sudo apt-get install -y --no-install-recommends lsb-release -qq >/dev/null
    fi
    distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    codename=$(lsb_release -cs)

    if [[ "$distro" != "ubuntu" && "$distro" != "debian" ]]; then
        echo "❌  Distribution $distro is not supported." >&2
        exit 1
    fi

    # Add Docker repo if absent
    if ! grep -Rq '^deb .*\bdocker\.com/linux' /etc/apt/sources.list{,.d/*} 2>/dev/null; then
        {
            sudo install -m0755 -d /etc/apt/keyrings
            curl -fsSL "https://download.docker.com/linux/${distro}/gpg" |
                sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${distro} ${codename} stable" |
                sudo tee /etc/apt/sources.list.d/docker-stable.list >/dev/null
        } >/dev/null 2>&1
    fi

    # Update package lists
    (sudo apt-get update -qq >/dev/null 2>&1) &
    spinner $! "Updating APT cache"

    # Prepare package list
    local base_deps=(
        ca-certificates gnupg curl jq make dnsutils ufw unattended-upgrades
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        lsb-release
    )
    local all_deps=()
    for pkg in "${base_deps[@]}" "${extra_deps[@]}"; do
        [[ " ${all_deps[*]} " != *" $pkg "* ]] && all_deps+=("$pkg")
    done

    local missing=()
    for dep in "${all_deps[@]}"; do
        dpkg -s "$dep" &>/dev/null || missing+=("$dep")
    done

    # Install missing packages
    if ((${#missing[@]})); then
        (sudo apt-get install -y --no-install-recommends "${missing[@]}" -qq >/dev/null 2>&1) &
        spinner $! "Installing ${#missing[@]} packages"
    fi

    if ! systemctl is-active --quiet docker; then
        (sudo systemctl enable --now docker >/dev/null 2>&1) &
        spinner $! "Starting Docker daemon "
    else
        (sleep 0.1) &
        spinner $! "Docker daemon already running"
    fi

    # Add current user to docker group
    if ! id -nG "$USER" | grep -qw docker; then
        (sudo usermod -aG docker "$USER" >/dev/null 2>&1) &
        spinner $! "Adding user to group"
    fi

    # Configure UFW (quiet)
    ssh_port=$(grep -Ei '^\s*Port\s+' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
    ssh_port=${ssh_port:-22}

    if dpkg -s ufw &>/dev/null &&
        ufw status | head -1 | grep -q "Status: active" &&
        ufw status verbose | grep -q "Default: deny (incoming)" &&
        ufw status | grep -qw "${ssh_port}/tcp" &&
        ufw status | grep -qw "443/tcp" &&
        ufw status | grep -qw "80/tcp"; then
        (sleep 0.2) &
        spinner $! "Firewall already set   "
    else
        (
            sudo ufw --force reset
            sudo ufw default deny incoming
            sudo ufw allow "${ssh_port}/tcp"
            sudo ufw allow 443/tcp
            sudo ufw allow 80/tcp
            sudo ufw --force enable
        ) >/dev/null 2>&1 &
        spinner $! "Configuring firewall   "
    fi

    # Enable unattended-upgrades
    if dpkg -s unattended-upgrades &>/dev/null &&
        systemctl is-enabled --quiet unattended-upgrades &&
        systemctl is-active --quiet unattended-upgrades &&
        grep -q '^Unattended-Upgrade::SyslogEnable.*true' \
            /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null; then
        (sleep 0.2) & # визуальный «фейковый» процесс
        spinner $! "Auto-updates already set "
    else
        (
            echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true |
                sudo debconf-set-selections
            sudo dpkg-reconfigure -f noninteractive unattended-upgrades
            sudo sed -i '/^Unattended-Upgrade::SyslogEnable/ d' \
                /etc/apt/apt.conf.d/50unattended-upgrades
            echo 'Unattended-Upgrade::SyslogEnable "true";' |
                sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null
            sudo systemctl restart unattended-upgrades
        ) >/dev/null 2>&1 &
        spinner $! "Setting auto-updates   "
    fi

    echo
    show_success "All dependencies installed and configured."
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
