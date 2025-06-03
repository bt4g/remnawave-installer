#!/bin/bash

# ===================================================================================
#                                MISCELLANEOUS FUNCTIONS
# ===================================================================================

# Generate QR code for URL
generate_qr_code() {
    local url="$1"
    local title="${2:-QR Code}"

    if [ -z "$url" ]; then
        return 1
    fi

    # Check if qrencode is available
    if command -v qrencode &>/dev/null; then
        echo -e "\033[1m$title:\033[0m"
        echo

        local qr_output=$(qrencode -t ANSIUTF8 "$url" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$qr_output" ]; then
            echo "$qr_output" | while IFS= read -r line; do
                printf "    %s\n" "$line"
            done
        else
            echo "$(t misc_qr_generation_failed)"
        fi
        echo
    else
        :
    fi
}
