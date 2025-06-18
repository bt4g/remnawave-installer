#!/bin/bash

# ===================================================================================
#                                SYSTEM FUNCTIONS
# ===================================================================================

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

install_dependencies() {
    local extra_deps=("$@")

    # --- 1. Определяем дистрибутив ---
    if ! command -v lsb_release &>/dev/null; then
        show_info "Installing lsb-release..."
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends lsb-release
    fi
    local distro
    distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    local codename
    codename=$(lsb_release -cs)
    if [[ "$distro" != "ubuntu" && "$distro" != "debian" ]]; then
        show_error "$(t system_distro_not_supported) $distro"
        exit 1
    fi

    local docker_ready=false
    if command -v docker &>/dev/null && docker info &>/dev/null && docker compose version &>/dev/null; then
        show_success "$(t docker_already_installed) $(docker --version)"
        docker_ready=true
    fi

    if ! $docker_ready; then
        show_info "$(t removing_old_docker)"

        local bad_pkgs=(
            docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        )
        sudo apt-get remove -y --purge "${bad_pkgs[@]}" || true
        sudo apt-get autoremove -y || true

        show_success "$(t old_docker_removed)"
    fi

    local base_deps=(ca-certificates curl gnupg jq make dnsutils ufw unattended-upgrades lsb-release coreutils)
    for pkg in "${extra_deps[@]}"; do
        [[ " ${base_deps[*]} " != *" $pkg "* ]] && base_deps+=("$pkg")
    done

    show_info "$(t spinner_updating_apt_cache)"
    sudo apt-get update

    local missing=()
    for pkg in "${base_deps[@]}"; do
        dpkg -s "$pkg" &>/dev/null || missing+=("$pkg")
    done

    if ((${#missing[@]})); then
        local missing_str="${missing[*]}"
        show_info "$(t spinner_installing_packages) $missing_str"
        sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y install --no-install-recommends "${missing[@]}"
        show_success "$(t spinner_installing_packages) $missing_str"
    else
        show_info "$(t packages_already_installed)"
    fi

    if ! $docker_ready; then
        show_info "$(t installing_docker)"
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/${distro}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${distro} ${codename} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

        show_info "$(t spinner_updating_apt_cache)"
        sudo apt-get update

        local docker_pkgs=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
        show_info "$(t spinner_installing_packages) ${docker_pkgs[*]}"
        sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y install "${docker_pkgs[@]}"
        show_success "$(t docker_installed)"
    fi

    if ! systemctl is-active --quiet docker; then
        (sudo systemctl enable --now docker >/dev/null 2>&1) &
        spinner $! "$(t spinner_starting_docker)"
    else
        (sleep 0.2) &
        spinner $! "$(t spinner_docker_already_running)"
    fi

    if dpkg -s ufw &>/dev/null; then
        local ssh_port=$(grep -Ei '^\s*Port\s+' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
        ssh_port=${ssh_port:-22}

        # Check if UFW is active and properly configured
        if ufw status | head -1 | grep -q "Status: active" &&
           ufw status | grep -qw "${ssh_port}/tcp" &&
           ufw status | grep -qw "443/tcp" &&
           ufw status | grep -qw "80/tcp"; then
            (sleep 0.2) &
            spinner $! "$(t spinner_firewall_already_set)"
        else
            (
                sudo ufw --force reset
                sudo ufw default deny incoming
                sudo ufw allow "${ssh_port}/tcp"
                sudo ufw allow 80/tcp
                sudo ufw allow 443/tcp
                sudo ufw --force enable
            ) >/dev/null 2>&1 &
            spinner $! "$(t spinner_configuring_firewall)"
            show_success "$(t ufw_ports_opened) ${ssh_port},80,443"
        fi
    fi

    if dpkg -s unattended-upgrades &>/dev/null; then
        if systemctl is-enabled --quiet unattended-upgrades && systemctl is-active --quiet unattended-upgrades; then
            (sleep 0.2) &
            spinner $! "$(t spinner_auto_updates_already_set)"
        else
            (
                echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | sudo debconf-set-selections
                sudo dpkg-reconfigure -f noninteractive unattended-upgrades 2>/dev/null || true
                sudo sed -i '/^Unattended-Upgrade::SyslogEnable/ d' /etc/apt/apt.conf.d/50unattended-upgrades
                echo 'Unattended-Upgrade::SyslogEnable "true";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null
                sudo systemctl restart unattended-upgrades || true
            ) >/dev/null 2>&1 &
            spinner $! "$(t spinner_setting_auto_updates)"
            show_success "$(t auto_updates_enabled)"
        fi
    fi

    show_success "$(t all_dependencies_installed)"
}

create_dir() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        show_info "$(t system_created_directory) $dir_path"
    fi
}

# Common preparation steps
prepare_installation() {
    local extra_deps=("$@")
    clear_screen
    install_dependencies "${extra_deps[@]}"

    if ! remove_previous_installation; then
        show_info "$(t system_installation_cancelled)"
        return 1
    fi

    mkdir -p "$REMNAWAVE_DIR/caddy"
    cd "$REMNAWAVE_DIR"
    return 0
}
