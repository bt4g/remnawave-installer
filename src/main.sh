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

main() {

    while true; do
    draw_info_box "Remnawave Panel" "Automatic installation by uphantom"

        echo -e "${BOLD_BLUE_MENU}Please select a component to install:${NC}"
        echo
        echo -e "  ${GREEN}1. ${NC}Install panel"
        echo -e "  ${GREEN}2. ${NC}Install node"
        echo -e "  ${GREEN}3. ${NC}Simple installation (panel + node)"
        echo -e "  ${GREEN}4. ${NC}Restart panel"
        echo -e "  ${GREEN}5. ${NC}Enable BBR"
        echo -e "  ${GREEN}6. ${NC}Exit"
        echo
        echo -ne "${BOLD_BLUE_MENU}Select an option (1-6): ${NC}"
        read choice

        case $choice in
        1)
            install_panel
            ;;
        2)
            setup_node
            ;;
        3)
            install_panel_all_in_one
            ;;
        4)
            restart_panel
            ;;
        5)
            enable_bbr
            ;;
        6)
            echo "Done."
            break
            ;;
        *)
            clear
            draw_info_box "Remnawave Panel" "Advanced configuration $VERSION"
            echo -e "${BOLD_RED}Invalid choice, please try again.${NC}"
            sleep 1
            ;;
        esac
    done
}

# Run main function
main
