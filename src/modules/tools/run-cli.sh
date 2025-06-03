#!/bin/bash

# Run Remnawave CLI function
run_remnawave_cli() {
    echo

    # Check if remnawave container is running
    if ! docker ps --format '{{.Names}}' | grep -q '^remnawave$'; then
        show_error "Remnawave container is not running!"
        echo -e "${YELLOW}Please make sure the panel is installed and running.${NC}"
        echo
        echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
        read -r
        return 1
    fi

    # Save current file descriptors
    exec 3>&1 4>&2
    exec > /dev/tty 2>&1

    # Run the CLI
    if docker exec -it -e TERM=xterm-256color remnawave remnawave; then
        echo
        show_success "CLI session completed successfully"
    else
        echo
        show_error "CLI session failed or was interrupted"
        exec 1>&3 2>&4
        echo
        echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
        read -r
        return 1
    fi

    # Restore file descriptors
    exec 1>&3 2>&4

    echo
    echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
    read -r
}
