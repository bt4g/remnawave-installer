#!/bin/bash

# Show panel credentials function
show_panel_credentials() {
    clear
    draw_info_box "Panel Access Credentials" "Remnawave Panel Login Information"
    
    local credentials_file="/opt/remnawave/credentials.txt"
    
    # Check if credentials file exists
    if [ -f "$credentials_file" ]; then
        echo -e "${BOLD_GREEN}Panel access credentials found:${NC}"
        echo
        echo -e "${BOLD_BLUE_MENU}═══ CREDENTIALS ═══${NC}"
        echo
        
        # Display file content with proper formatting
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*$ ]]; then
                echo
            elif [[ "$line" =~ ^[[:space:]]*#.*$ ]] || [[ "$line" =~ ^[[:space:]]*\[.*\][[:space:]]*$ ]]; then
                # Headers and comments in yellow
                echo -e "${YELLOW}$line${NC}"
            elif [[ "$line" =~ .*:.*$ ]]; then
                # Key-value pairs: key in orange, value in green
                local key=$(echo "$line" | cut -d':' -f1)
                local value=$(echo "$line" | cut -d':' -f2-)
                echo -e "${ORANGE}$key:${GREEN}$value${NC}"
            else
                # Regular text in default color
                echo -e "${NC}$line"
            fi
        done < "$credentials_file"
        
        echo
        echo -e "${BOLD_BLUE_MENU}═══════════════════${NC}"
    else
        echo -e "${BOLD_RED}Credentials file not found!${NC}"
        echo
        echo -e "${YELLOW}The credentials file does not exist at: ${ORANGE}$credentials_file${NC}"
        echo
        echo -e "${YELLOW}This usually means:${NC}"
        echo -e "  • Panel is not installed yet"
        echo -e "  • Installation was not completed successfully"
        echo -e "  • Credentials file was manually deleted"
        echo
        echo -e "${YELLOW}Try installing the panel first using options 1, 2, 4, or 5 from the main menu.${NC}"
    fi
    
    echo
    echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
    read -r
}
