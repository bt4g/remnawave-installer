#!/bin/bash

# ===================================================================================
#                                VALIDATION FUNCTIONS
# ===================================================================================

# Validate an IP address
validate_ip() {
    local input="$1"

    # Trim spaces
    input=$(echo "$input" | tr -d ' ')

    # If empty, fail
    if [ -z "$input" ]; then
        return 1
    fi

    # Check for IP pattern
    if [[ $input =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Validate each octet is <= 255
        IFS='.' read -r -a octets <<<"$input"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        echo "$input"
        return 0
    fi

    return 1
}

# Validate a domain name
validate_domain_name() {
    local input="$1"
    local max_length="${2:-253}" # Maximum domain length by standard

    # Trim spaces
    input=$(echo "$input" | tr -d ' ')

    # If empty, fail
    if [ -z "$input" ]; then
        return 1
    fi

    # Check length
    if [ ${#input} -gt $max_length ]; then
        return 1
    fi

    # Domain pattern validation - must contain at least one dot and not start/end with dot or dash
    if [[ $input =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$ ]] &&
        [[ ! $input =~ \.\. ]]; then
        echo "$input"
        return 0
    fi

    return 1
}

# Validate either an IP address or domain name
validate_domain() {
    local input="$1"
    local max_length="${2:-253}"

    # Try as IP first
    local result=$(validate_ip "$input")
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    # Try as domain name
    result=$(validate_domain_name "$input" "$max_length")
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    return 1
}

# Request numeric value with validation
prompt_number() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"
    local min="${3:-1}"
    local max="${4:-}"

    local number
    while true; do
        echo -ne "${prompt_color}${prompt_text}: ${NC}" >&2
        read number
        echo >&2

        # Number validation
        if [[ "$number" =~ ^[0-9]+$ ]]; then
            if [ -n "$min" ] && [ "$number" -lt "$min" ]; then
                echo -e "${BOLD_RED}$(t validation_value_min) ${min}.${NC}" >&2
                continue
            fi

            if [ -n "$max" ] && [ "$number" -gt "$max" ]; then
                echo -e "${BOLD_RED}$(t validation_value_max) ${max}.${NC}" >&2
                continue
            fi

            break
        else
            echo -e "${BOLD_RED}$(t validation_enter_numeric)${NC}" >&2
        fi
    done

    echo "$number"
}

# Validate SSL certificate format
validate_ssl_certificate() {
    local certificate="$1"

    # Check if certificate is empty
    if [ -z "$certificate" ]; then
        return 1
    fi

    # Check if certificate starts with SSL_CERT=
    if [[ ! "$certificate" =~ ^SSL_CERT= ]]; then
        return 1
    fi

    # Extract the value part (everything after SSL_CERT=)
    local cert_value="${certificate#SSL_CERT=}"

    # Remove surrounding quotes if present
    cert_value="${cert_value#\"}"
    cert_value="${cert_value%\"}"

    # Check if the value is not empty
    if [ -z "$cert_value" ]; then
        return 1
    fi

    # Check if it's valid base64
    if ! echo "$cert_value" | base64 -d >/dev/null 2>&1; then
        return 1
    fi

    # Try to decode and check if it's valid JSON
    local decoded_json
    if ! decoded_json=$(echo "$cert_value" | base64 -d 2>/dev/null); then
        return 1
    fi

    # Check if decoded content is valid JSON and contains required fields
    if ! echo "$decoded_json" | jq -e '.nodeCertPem and .nodeKeyPem and .caCertPem and .jwtPublicKey' >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

simple_read_domain_or_ip() {
    local prompt="$1"
    local default_value="$2"
    local validation_type="${3:-both}" # Can be 'domain_only', 'ip_only', or 'both'
    local result=""
    local attempts=0
    local max_attempts=10
    while [ $attempts -lt $max_attempts ]; do
        if [ -n "$default_value" ]; then
            echo -ne "${ORANGE}${prompt} [$default_value]: ${NC}" >&2
        else
            echo -ne "${ORANGE}${prompt}: ${NC}" >&2
        fi
        read input
        echo >&2

        if [ -z "$input" ] && [ -n "$default_value" ]; then
            result="$default_value"
            break
        fi
        if [ -z "$input" ]; then
            echo -e "${BOLD_RED}$(t validation_input_empty)${NC}" >&2
            ((attempts++))
            continue
        fi
        if [ "$validation_type" = "ip_only" ]; then
            result=$(validate_ip "$input")
            local status=$?
            if [ $status -eq 0 ]; then
                break
            else
                echo -e "${BOLD_RED}$(t validation_invalid_ip)${NC}" >&2
            fi
        elif [ "$validation_type" = "domain_only" ]; then
            result=$(validate_domain_name "$input")
            local status=$?
            if [ $status -eq 0 ]; then
                break
            else
                echo -e "${BOLD_RED}$(t validation_invalid_domain)${NC}" >&2
                echo -e "${BOLD_RED}$(t validation_use_only_letters)${NC}" >&2
            fi
        else
            result=$(validate_domain "$input")
            local status=$?
            if [ $status -eq 0 ]; then
                break
            else
                echo -e "${BOLD_RED}$(t validation_invalid_domain_ip)${NC}" >&2
                echo -e "${BOLD_RED}$(t validation_domain_format)${NC}" >&2
                echo -e "${BOLD_RED}$(t validation_ip_format)${NC}" >&2
            fi
        fi
        ((attempts++))
    done
    if [ $attempts -eq $max_attempts ]; then
        if [ -n "$default_value" ]; then
            echo -e "${BOLD_RED}$(t validation_max_attempts_default) $default_value${NC}" >&2
            result="$default_value"
        else
            echo -e "${BOLD_RED}$(t validation_max_attempts_no_input)${NC}" >&2
            echo -e "${BOLD_RED}$(t validation_cannot_continue)${NC}" >&2
            return 1
        fi
    fi
    echo "$result"
}
