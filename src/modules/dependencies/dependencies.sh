#!/bin/bash

# Function to check and install dependencies
check_and_install_dependency() {
    local packages=("$@")
    local failed=false

    for package_name in "${packages[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q "install ok installed"; then
            show_info "Installing package $package_name..."
            sudo apt-get install -y "$package_name" >/dev/null 2>&1

            if ! dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q "install ok installed"; then
                show_error "Error: Failed to install $package_name. Please install it manually."
                show_error "The script requires the $package_name package to work."
                sleep 2
                failed=true
            else
                show_info "Package $package_name installed successfully."
            fi
        fi
    done

    if [ "$failed" = true ]; then
        return 1
    fi
    return 0
}

# Install common dependencies for all components
install_dependencies() {
    show_info "Checking dependencies..."

    # Update package lists
    (sudo apt-get update >/dev/null 2>&1) &
    spinner $! "Updating package lists"

    # Install lsb-release if it's missing – it's needed to determine the distribution
    if ! command -v lsb_release &>/dev/null; then
        (sudo apt-get install -y lsb-release >/dev/null 2>&1) &
        spinner $! "Installing lsb-release"
    fi

    # Check and install required packages
    check_and_install_dependency "curl" "jq" "make" "dnsutils" || {
        show_error "Error: Not all required dependencies were installed."
        return 1
    }

    # Check if Docker is installed
    if command -v docker &>/dev/null && docker --version &>/dev/null; then
        return 0
    else
        (sudo apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc >/dev/null 2>&1) &
        spinner $! "Removing old Docker versions"

        show_info "Installing Docker and other required packages..."

        # Install prerequisite dependencies
        (sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common >/dev/null 2>&1) &
        spinner $! "Installing Docker prerequisites"

        # Create directory to store keys
        sudo mkdir -p /etc/apt/keyrings

        # Add the official Docker GPG key
        # Key file path – /etc/apt/keyrings/docker.gpg
        (curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 2>/dev/null) &
        spinner $! "Adding Docker GPG key" ||
            {
                # If it fails, try deleting the file and adding the key again
                sudo rm -f /etc/apt/keyrings/docker.gpg
                (curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
                    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null) &
                spinner $! "Retrying Docker GPG key installation"
            }

        # Set key file permissions
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Determine distribution and repository
        DIST_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]') # ubuntu or debian
        CODENAME=$(lsb_release -cs)                             # jammy, focal, bookworm, etc.

        if [ "$DIST_ID" = "ubuntu" ]; then
            REPO_URL="https://download.docker.com/linux/ubuntu"
        elif [ "$DIST_ID" = "debian" ]; then
            REPO_URL="https://download.docker.com/linux/debian"
        else
            show_error "Unsupported distribution: $DIST_ID"
            exit 1
        fi

        # Add the Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $REPO_URL $CODENAME stable" |
            sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

        # Update package index
        (sudo apt-get update >/dev/null 2>&1) &
        spinner $! "Updating package index"

        # Install Docker Engine, Docker CLI, containerd, Buildx and Compose plugins
        (sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1) &
        spinner $! "Installing Docker packages"

        # Check if the docker group exists, create if not
        if ! getent group docker >/dev/null; then
            show_info "Creating docker group..."
            sudo groupadd docker
        fi

        # Add current user to the docker group (to use Docker without sudo)
        sudo usermod -aG docker "$USER"

        # Check installation success
        if command -v docker &>/dev/null; then
            echo -e "${GREEN}Docker installed successfully: $(docker --version)${NC}"
            echo ""
        else
            echo -e "${RED}Docker installation failed${NC}"
            echo ""
            exit 1
        fi
    fi
}
