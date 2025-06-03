#!/bin/bash

# ===================================================================================
#                                DISPLAY FUNCTIONS
# ===================================================================================

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

show_success() {
    local message="$1"
    local output_fd="${2:-1}" # Default to stdout (1)
    echo -e "${BOLD_GREEN}✓ ${message}${NC}" >&$output_fd
    echo >&$output_fd
}

show_error() {
    local message="$1"
    local output_fd="${2:-2}" # Default to stderr (2)
    echo -e "${BOLD_RED}✗ ${message}${NC}" >&$output_fd
    echo >&$output_fd
}

show_warning() {
    local message="$1"
    local output_fd="${2:-2}" # Default to stderr (2)
    echo -e "${BOLD_YELLOW}⚠  ${message}${NC}" >&$output_fd
    echo >&$output_fd
}

show_info() {
    local message="$1"
    local color="${2:-$ORANGE}"
    local output_fd="${3:-2}" # Default to stderr (2)
    echo -e "${color}${message}${NC}" >&$output_fd
    echo >&$output_fd
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
    for ((i = 0; i < count; i++)); do
        echo -ne "${progress_char}"
        sleep 0.5
    done
    echo
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
