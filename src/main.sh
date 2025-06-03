#!/bin/bash

# Root privileges check
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (sudo)"
    exit 1
fi

clear

# ===================================================================================
# This file is intended ONLY for building the final script.
# To run, use ONLY the built script dist/install_remnawave.sh
# ===================================================================================

# Show main menu
show_main_menu() {
    clear
    echo -e "${BOLD_GREEN}Remnawave Panel Installer by uphantom v${VERSION}${NC}"
    echo
    echo -e "${GREEN}1.${NC} Install components"
    echo
    echo -e "${GREEN}2.${NC} Restart panel"
    echo -e "${GREEN}3.${NC} Remove panel"
    echo -e "${GREEN}4.${NC} Remnawave Rescue CLI [Reset admin]"
    echo -e "${GREEN}5.${NC} Show panel access credentials"
    echo
    echo -e "${GREEN}6.${NC} Enable BBR"
    echo
    echo -e "${GREEN}0.${NC} Exit"
    echo
    echo -ne "${BOLD_BLUE_MENU}Select option: ${NC}"
}

# Show installation submenu
show_installation_menu() {
    clear
    echo -e "${BOLD_GREEN}Install Components${NC}"
    echo
    echo -e "${YELLOW}Panel Only:${NC}"
    echo -e "${GREEN}1.${NC} Panel with FULL Caddy security (recommended)"
    echo -e "${GREEN}2.${NC} Panel with SIMPLE cookie security"
    echo
    echo -e "${YELLOW}Node Only:${NC}"
    echo -e "${GREEN}3.${NC} Node only (for separate server)"
    echo
    echo -e "${YELLOW}All-in-One:${NC}"
    echo -e "${GREEN}4.${NC} Panel + Node with FULL Caddy security"
    echo -e "${GREEN}5.${NC} Panel + Node with SIMPLE cookie security"
    echo
    echo -e "${GREEN}0.${NC} Back to main menu"
    echo
    echo -ne "${BOLD_BLUE_MENU}Select option: ${NC}"
}

# Handle installation menu
handle_installation_menu() {
    while true; do
        show_installation_menu
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
        0)
            return
            ;;
        *)
            clear
            echo -e "${BOLD_RED}Invalid choice, please try again.${NC}"
            sleep 1
            ;;
        esac
    done
}

main() {
    while true; do
        show_main_menu
        read choice

        case $choice in
        1)
            handle_installation_menu
            ;;
        2)
            restart_panel
            ;;
        3)
            remove_previous_installation true
            ;;
        4)
            run_remnawave_cli
            ;;
        5)
            show_panel_credentials
            ;;
        6)
            enable_bbr
            ;;
        0)
            echo "Exiting."
            break
            ;;
        *)
            clear
            echo -e "${BOLD_RED}Invalid choice, please try again.${NC}"
            sleep 1
            ;;
        esac
    done
}

# Run main function
main
