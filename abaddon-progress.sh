#!/usr/bin/env bash
# Abaddon Progress - Modern terminal UX helpers
# Terminal-safe progress indicators and rich formatting

# Guard against multiple loads
[[ -n "${ABADDON_PROGRESS_LOADED:-}" ]] && return 0
readonly ABADDON_PROGRESS_LOADED=1

# Require abaddon-core for logging
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-progress.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

# Terminal capability detection
TERM_COLORS=0
TERM_INTERACTIVE=false
TERM_WIDTH=80
TERM_SUPPORTS_UNICODE=false

detect_terminal_features() {
    # Color support
    if command -v tput >/dev/null 2>&1; then
        TERM_COLORS=$(tput colors 2>/dev/null || echo 0)
    else
        TERM_COLORS=8  # Reasonable default
    fi
    
    # Interactive terminal detection
    if [[ -t 1 ]] && [[ -t 2 ]]; then
        TERM_INTERACTIVE=true
    else
        TERM_INTERACTIVE=false
    fi
    
    # Terminal width
    if command -v tput >/dev/null 2>&1; then
        TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
    elif [[ -n "${COLUMNS:-}" ]]; then
        TERM_WIDTH="$COLUMNS"
    else
        TERM_WIDTH=80
    fi
    
    # Unicode support detection
    if [[ "${LANG:-}" == *"UTF-8"* ]] || [[ "${LC_ALL:-}" == *"UTF-8"* ]]; then
        TERM_SUPPORTS_UNICODE=true
    else
        TERM_SUPPORTS_UNICODE=false
    fi
    
    log_debug "Terminal: ${TERM_COLORS} colors, width=${TERM_WIDTH}, interactive=${TERM_INTERACTIVE}, unicode=${TERM_SUPPORTS_UNICODE}"
}

# Spinner animation frames
declare -a SPINNER_FRAMES_BASIC=('|' '/' '-' '\')
declare -a SPINNER_FRAMES_UNICODE=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
declare -a SPINNER_FRAMES_DOTS=('⠁' '⠂' '⠄' '⡀' '⡈' '⡐' '⡠' '⣀' '⣁' '⣂' '⣄' '⣌' '⣔' '⣤' '⣥' '⣦' '⣮' '⣶' '⣷' '⣿')

# Get appropriate spinner frames
get_spinner_frames() {
    local style="${1:-auto}"
    
    case "$style" in
        basic)
            echo "${SPINNER_FRAMES_BASIC[@]}"
            ;;
        unicode)
            if [[ "$TERM_SUPPORTS_UNICODE" == "true" ]]; then
                echo "${SPINNER_FRAMES_UNICODE[@]}"
            else
                echo "${SPINNER_FRAMES_BASIC[@]}"
            fi
            ;;
        dots)
            if [[ "$TERM_SUPPORTS_UNICODE" == "true" ]]; then
                echo "${SPINNER_FRAMES_DOTS[@]}"
            else
                echo "${SPINNER_FRAMES_BASIC[@]}"
            fi
            ;;
        auto|*)
            if [[ "$TERM_SUPPORTS_UNICODE" == "true" ]] && [[ "$TERM_COLORS" -gt 8 ]]; then
                echo "${SPINNER_FRAMES_UNICODE[@]}"
            else
                echo "${SPINNER_FRAMES_BASIC[@]}"
            fi
            ;;
    esac
}

# Show spinner for background process
show_spinner() {
    local message="$1"
    local pid="$2"
    local style="${3:-auto}"
    local delay=0.1
    
    # Non-interactive fallback
    if [[ "$TERM_INTERACTIVE" == "false" ]]; then
        echo "$message..."
        wait "$pid"
        return $?
    fi
    
    # Get appropriate spinner frames
    local frames
    read -ra frames <<< "$(get_spinner_frames "$style")"
    
    local i=0
    local start_time
    start_time=$(date +%s)
    
    # Hide cursor
    printf '\033[?25l'
    
    while kill -0 "$pid" 2>/dev/null; do
        local current_time elapsed
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [[ "$TERM_COLORS" -gt 8 ]]; then
            printf "\r${CYAN}%s${NC} %s ${YELLOW}(%ds)${NC}" \
                "${frames[i]}" "$message" "$elapsed"
        else
            printf "\r%s %s (%ds)" \
                "${frames[i]}" "$message" "$elapsed"
        fi
        
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep $delay
    done
    
    # Show cursor and clear line
    printf '\033[?25h\r'
    
    # Check if process succeeded
    if wait "$pid"; then
        if [[ "$TERM_COLORS" -gt 8 ]]; then
            printf "${GREEN}✓${NC} %s ${YELLOW}(%ds)${NC}\n" "$message" "$elapsed"
        else
            printf "✓ %s (%ds)\n" "$message" "$elapsed"
        fi
        return 0
    else
        local exit_code=$?
        if [[ "$TERM_COLORS" -gt 8 ]]; then
            printf "${RED}✗${NC} %s ${YELLOW}(%ds)${NC}\n" "$message" "$elapsed"
        else
            printf "✗ %s (%ds)\n" "$message" "$elapsed"
        fi
        return $exit_code
    fi
}

# Progress bar for operations with known progress
show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    local width="${4:-40}"
    
    # Non-interactive fallback
    if [[ "$TERM_INTERACTIVE" == "false" ]]; then
        local percent=$((current * 100 / total))
        echo "Progress: $current/$total ($percent%) - $message"
        return 0
    fi
    
    # Calculate progress
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Create progress bar
    local bar=""
    if [[ "$TERM_SUPPORTS_UNICODE" == "true" ]]; then
        # Unicode progress bar
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=0; i<empty; i++)); do bar+="░"; done
    else
        # ASCII progress bar
        for ((i=0; i<filled; i++)); do bar+="="; done
        for ((i=0; i<empty; i++)); do bar+="-"; done
    fi
    
    if [[ "$TERM_COLORS" -gt 8 ]]; then
        printf "\r${BLUE}[${NC}%s${BLUE}]${NC} %3d%% %s" "$bar" "$percent" "$message"
    else
        printf "\r[%s] %3d%% %s" "$bar" "$percent" "$message"
    fi
    
    # Add newline if complete
    if [[ "$current" -eq "$total" ]]; then
        echo
    fi
}

# Rich table formatting with eza-style aesthetics
create_table() {
    local -a headers=("$@")
    local num_cols=${#headers[@]}
    
    # Non-interactive fallback
    if [[ "$TERM_INTERACTIVE" == "false" ]] || [[ "$TERM_COLORS" -lt 8 ]]; then
        printf "%-15s" "${headers[@]}"
        echo
        for ((i=0; i<num_cols; i++)); do
            printf "%-15s" "---------------"
        done
        echo
        return 0
    fi
    
    # Calculate column widths
    local -a col_widths
    for ((i=0; i<num_cols; i++)); do
        col_widths[i]=15  # Default width
    done
    
    # Unicode table if supported
    if [[ "$TERM_SUPPORTS_UNICODE" == "true" ]]; then
        # Top border
        printf "${CYAN}┌"
        for ((i=0; i<num_cols; i++)); do
            for ((j=0; j<${col_widths[i]}; j++)); do printf "─"; done
            if [[ $i -lt $((num_cols-1)) ]]; then printf "┬"; fi
        done
        printf "┐${NC}\n"
        
        # Header row
        printf "${CYAN}│${NC}"
        for ((i=0; i<num_cols; i++)); do
            printf "${BOLD}%-${col_widths[i]}s${NC}" "${headers[i]}"
            if [[ $i -lt $((num_cols-1)) ]]; then printf "${CYAN}│${NC}"; fi
        done
        printf "${CYAN}│${NC}\n"
        
        # Middle border
        printf "${CYAN}├"
        for ((i=0; i<num_cols; i++)); do
            for ((j=0; j<${col_widths[i]}; j++)); do printf "─"; done
            if [[ $i -lt $((num_cols-1)) ]]; then printf "┼"; fi
        done
        printf "┤${NC}\n"
    else
        # ASCII table fallback
        printf "+"
        for ((i=0; i<num_cols; i++)); do
            for ((j=0; j<${col_widths[i]}; j++)); do printf "-"; done
            printf "+"
        done
        echo
        
        printf "|"
        for ((i=0; i<num_cols; i++)); do
            printf "%-${col_widths[i]}s|" "${headers[i]}"
        done
        echo
        
        printf "+"
        for ((i=0; i<num_cols; i++)); do
            for ((j=0; j<${col_widths[i]}; j++)); do printf "-"; done
            printf "+"
        done
        echo
    fi
}

# Add table row
add_table_row() {
    local -a values=("$@")
    local num_cols=${#values[@]}
    
    # Non-interactive fallback
    if [[ "$TERM_INTERACTIVE" == "false" ]] || [[ "$TERM_COLORS" -lt 8 ]]; then
        printf "%-15s" "${values[@]}"
        echo
        return 0
    fi
    
    if [[ "$TERM_SUPPORTS_UNICODE" == "true" ]]; then
        printf "${CYAN}│${NC}"
        for ((i=0; i<num_cols; i++)); do
            printf "%-15s" "${values[i]}"
            if [[ $i -lt $((num_cols-1)) ]]; then printf "${CYAN}│${NC}"; fi
        done
        printf "${CYAN}│${NC}\n"
    else
        printf "|"
        for ((i=0; i<num_cols; i++)); do
            printf "%-15s|" "${values[i]}"
        done
        echo
    fi
}

# Close table
close_table() {
    local num_cols="${1:-3}"
    
    # Non-interactive fallback
    if [[ "$TERM_INTERACTIVE" == "false" ]] || [[ "$TERM_COLORS" -lt 8 ]]; then
        return 0
    fi
    
    if [[ "$TERM_SUPPORTS_UNICODE" == "true" ]]; then
        printf "${CYAN}└"
        for ((i=0; i<num_cols; i++)); do
            for ((j=0; j<15; j++)); do printf "─"; done
            if [[ $i -lt $((num_cols-1)) ]]; then printf "┴"; fi
        done
        printf "┘${NC}\n"
    else
        printf "+"
        for ((i=0; i<num_cols; i++)); do
            for ((j=0; j<15; j++)); do printf "-"; done
            printf "+"
        done
        echo
    fi
}

# Status indicators with icons
status_icon() {
    local status="$1"
    local use_color="${2:-true}"
    
    case "$status" in
        success|ok|pass|✓)
            if [[ "$use_color" == "true" ]] && [[ "$TERM_COLORS" -gt 8 ]]; then
                echo -e "${GREEN}✓${NC}"
            else
                echo "✓"
            fi
            ;;
        error|fail|✗)
            if [[ "$use_color" == "true" ]] && [[ "$TERM_COLORS" -gt 8 ]]; then
                echo -e "${RED}✗${NC}"
            else
                echo "✗"
            fi
            ;;
        warning|warn|⚠)
            if [[ "$use_color" == "true" ]] && [[ "$TERM_COLORS" -gt 8 ]]; then
                echo -e "${YELLOW}⚠${NC}"
            else
                echo "!"
            fi
            ;;
        info|ℹ)
            if [[ "$use_color" == "true" ]] && [[ "$TERM_COLORS" -gt 8 ]]; then
                echo -e "${BLUE}ℹ${NC}"
            else
                echo "i"
            fi
            ;;
        working|...)
            if [[ "$TERM_SUPPORTS_UNICODE" == "true" ]]; then
                echo "⠋"
            else
                echo "..."
            fi
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Rich formatting helpers
format_bold() {
    if [[ "$TERM_COLORS" -gt 0 ]]; then
        echo -e "${BOLD}$*${NC}"
    else
        echo "$*"
    fi
}

format_dim() {
    if [[ "$TERM_COLORS" -gt 8 ]]; then
        echo -e "\033[2m$*${NC}"
    else
        echo "$*"
    fi
}

format_underline() {
    if [[ "$TERM_COLORS" -gt 0 ]]; then
        echo -e "\033[4m$*${NC}"
    else
        echo "$*"
    fi
}

# Clear current line (for updates)
clear_line() {
    if [[ "$TERM_INTERACTIVE" == "true" ]]; then
        printf '\r\033[K'
    fi
}

# Section headers with formatting
section_header() {
    local title="$1"
    local level="${2:-1}"
    
    case "$level" in
        1)
            if [[ "$TERM_COLORS" -gt 8 ]]; then
                echo -e "\n${BOLD}${BLUE}=== $title ===${NC}\n"
            else
                echo -e "\n=== $title ===\n"
            fi
            ;;
        2)
            if [[ "$TERM_COLORS" -gt 8 ]]; then
                echo -e "${CYAN}$title${NC}"
            else
                echo "$title"
            fi
            ;;
        3)
            if [[ "$TERM_COLORS" -gt 8 ]]; then
                echo -e "${YELLOW}$title:${NC}"
            else
                echo "$title:"
            fi
            ;;
        *)
            echo "$title"
            ;;
    esac
}

# Initialize terminal features on module load
detect_terminal_features

log_debug "Abaddon Progress module loaded successfully (interactive=$TERM_INTERACTIVE, colors=$TERM_COLORS)"