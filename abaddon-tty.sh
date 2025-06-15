#!/usr/bin/env bash
# Abaddon TTY - Terminal interface layer and cell membrane
# Provides semantic color interface and terminal capability detection

set -u # Catch undefined variables (linting-like behavior)

# Guard against multiple loads
[[ -n "${ABADDON_TTY_LOADED:-}" ]] && return 0
readonly ABADDON_TTY_LOADED=1

# Require abaddon-core for semantic color foundation
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-tty.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

# TTY module state variables (following framework pattern)
declare -g ABADDON_TTY_STATUS=""
declare -g ABADDON_TTY_ERROR_MESSAGE=""
declare -g ABADDON_TTY_COLORS=0
declare -g ABADDON_TTY_INTERACTIVE=false
declare -g ABADDON_TTY_WIDTH=80
declare -g ABADDON_TTY_HEIGHT=24
declare -g ABADDON_TTY_SUPPORTS_UNICODE=false
declare -g ABADDON_TTY_LAST_OPERATION=""
declare -g ABADDON_TTY_TPUT_AVAILABLE=""

# TTY module constants
readonly ABADDON_TTY_SUCCESS="success"
readonly ABADDON_TTY_ERROR="error"

# TTY capability-aware color definitions (semantic interface)
# These will be set by detect_tty_capabilities() based on terminal support
declare -g ABADDON_TTY_RED=""
declare -g ABADDON_TTY_GREEN=""
declare -g ABADDON_TTY_YELLOW=""
declare -g ABADDON_TTY_BLUE=""
declare -g ABADDON_TTY_CYAN=""
declare -g ABADDON_TTY_BOLD=""
declare -g ABADDON_TTY_NC=""

# Private helper: Clear all TTY color variables
_clear_tty_colors() {
    ABADDON_TTY_RED=""
    ABADDON_TTY_GREEN=""
    ABADDON_TTY_YELLOW=""
    ABADDON_TTY_BLUE=""
    ABADDON_TTY_CYAN=""
    ABADDON_TTY_BOLD=""
    ABADDON_TTY_NC=""
}

# Reset TTY module state
reset_tty_state() {
    ABADDON_TTY_STATUS=""
    ABADDON_TTY_ERROR_MESSAGE=""
    ABADDON_TTY_COLORS=0
    ABADDON_TTY_INTERACTIVE=false
    ABADDON_TTY_WIDTH=80
    ABADDON_TTY_HEIGHT=24
    ABADDON_TTY_SUPPORTS_UNICODE=false
    ABADDON_TTY_LAST_OPERATION=""
    ABADDON_TTY_TPUT_AVAILABLE=""
    
    _clear_tty_colors
}

# Set TTY error state
set_tty_error() {
    local error_message="$1"
    ABADDON_TTY_STATUS="$ABADDON_TTY_ERROR"
    ABADDON_TTY_ERROR_MESSAGE="$error_message"
    log_error "TTY error: $error_message"
}

# Set TTY success state
set_tty_success() {
    local operation="${1:-tty_detection}"
    ABADDON_TTY_STATUS="$ABADDON_TTY_SUCCESS"
    ABADDON_TTY_ERROR_MESSAGE=""
    ABADDON_TTY_LAST_OPERATION="$operation"
}

# Detect terminal capabilities and configure colors accordingly
detect_tty_capabilities() {
    reset_tty_state
    
    # Cache tput availability
    if command -v tput >/dev/null 2>&1; then
        ABADDON_TTY_TPUT_AVAILABLE="true"
        ABADDON_TTY_COLORS=$(tput colors 2>/dev/null || echo 0)
    else
        ABADDON_TTY_TPUT_AVAILABLE="false"
        ABADDON_TTY_COLORS=8 # Reasonable default
    fi
    
    # Interactive terminal detection
    if [[ -t 1 ]] && [[ -t 2 ]]; then
        ABADDON_TTY_INTERACTIVE=true
    else
        ABADDON_TTY_INTERACTIVE=false
    fi
    
    # Terminal dimensions
    if [[ "$ABADDON_TTY_TPUT_AVAILABLE" == "true" ]]; then
        ABADDON_TTY_WIDTH=$(tput cols 2>/dev/null || echo 80)
        ABADDON_TTY_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    elif [[ -n "${COLUMNS:-}" ]]; then
        ABADDON_TTY_WIDTH="$COLUMNS"
        ABADDON_TTY_HEIGHT="${LINES:-24}"
    else
        ABADDON_TTY_WIDTH=80
        ABADDON_TTY_HEIGHT=24
    fi
    
    # Unicode support detection
    if [[ "${LANG:-}" == *"UTF-8"* ]] || [[ "${LC_ALL:-}" == *"UTF-8"* ]]; then
        ABADDON_TTY_SUPPORTS_UNICODE=true
    else
        ABADDON_TTY_SUPPORTS_UNICODE=false
    fi
    
    # Configure color variables based on capabilities
    configure_tty_colors
    
    set_tty_success "tty_capability_detection"
    log_debug "TTY: ${ABADDON_TTY_COLORS} colors, width=${ABADDON_TTY_WIDTH}, interactive=${ABADDON_TTY_INTERACTIVE}, unicode=${ABADDON_TTY_SUPPORTS_UNICODE}"
}

# Configure color variables based on terminal capabilities
configure_tty_colors() {
    if [[ "$ABADDON_TTY_INTERACTIVE" == "true" ]] && [[ "$ABADDON_TTY_COLORS" -gt 0 ]]; then
        # Terminal supports colors - use semantic colors from core
        ABADDON_TTY_RED="$ABADDON_CORE_COLOR_RED"
        ABADDON_TTY_GREEN="$ABADDON_CORE_COLOR_GREEN"
        ABADDON_TTY_YELLOW="$ABADDON_CORE_COLOR_YELLOW"
        ABADDON_TTY_BLUE="$ABADDON_CORE_COLOR_BLUE"
        ABADDON_TTY_CYAN="$ABADDON_CORE_COLOR_CYAN"
        ABADDON_TTY_BOLD="$ABADDON_CORE_COLOR_BOLD"
        ABADDON_TTY_NC="$ABADDON_CORE_COLOR_NC"
    else
        # No color support - clear all colors
        _clear_tty_colors
    fi
}

# Semantic output functions (cell membrane interface)
tty_render_message() {
    local semantic_type="$1"
    local content="$2"
    local use_color="${3:-true}"
    
    case "$semantic_type" in
        error)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_RED}${content}${ABADDON_TTY_NC}"
            else
                echo "$content"
            fi
            ;;
        success)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_GREEN}${content}${ABADDON_TTY_NC}"
            else
                echo "$content"
            fi
            ;;
        warning)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_YELLOW}${content}${ABADDON_TTY_NC}"
            else
                echo "$content"
            fi
            ;;
        info)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_BLUE}${content}${ABADDON_TTY_NC}"
            else
                echo "$content"
            fi
            ;;
        debug)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_CYAN}${content}${ABADDON_TTY_NC}"
            else
                echo "$content"
            fi
            ;;
        *)
            echo "$content"
            ;;
    esac
}

# Semantic formatting functions
tty_format_bold() {
    local text="$1"
    echo -e "${ABADDON_TTY_BOLD}${text}${ABADDON_TTY_NC}"
}

tty_format_error() {
    local text="$1"
    echo -e "${ABADDON_TTY_RED}${text}${ABADDON_TTY_NC}"
}

tty_format_success() {
    local text="$1"
    echo -e "${ABADDON_TTY_GREEN}${text}${ABADDON_TTY_NC}"
}

tty_format_warning() {
    local text="$1"
    echo -e "${ABADDON_TTY_YELLOW}${text}${ABADDON_TTY_NC}"
}

tty_format_info() {
    local text="$1"
    echo -e "${ABADDON_TTY_BLUE}${text}${ABADDON_TTY_NC}"
}

# Status icon functions (capability-aware)
tty_status_icon() {
    local status="$1"
    local use_color="${2:-true}"
    
    case "$status" in
        success | ok | pass | ✓)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_GREEN}✓${ABADDON_TTY_NC}"
            else
                echo "✓"
            fi
            ;;
        error | fail | ✗)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_RED}✗${ABADDON_TTY_NC}"
            else
                echo "✗"
            fi
            ;;
        warning | warn | ⚠)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_YELLOW}⚠${ABADDON_TTY_NC}"
            else
                echo "!"
            fi
            ;;
        info | ℹ)
            if [[ "$use_color" == "true" ]]; then
                echo -e "${ABADDON_TTY_BLUE}ℹ${ABADDON_TTY_NC}"
            else
                echo "i"
            fi
            ;;
        working | ...)
            if [[ "$ABADDON_TTY_SUPPORTS_UNICODE" == "true" ]]; then
                echo "⠋"
            else
                echo "+"
            fi
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# TTY state accessors (following framework pattern)
get_tty_status() {
    echo "$ABADDON_TTY_STATUS"
}

get_tty_error_message() {
    echo "$ABADDON_TTY_ERROR_MESSAGE"
}

get_tty_last_operation() {
    echo "$ABADDON_TTY_LAST_OPERATION"
}

# TTY success/failure helpers
tty_succeeded() {
    [[ "$ABADDON_TTY_STATUS" == "$ABADDON_TTY_SUCCESS" ]]
}

tty_failed() {
    [[ "$ABADDON_TTY_STATUS" == "$ABADDON_TTY_ERROR" ]]
}

# TTY information functions
get_tty_capabilities() {
    echo "colors:${ABADDON_TTY_COLORS} interactive:${ABADDON_TTY_INTERACTIVE} unicode:${ABADDON_TTY_SUPPORTS_UNICODE} width:${ABADDON_TTY_WIDTH}x${ABADDON_TTY_HEIGHT}"
}

tty_info() {
    echo "Abaddon TTY Module"
    echo "  Capabilities: $(get_tty_capabilities)"
    echo "  Status: $(get_tty_status)"
    echo "  Last Operation: $(get_tty_last_operation)"
}

# Module validation
validate_tty_module() {
    local required_functions=(
        "detect_tty_capabilities"
        "configure_tty_colors"
        "tty_render_message"
        "tty_format_bold"
        "tty_format_error"
        "tty_format_success"
        "tty_format_warning"
        "tty_format_info"
        "tty_status_icon"
        "get_tty_status"
        "get_tty_error_message"
        "get_tty_last_operation"
        "get_tty_capabilities"
        "tty_info"
        "tty_succeeded"
        "tty_failed"
        "reset_tty_state"
        "set_tty_error"
        "set_tty_success"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            set_tty_error "Missing required function: $func"
            return 1
        fi
    done
    
    set_tty_success "module_validation"
    return 0
}

# Auto-detect TTY capabilities on module load
detect_tty_capabilities

log_debug "TTY module loaded with ${ABADDON_TTY_COLORS} color support"