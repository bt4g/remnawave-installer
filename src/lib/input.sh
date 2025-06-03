#!/bin/bash

# ===================================================================================
#                                INPUT FUNCTIONS
# ===================================================================================

# Request input with preset text and color
prompt_input() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"

    echo -ne "${prompt_color}${prompt_text}${NC}" >&2
    read input_value
    echo >&2

    echo "$input_value"
}

# Request password input (with echo disabled)
prompt_password() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"

    echo -ne "${prompt_color}${prompt_text}${NC}" >&2
    stty -echo
    read password_value
    stty echo
    echo >&2

    echo "$password_value"
}

# Request yes/no option selection
prompt_yes_no() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"
    local default="${3:-}"

    local prompt_suffix="$(t prompt_yes_no_suffix)"
    [ -n "$default" ] && prompt_suffix="$(t prompt_yes_no_default_suffix)$default]: "

    while true; do
        echo -ne "${prompt_color}${prompt_text}${prompt_suffix}${NC}" >&2

        while read -t 0.1; do read -n 1; done

        read answer
        echo >&2

        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

        [ -z "$answer" ] && answer="$default"

        if [ "$answer" = "y" ] || [ "$answer" = "yes" ]; then
            return 0
        elif [ "$answer" = "n" ] || [ "$answer" = "no" ]; then
            return 1
        else
            echo -e "${BOLD_RED}$(t error_enter_yn)${NC}" >&2
            echo ''
        fi
    done
}

# Request selection from numbered menu
prompt_menu_option() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"
    local min="${3:-1}"
    local max="$4"

    local selected_option
    while true; do
        echo -ne "${prompt_color}${prompt_text} (${min}-${max}): ${NC}" >&2
        read selected_option
        echo >&2

        # Validation of selection
        if [[ "$selected_option" =~ ^[0-9]+$ ]] &&
            [ "$selected_option" -ge "$min" ] &&
            [ "$selected_option" -le "$max" ]; then
            break
        else
            echo -e "${BOLD_RED}$(t error_enter_number_between) ${min} and ${max}.${NC}" >&2
        fi
    done

    echo "$selected_option"
}

# Validate password strength
validate_password_strength() {
    local password="$1"
    local min_length=${2:-8}

    local length=${#password}

    # Check length
    if [ "$length" -lt "$min_length" ]; then
        echo "$(t password_min_length) $min_length $(t password_min_length_suffix)"
        return 1
    fi

    # Check for digits
    if ! [[ "$password" =~ [0-9] ]]; then
        echo "$(t password_need_digit)"
        return 1
    fi

    # Check for lowercase letters
    if ! [[ "$password" =~ [a-z] ]]; then
        echo "$(t password_need_lowercase)"
        return 1
    fi

    # Check for uppercase letters
    if ! [[ "$password" =~ [A-Z] ]]; then
        echo "$(t password_need_uppercase)"
        return 1
    fi

    # Password passed all checks
    return 0
}

# Request password with confirmation and strength validation
prompt_secure_password() {
    local prompt_text="$1"
    local confirm_text="${2:-$(t auth_confirm_password)}"
    local min_length=${3:-8}

    local password1 password2 error_message

    while true; do
        # Request password
        password1=$(prompt_password "$prompt_text")

        # Check password strength
        error_message=$(validate_password_strength "$password1" "$min_length")
        if [ $? -ne 0 ]; then
            echo -e "${BOLD_RED}${error_message} $(t password_try_again)${NC}" >&2
            continue
        fi

        # Request password confirmation
        password2=$(prompt_password "$confirm_text")

        # Check password match
        if [ "$password1" = "$password2" ]; then
            break
        else
            echo -e "${BOLD_RED}$(t error_passwords_no_match)${NC}" >&2
        fi
    done

    echo "$password1"
}
