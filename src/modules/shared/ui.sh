# Draw information box
draw_info_box() {
    local title="$1"
    local subtitle="$2"

    # Fixed block width for ideal alignment
    local width=54

    echo -e "${BOLD_GREEN}"
    # Top border
    printf "┌%s┐\n" "$(printf '─%.0s' $(seq 1 $width))"

    # Centring title
    local title_padding_left=$(((width - ${#title}) / 2))
    local title_padding_right=$((width - title_padding_left - ${#title}))
    printf "│%*s%s%*s│\n" "$title_padding_left" "" "$title" "$title_padding_right" ""

    # Centring subtitle
    local subtitle_padding_left=$(((width - ${#subtitle}) / 2))
    local subtitle_padding_right=$((width - subtitle_padding_left - ${#subtitle}))
    printf "│%*s%s%*s│\n" "$subtitle_padding_left" "" "$subtitle" "$subtitle_padding_right" ""

    # Empty line
    printf "│%*s│\n" "$width" ""

    # Version line - careful color handling
    local version_text="  • Version: "
    local version_value="$VERSION"
    local version_value_colored="${ORANGE}${version_value}${BOLD_GREEN}"
    local version_value_length=${#version_value}
    local remaining_space=$((width - ${#version_text} - version_value_length))
    printf "│%s%s%*s│\n" "$version_text" "$version_value_colored" "$remaining_space" ""

    # Empty line
    printf "│%*s│\n" "$width" ""

    # Bottom border
    printf "└%s┘\n" "$(printf '─%.0s' $(seq 1 $width))"
    echo -e "${NC}"
}

# Clear screen
clear_screen() {
    clear
}

# Display section header
draw_section_header() {
    local title="$1"
    local width=${2:-50}
    
    echo -e "${BOLD_RED}\033[1m┌$(printf '─%.0s' $(seq 1 $width))┐\033[0m${NC}"
    
    # Centring title
    local padding_left=$(((width - ${#title}) / 2))
    local padding_right=$((width - padding_left - ${#title}))
    echo -e "${BOLD_RED}\033[1m│$(printf ' %.0s' $(seq 1 $padding_left))$title$(printf ' %.0s' $(seq 1 $padding_right))│\033[0m${NC}"
    
    echo -e "${BOLD_RED}\033[1m└$(printf '─%.0s' $(seq 1 $width))┘\033[0m${NC}"
    echo
}

# Display menu options with numbering
draw_menu_options() {
    local options=("$@")
    local idx=1
    
    for option in "${options[@]}"; do
        echo -e "${ORANGE}$idx. $option${NC}"
        ((idx++))
    done
    echo
}

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
    
    local prompt_suffix=" (y/n): "
    [ -n "$default" ] && prompt_suffix=" (y/n) [$default]: "
    
    echo -ne "${prompt_color}${prompt_text}${prompt_suffix}${NC}" >&2
    read answer
    echo >&2
    
    # Convert to lowercase
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    
    # If empty, use default value
    [ -z "$answer" ] && answer="$default"
    
    if [ "$answer" = "y" ] || [ "$answer" = "yes" ]; then
        return 0
    else
        return 1
    fi
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
        if [[ "$selected_option" =~ ^[0-9]+$ ]] && \
           [ "$selected_option" -ge "$min" ] && \
           [ "$selected_option" -le "$max" ]; then
            break
        else
            echo -e "${BOLD_RED}Plfease enter a number between ${min} and ${max}.${NC}" >&2
        fi
    done
    
    echo "$selected_option"
}

show_success() {
    local message="$1"
    echo -e "${BOLD_GREEN}✓ ${message}${NC}"
    echo ""
}

show_error() {
    local message="$1"
    echo -e "${BOLD_RED}✗ ${message}${NC}"
    echo ""
}

show_warning() {
    local message="$1"
    echo -e "${BOLD_YELLOW}⚠  ${message}${NC}"
    echo ""
}

show_info() {
    local message="$1"
    local color="${2:-$ORANGE}"
    echo -e "${color}${message}${NC}"
    echo ""
}

show_info_e() {
    local message="$1"
    local color="${2:-$ORANGE}"
    echo -e "${color}${message}${NC}" >&2
    echo "" >&2
}

# Draw separator
draw_separator() {
    local width=${1:-50}
    local char=${2:-"-"}
    
    printf "%s\n" "$(printf "$char%.0s" $(seq 1 $width))"
}

# Display operation progress
show_progress() {
    local message="$1"
    local progress_char=${2:-"."}
    local count=${3:-3}
    
    echo -ne "${message}"
    for ((i=0; i<count; i++)); do
        echo -ne "${progress_char}"
        sleep 0.5
    done
    echo ""
}

# Request domain with validation
prompt_domain() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"
    
    local domain
    while true; do
        echo -ne "${prompt_color}${prompt_text}: ${NC}" >&2
        read domain
        echo >&2
        
        # Base domain validation (can be expanded)
        if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            break
        else
            echo -e "${BOLD_RED}Invalid domain format. Please try again.${NC}" >&2
        fi
    done
    
    echo "$domain"
    echo ""
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
                echo -e "${BOLD_RED}Value must be at least ${min}.${NC}" >&2
                continue
            fi
            
            if [ -n "$max" ] && [ "$number" -gt "$max" ]; then
                echo -e "${BOLD_RED}Value must be at most ${max}.${NC}" >&2
                continue
            fi
            
            break
        else
            echo -e "${BOLD_RED}Please enter a valid numeric value.${NC}" >&2
        fi
    done
    
    echo "$number"
}

# Display row with label and value
draw_info_row() {
    local label="$1"
    local value="$2"
    local label_color="${3:-$ORANGE}"
    local value_color="${4:-$GREEN}"
    local width=${5:-50}
    
    local label_display="${label_color}${label}:${NC}"
    local value_display="${value_color}${value}${NC}"
    
    echo -e "${label_display} ${value_display}"
}

# Center text
center_text() {
    local text="$1"
    local width=${2:-$(tput cols)}
    local padding_left=$(((width - ${#text}) / 2))
    
    printf "%${padding_left}s%s\n" "" "$text"
}

# Display completion message block
draw_completion_message() {
    local title="$1"
    local message="$2"
    local width=${3:-70}
    
    draw_separator "$width" "="
    center_text "$title" "$width"
    echo
    echo -e "$message"
    draw_separator "$width" "="
}

# Validate password strength
validate_password_strength() {
    local password="$1"
    local min_length=${2:-8}
    
    local length=${#password}
    
    # Check length
    if [ "$length" -lt "$min_length" ]; then
        echo "Password must contain at least $min_length characters."
        return 1
    fi
    
    # Check for digits
    if ! [[ "$password" =~ [0-9] ]]; then
        echo "Password must contain at least one digit."
        return 1
    fi
    
    # Check for lowercase letters
    if ! [[ "$password" =~ [a-z] ]]; then
        echo "Password must contain at least one lowercase letter."
        return 1
    fi
    
    # Check for uppercase letters
    if ! [[ "$password" =~ [A-Z] ]]; then
        echo "Password must contain at least one uppercase letter."
        return 1
    fi
    
    # Password passed all checks
    return 0
}

# Request password with confirmation and strength validation
prompt_secure_password() {
    local prompt_text="$1"
    local confirm_text="${2:-Please confirm your password}"
    local min_length=${3:-8}
    
    local password1 password2 error_message
    
    while true; do
        # Request password
        password1=$(prompt_password "$prompt_text")
        
        # Check password strength
        error_message=$(validate_password_strength "$password1" "$min_length")
        if [ $? -ne 0 ]; then
            echo -e "${BOLD_RED}${error_message} Please try again.${NC}" >&2
            continue
        fi
        
        # Request password confirmation
        password2=$(prompt_password "$confirm_text")
        
        # Check password match
        if [ "$password1" = "$password2" ]; then
            break
        else
            echo -e "${BOLD_RED}Passwords do not match. Please try again.${NC}" >&2
        fi
    done
    
    echo "$password1"
}

# Display spinner while command is running
spinner() {
    local pid=$1
    local text=$2
    local spinstr='⣷⣯⣟⡿⢿⣻⣽⣾'
    local text_code="$BOLD_GREEN"
    local bg_code=""
    local effect_code="\033[1m"
    local delay=0.12
    local reset_code="$NC"

    printf "${effect_code}${text_code}${bg_code}%s${reset_code}" "$text" >/dev/tty

    while kill -0 "$pid" 2>/dev/null; do
        for ((i = 0; i < ${#spinstr}; i++)); do
            printf "\r${effect_code}${text_code}${bg_code}[%s] %s${reset_code}" "$(echo -n "${spinstr:$i:1}")" "$text" >/dev/tty
            sleep $delay
        done
    done

    printf "\r\033[K" >/dev/tty
}
