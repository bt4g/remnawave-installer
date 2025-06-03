#!/bin/bash

# ===================================================================================
#                           INTERNATIONALIZATION FUNCTIONS
# ===================================================================================

# Initialize translations arrays for each language
declare -A TRANSLATIONS_EN
declare -A TRANSLATIONS_RU

# Get translated text by key
t() {
    local key="$1"
    local value=""

    # Get the value from the appropriate language array
    case "$LANG_CODE" in
        "ru")
            value="${TRANSLATIONS_RU[$key]:-}"
            ;;
        "en"|*)
            value="${TRANSLATIONS_EN[$key]:-}"
            ;;
    esac

    # Return the translation or show missing key
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "[$key]" # Show key if no translation found
    fi
}
