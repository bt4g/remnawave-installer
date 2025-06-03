#!/bin/bash

# Show panel credentials function
show_panel_credentials() {
    echo
    echo -e "${BOLD_GREEN}$(t credentials_panel_title)${NC}"
    echo

    local credentials_file="/opt/remnawave/credentials.txt"

    # Check if credentials file exists
    if [ -f "$credentials_file" ]; then
        echo -e "${BOLD_GREEN}$(t credentials_found)${NC}"
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
    else
        echo -e "${BOLD_RED}$(t credentials_not_found)${NC}"
        echo
        echo -e "${YELLOW}$(t credentials_file_location) ${ORANGE}$credentials_file${NC}"
        echo
        echo -e "${YELLOW}$(t credentials_reasons)${NC}"
        echo -e "  • $(t credentials_reason_not_installed)"
        echo -e "  • $(t credentials_reason_incomplete)"
        echo -e "  • $(t credentials_reason_deleted)"
        echo
        echo -e "${YELLOW}$(t credentials_try_install)${NC}"
    fi

    echo
    echo -e "${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
    read -r
}
