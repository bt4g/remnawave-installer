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

        # Installation section
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

        # Panel management section
        echo -e "  ${BOLD_BLUE_MENU}═══ PANEL MANAGEMENT ═══${NC}"
        echo
        echo -e "  ${GREEN}6. ${NC}Restart panel"
        echo -e "  ${GREEN}7. ${NC}Remove panel"
        echo -e "  ${GREEN}8. ${NC}Reset admin login and password"
        echo -e "  ${GREEN}9. ${NC}Show panel access credentials"
        echo

        # System management section
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

# Run main function
main
