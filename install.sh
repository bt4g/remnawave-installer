#!/bin/bash

# Usage: sudo bash -c "$(curl -sL URL)" @ --lang=ru

if [[ "$1" == "@" ]]; then
    shift
fi

# Parse installer-branch parameter to determine which script to download
INSTALLER_BRANCH="${INSTALLER_BRANCH:-main}"
for arg in "$@"; do
    case $arg in
        --installer-branch=*)
            INSTALLER_BRANCH="${arg#*=}"
            ;;
        --installer-branch)
            # This would require looking at the next argument, but it's complex in this context
            # For now, we'll rely on the --installer-branch=value format
            ;;
    esac
done

TEMP_SCRIPT=$(mktemp /tmp/remnawave_installer_XXXXXX.sh)
if ! curl -sL "https://raw.githubusercontent.com/xxphantom/remnawave-installer/refs/heads/$INSTALLER_BRANCH/dist/install_remnawave.sh" -o "$TEMP_SCRIPT"; then
    echo "Error: Failed to download installer script"
    rm -f "$TEMP_SCRIPT" 2>/dev/null
    exit 1
fi

chmod +x "$TEMP_SCRIPT"
exec bash "$TEMP_SCRIPT" "$@"
