#!/bin/bash

# Root privileges check
if [ "$(id -u)" -ne 0 ]; then
    echo "$(t error_root_required)"
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
    echo -e "${BOLD_GREEN}$(t main_menu_title)${VERSION}${NC}"
    echo -e "${GREEN}$(t main_menu_script_branch)${NC} ${BLUE}$INSTALLER_BRANCH${NC} | ${GREEN}$(t main_menu_panel_branch)${NC} ${BLUE}$REMNAWAVE_BRANCH${NC}"
    echo
    echo -e "${GREEN}1.${NC} $(t main_menu_install_components)"
    echo
    echo -e "${GREEN}2.${NC} $(t main_menu_update_components)"
    echo -e "${GREEN}3.${NC} $(t main_menu_restart_panel)"
    echo -e "${GREEN}4.${NC} $(t main_menu_remove_panel)"
    echo -e "${GREEN}5.${NC} $(t main_menu_rescue_cli)"
    echo -e "${GREEN}6.${NC} $(t main_menu_show_credentials)"
    echo
    echo -e "${GREEN}7.${NC} $(get_bbr_menu_text)"
    echo -e "${GREEN}8.${NC} $(t main_menu_warp_integration)"
    echo
    echo -e "${GREEN}0.${NC} $(t main_menu_exit)"
    echo
    echo -ne "${BOLD_BLUE_MENU}$(t main_menu_select_option) ${NC}"
}

# Show installation submenu
show_installation_menu() {
    clear
    echo -e "${BOLD_GREEN}$(t install_menu_title)${NC}"
    echo
    echo -e "${YELLOW}$(t install_menu_panel_only)${NC}"
    echo -e "${GREEN}1.${NC} $(t install_menu_panel_full_security)"
    echo -e "${GREEN}2.${NC} $(t install_menu_panel_simple_security)"
    echo
    echo -e "${YELLOW}$(t install_menu_node_only)${NC}"
    echo -e "${GREEN}3.${NC} $(t install_menu_node_separate)"
    echo
    echo -e "${YELLOW}$(t install_menu_all_in_one)${NC}"
    echo -e "${GREEN}4.${NC} $(t install_menu_panel_node_full)"
    echo -e "${GREEN}5.${NC} $(t install_menu_panel_node_simple)"
    echo
    echo -e "${GREEN}0.${NC} $(t install_menu_back)"
    echo
    echo -ne "${BOLD_BLUE_MENU}$(t main_menu_select_option) ${NC}"
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
            echo -e "${BOLD_RED}$(t error_invalid_choice)${NC}"
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
            handle_update_menu
            ;;
        3)
            restart_panel
            ;;
        4)
            remove_previous_installation true
            ;;
        5)
            run_remnawave_cli
            ;;
        6)
            show_panel_credentials
            ;;
        7)
            toggle_bbr
            ;;
        8)
            add_warp_integration
            ;;
        0)
            echo "$(t exiting)"
            break
            ;;
        *)
            clear
            echo -e "${BOLD_RED}$(t error_invalid_choice)${NC}"
            sleep 1
            ;;
        esac
    done
}

# Run main function
main
