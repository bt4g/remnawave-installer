#!/bin/bash

# Usage: sudo bash -c "$(curl -sL URL)" @ --lang=ru

if [[ "$1" == "@" ]]; then
    shift
fi

TEMP_SCRIPT=$(mktemp /tmp/remnawave_installer_XXXXXX.sh)

if ! curl -sL "https://raw.githubusercontent.com/xxphantom/remnawave-installer/refs/heads/dev/dist/install_remnawave.sh" -o "$TEMP_SCRIPT"; then
    echo "Error: Failed to download installer script"
    rm -f "$TEMP_SCRIPT" 2>/dev/null
    exit 1
fi

chmod +x "$TEMP_SCRIPT"
exec bash "$TEMP_SCRIPT" "$@"
