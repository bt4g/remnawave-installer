#!/bin/bash

# Run Remnawave CLI function
run_remnawave_cli() {
    echo

    # Check if remnawave container is running
    if ! docker ps --format '{{.Names}}' | grep -q '^remnawave$'; then
        show_error "$(t cli_container_not_running)"
        echo -e "${YELLOW}$(t cli_ensure_panel_running)${NC}"
        echo
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Save current file descriptors
    exec 3>&1 4>&2
    exec >/dev/tty 2>&1

    # Run the CLI
    if docker exec -it -e TERM=xterm-256color remnawave remnawave; then
        echo
        show_success "$(t cli_session_completed)"
    else
        echo
        show_error "$(t cli_session_failed)"
        exec 1>&3 2>&4
        echo
        echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
        read -r
        return 0
    fi

    # Restore file descriptors
    exec 1>&3 2>&4

    echo
    echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
    read -r
}
