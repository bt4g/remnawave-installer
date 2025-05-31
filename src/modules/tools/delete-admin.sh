#!/bin/bash

# Admin deletion function
delete_admin() {
    clear
    local env_file="/opt/remnawave/.env"

    # Check if .env file exists
    if [ -f "$env_file" ]; then
        POSTGRES_USER=$(grep -oP '^POSTGRES_USER=\K.*' "$env_file")
        POSTGRES_PASSWORD=$(grep -oP '^POSTGRES_PASSWORD=\K.*' "$env_file")
        POSTGRES_DB=$(grep -oP '^POSTGRES_DB=\K.*' "$env_file")
    else
        echo -e "${RED}.env file not found at path $env_file${NC}"
        echo -e "${RED}Trying default database credentials${NC}"
        POSTGRES_USER="postgres"
        POSTGRES_PASSWORD="postgres"
        POSTGRES_DB="postgres"
    fi

    local CONTAINER_NAME="remnawave-db"
    local TABLE_NAME="admin"

    # Check if container is running
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${RED}Container $CONTAINER_NAME is not running!${NC}"
        echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
        read -r
        return 1
    fi

    echo -e "${YELLOW}You are about to delete the superadmin record from table $TABLE_NAME${NC}"
    echo
    read -p "Continue? (y/yes): " CONFIRM

    if [[ "${CONFIRM,,}" != "y" && "${CONFIRM,,}" != "yes" ]]; then
        echo
        echo -e "${YELLOW}Operation cancelled${NC}"
        echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
        read -r
        return 0
    fi

    local SQL_QUERY="DELETE FROM $TABLE_NAME WHERE ctid IN (SELECT ctid FROM $TABLE_NAME LIMIT 1);"

    echo
    echo "Deleting superadmin from table $TABLE_NAME..."
    local RESULT=$(docker exec $CONTAINER_NAME psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$SQL_QUERY")

    if [[ $? -eq 0 ]]; then
        if [[ $RESULT == *"DELETE 0"* ]]; then
            echo
            echo -e "${YELLOW}No superadmin records found in table $TABLE_NAME${NC}"
        else
            echo -e "${GREEN}Record successfully deleted${NC}"
        fi
    else
        echo
        echo -e "${RED}Error deleting record${NC}"
    fi

    echo
    echo -e "${BOLD_YELLOW}Press Enter to return to menu...${NC}"
    read -r
}
