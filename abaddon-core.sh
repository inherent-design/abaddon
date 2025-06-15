#!/usr/bin/env bash
# Abaddon Core - Shared utilities for both pure POSIX and modern variants
# Universal logging, platform detection, and common helpers

set -u # Catch undefined variables (linting-like behavior)

# Guard against multiple loads
[[ -n "${ABADDON_CORE_LOADED:-}" ]] && return 0
readonly ABADDON_CORE_LOADED=1

# ============================================================================
# Semantic Color Architecture - Intent-Based Color System
# ============================================================================
# 
# Core defines SEMANTIC INTENT, TTY module implements TERMINAL REPRESENTATION
# This allows user terminal themes to control actual appearance while
# maintaining consistent semantic meaning across the application.

# Semantic Color Slots (Terminal Color Indices)
# These map to standard ANSI color slots that users can customize
readonly ABADDON_CORE_SEMANTIC_SLOT_ERROR=1        # Usually red
readonly ABADDON_CORE_SEMANTIC_SLOT_SUCCESS=2      # Usually green  
readonly ABADDON_CORE_SEMANTIC_SLOT_WARNING=3      # Usually yellow
readonly ABADDON_CORE_SEMANTIC_SLOT_INFO=4         # Usually blue
readonly ABADDON_CORE_SEMANTIC_SLOT_DEBUG=6        # Usually cyan
readonly ABADDON_CORE_SEMANTIC_SLOT_ACCENT=5       # Usually magenta
readonly ABADDON_CORE_SEMANTIC_SLOT_NEUTRAL=7      # Usually white/light gray
readonly ABADDON_CORE_SEMANTIC_SLOT_MUTED=8        # Usually dark gray

# Semantic Intent Definitions (Abstract)
# These describe WHAT something means, not HOW it looks
readonly ABADDON_CORE_SEMANTIC_ERROR="error"           # Critical problems, failures
readonly ABADDON_CORE_SEMANTIC_SUCCESS="success"       # Successful operations, confirmations
readonly ABADDON_CORE_SEMANTIC_WARNING="warning"       # Cautions, non-critical issues
readonly ABADDON_CORE_SEMANTIC_INFO="info"            # General information, status
readonly ABADDON_CORE_SEMANTIC_DEBUG="debug"          # Development, diagnostic info
readonly ABADDON_CORE_SEMANTIC_ACCENT="accent"        # Highlights, emphasis
readonly ABADDON_CORE_SEMANTIC_NEUTRAL="neutral"      # Default text, body content
readonly ABADDON_CORE_SEMANTIC_MUTED="muted"          # Secondary text, metadata

# Context-Specific Semantic Intents
readonly ABADDON_CORE_SEMANTIC_TEST_EXPECTED="test_expected"     # Expected test failures
readonly ABADDON_CORE_SEMANTIC_TEST_UNEXPECTED="test_unexpected" # Unexpected errors
readonly ABADDON_CORE_SEMANTIC_PROGRESS="progress"              # Progress indicators
readonly ABADDON_CORE_SEMANTIC_SYSTEM="system"                 # System messages

# Default Terminal Escape Sequences (Fallback Implementation)
# TTY module will override these with capability-aware versions
readonly ABADDON_CORE_COLOR_RED='\033[0;31m'      # Slot 1
readonly ABADDON_CORE_COLOR_GREEN='\033[0;32m'    # Slot 2
readonly ABADDON_CORE_COLOR_YELLOW='\033[0;33m'   # Slot 3
readonly ABADDON_CORE_COLOR_BLUE='\033[0;34m'     # Slot 4
readonly ABADDON_CORE_COLOR_MAGENTA='\033[0;35m'  # Slot 5
readonly ABADDON_CORE_COLOR_CYAN='\033[0;36m'     # Slot 6
readonly ABADDON_CORE_COLOR_WHITE='\033[0;37m'    # Slot 7
readonly ABADDON_CORE_COLOR_GRAY='\033[0;90m'     # Slot 8 (bright black)

# Style Escape Sequences
readonly ABADDON_CORE_COLOR_BOLD='\033[1m'
readonly ABADDON_CORE_COLOR_DIM='\033[2m'
readonly ABADDON_CORE_COLOR_UNDERLINE='\033[4m'
readonly ABADDON_CORE_COLOR_INVERSE='\033[7m'
readonly ABADDON_CORE_COLOR_NC='\033[0m'          # Reset/No Color

# Logging levels
readonly ABADDON_CORE_LOG_LEVEL_DEBUG=0
readonly ABADDON_CORE_LOG_LEVEL_INFO=1
readonly ABADDON_CORE_LOG_LEVEL_SUCCESS=2
readonly ABADDON_CORE_LOG_LEVEL_WARN=3
readonly ABADDON_CORE_LOG_LEVEL_ERROR=4

# Initialize log level with fallback
declare -g ABADDON_CORE_LOG_LEVEL
: "${ABADDON_CORE_LOG_LEVEL:=$ABADDON_CORE_LOG_LEVEL_INFO}"

# Core module state variables (following framework pattern)
declare -g ABADDON_CORE_PLATFORM=""
declare -g ABADDON_CORE_CAPABILITIES=""
declare -g ABADDON_CORE_STATUS=""
declare -g ABADDON_CORE_ERROR_MESSAGE=""

# Core module constants
readonly ABADDON_CORE_SUCCESS="success"
readonly ABADDON_CORE_ERROR="error"

# Enhanced logging system with level support
# All logging goes to stderr (operational metadata, not user data)
log_debug() {
    [[ $ABADDON_CORE_LOG_LEVEL -le $ABADDON_CORE_LOG_LEVEL_DEBUG ]] || return 0
    echo -e "${ABADDON_CORE_COLOR_CYAN}[DEBUG]${ABADDON_CORE_COLOR_NC} $*" >&2
}

log_info() {
    [[ $ABADDON_CORE_LOG_LEVEL -le $ABADDON_CORE_LOG_LEVEL_INFO ]] || return 0
    echo -e "${ABADDON_CORE_COLOR_BLUE}[INFO]${ABADDON_CORE_COLOR_NC} $*" >&2
}

log_success() {
    [[ $ABADDON_CORE_LOG_LEVEL -le $ABADDON_CORE_LOG_LEVEL_SUCCESS ]] || return 0
    echo -e "${ABADDON_CORE_COLOR_GREEN}[OK]${ABADDON_CORE_COLOR_NC} $*" >&2
}

log_warn() {
    [[ $ABADDON_CORE_LOG_LEVEL -le $ABADDON_CORE_LOG_LEVEL_WARN ]] || return 0
    echo -e "${ABADDON_CORE_COLOR_YELLOW}[WARN]${ABADDON_CORE_COLOR_NC} $*" >&2
}

log_error() {
    echo -e "${ABADDON_CORE_COLOR_RED}[ERROR]${ABADDON_CORE_COLOR_NC} $*" >&2
}

# ============================================================================
# Semantic Color Interface Functions
# ============================================================================
# Core provides semantic intent, actual color rendering delegated to TTY module

# Get semantic color for intent (fallback implementation)
get_semantic_color() {
    local intent="$1"
    case "$intent" in
        "$ABADDON_CORE_SEMANTIC_ERROR")       echo "$ABADDON_CORE_COLOR_RED" ;;
        "$ABADDON_CORE_SEMANTIC_SUCCESS")     echo "$ABADDON_CORE_COLOR_GREEN" ;;
        "$ABADDON_CORE_SEMANTIC_WARNING")     echo "$ABADDON_CORE_COLOR_YELLOW" ;;
        "$ABADDON_CORE_SEMANTIC_INFO")        echo "$ABADDON_CORE_COLOR_BLUE" ;;
        "$ABADDON_CORE_SEMANTIC_DEBUG")       echo "$ABADDON_CORE_COLOR_CYAN" ;;
        "$ABADDON_CORE_SEMANTIC_ACCENT")      echo "$ABADDON_CORE_COLOR_MAGENTA" ;;
        "$ABADDON_CORE_SEMANTIC_NEUTRAL")     echo "$ABADDON_CORE_COLOR_WHITE" ;;
        "$ABADDON_CORE_SEMANTIC_MUTED")       echo "$ABADDON_CORE_COLOR_GRAY" ;;
        "$ABADDON_CORE_SEMANTIC_TEST_EXPECTED") echo "$ABADDON_CORE_COLOR_DIM" ;;
        "$ABADDON_CORE_SEMANTIC_TEST_UNEXPECTED") echo "$ABADDON_CORE_COLOR_INVERSE$ABADDON_CORE_COLOR_RED" ;;
        *) echo "$ABADDON_CORE_COLOR_NC" ;;
    esac
}

# Semantic logging functions (intent-based)
log_semantic() {
    local intent="$1"
    shift
    local color
    color=$(get_semantic_color "$intent")
    echo -e "${color}$*${ABADDON_CORE_COLOR_NC}" >&2
}

# Reset core module state
reset_core_state() {
    ABADDON_CORE_PLATFORM=""
    ABADDON_CORE_CAPABILITIES=""
    ABADDON_CORE_STATUS=""
    ABADDON_CORE_ERROR_MESSAGE=""
}

# Set core error state
set_core_error() {
    local error_message="$1"
    ABADDON_CORE_STATUS="$ABADDON_CORE_ERROR"
    ABADDON_CORE_ERROR_MESSAGE="$error_message"
    log_error "Core error: $error_message"
}

# Set core success state
set_core_success() {
    ABADDON_CORE_STATUS="$ABADDON_CORE_SUCCESS"
    ABADDON_CORE_ERROR_MESSAGE=""
}

# Enhanced platform detection with capabilities
detect_platform() {
    reset_core_state

    local platform
    case "$(uname -s)" in
    Darwin)
        platform="macos"
        ;;
    Linux)
        if [[ -f /etc/os-release ]]; then
            # Source os-release to get ID
            local os_id
            os_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
            platform="linux_${os_id}"
        else
            platform="linux_unknown"
        fi
        ;;
    CYGWIN* | MINGW* | MSYS*)
        platform="windows"
        ;;
    *)
        platform="unknown"
        ;;
    esac

    ABADDON_CORE_PLATFORM="$platform"
    set_core_success
    echo "$platform"
}

# Get platform capabilities
get_platform_capabilities() {
    local platform

    # Use cached platform if available
    if [[ -n "$ABADDON_CORE_PLATFORM" ]]; then
        platform="$ABADDON_CORE_PLATFORM"
    else
        platform=$(detect_platform)
    fi

    local capabilities
    case "$platform" in
    macos)
        capabilities="homebrew,networksetup,launchctl,pbcopy,open"
        ;;
    linux_ubuntu | linux_debian)
        capabilities="apt,systemctl,xclip,xdg-open"
        ;;
    linux_fedora | linux_rhel | linux_centos)
        capabilities="dnf,systemctl,xclip,xdg-open"
        ;;
    linux_arch)
        capabilities="pacman,systemctl,xclip,xdg-open"
        ;;
    linux_*)
        capabilities="systemctl,xclip,xdg-open"
        ;;
    windows)
        capabilities="powershell,clip,start"
        ;;
    *)
        capabilities="basic"
        ;;
    esac

    ABADDON_CORE_CAPABILITIES="$capabilities"
    echo "$capabilities"
}

# Portable path handling
normalize_path() {
    local path="$1"
    # Expand tilde and resolve relative paths
    path="${path/#\~/$HOME}"
    # Use readlink if available, otherwise basic cleanup
    if command -v readlink >/dev/null 2>&1; then
        readlink -f "$path" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}

# Safe command execution with timeout
safe_execute() {
    local timeout_seconds="${1:-10}"
    local command="$2"
    shift 2

    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_seconds" $command "$@"
    else
        # Fallback without timeout
        $command "$@"
    fi
}

# Configuration validation helpers
validate_config_file() {
    local config_file="$1"
    local required_keys=("${@:2}")

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        log_error "Configuration file not readable: $config_file"
        return 1
    fi

    # Basic syntax check for shell config files
    if [[ "$config_file" =~ \.(sh|bash|env)$ ]]; then
        if ! bash -n "$config_file" 2>/dev/null; then
            log_error "Configuration file has syntax errors: $config_file"
            return 1
        fi
    fi

    log_debug "Configuration file validated: $config_file"
    return 0
}

# Environment variable helpers
require_env_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"

    if [[ -z "$var_value" ]]; then
        log_error "Required environment variable not set: $var_name"
        return 1
    fi

    log_debug "Environment variable validated: $var_name=$var_value"
    return 0
}

# Portable arithmetic operations (Atlas bash patterns)
safe_arithmetic() {
    local expression="$1"
    local result

    # Use portable arithmetic expansion
    if result=$((expression)) 2>/dev/null; then
        echo "$result"
        return 0
    else
        log_error "Invalid arithmetic expression: $expression"
        return 1
    fi
}

# String manipulation helpers
trim_whitespace() {
    local string="$1"
    # Remove leading and trailing whitespace
    string="${string#"${string%%[![:space:]]*}"}"
    string="${string%"${string##*[![:space:]]}"}"
    echo "$string"
}

# Version comparison (simple semver-like)
version_compare() {
    local version1="$1"
    local version2="$2"

    # Simple version comparison using sort -V if available
    if command -v sort >/dev/null 2>&1; then
        local result
        result=$(printf '%s\n%s\n' "$version1" "$version2" | sort -V | head -1)
        if [[ "$result" == "$version1" ]]; then
            echo "le" # version1 <= version2
        else
            echo "gt" # version1 > version2
        fi
    else
        # Fallback: basic string comparison
        if [[ "$version1" == "$version2" ]]; then
            echo "eq"
        elif [[ "$version1" < "$version2" ]]; then
            echo "lt"
        else
            echo "gt"
        fi
    fi
}

# Error handling patterns
handle_error() {
    local exit_code="$1"
    local error_message="$2"
    local context="${3:-unknown}"

    log_error "Command failed in context '$context': $error_message (exit code: $exit_code)"

    # Provide contextual guidance based on common error codes
    case "$exit_code" in
    1) log_info "General error - check command syntax and arguments" ;;
    2) log_info "Misuse of shell builtins - check command usage" ;;
    126) log_info "Command not executable - check permissions" ;;
    127) log_info "Command not found - check if tool is installed" ;;
    130) log_info "Script interrupted by user (Ctrl+C)" ;;
    *) log_info "Unexpected error code - see documentation" ;;
    esac

    return "$exit_code"
}

# Cleanup helpers
register_cleanup() {
    local cleanup_function="$1"

    # Add to existing trap or create new one
    local existing_trap
    existing_trap=$(trap -p EXIT | sed "s/trap -- '\(.*\)' EXIT/\1/")

    if [[ -n "$existing_trap" ]]; then
        trap "$existing_trap; $cleanup_function" EXIT
    else
        trap "$cleanup_function" EXIT
    fi

    log_debug "Registered cleanup function: $cleanup_function"
}

# Module validation
validate_module() {
    local module_name="$1"
    local required_functions=("${@:2}")

    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            log_error "Module $module_name missing required function: $func"
            return 1
        fi
    done

    log_debug "Module validated: $module_name"
    return 0
}

# File system helpers
ensure_directory() {
    local directory="$1"
    local permissions="${2:-755}"

    if [[ ! -d "$directory" ]]; then
        if mkdir -p "$directory" 2>/dev/null; then
            chmod "$permissions" "$directory" 2>/dev/null || true
            log_debug "Created directory: $directory"
        else
            log_error "Failed to create directory: $directory"
            return 1
        fi
    fi

    if [[ ! -w "$directory" ]]; then
        log_error "Directory not writable: $directory"
        return 1
    fi

    return 0
}

# Performance measurement helpers
measure_execution() {
    local command_name="$1"
    local start_time end_time duration
    shift

    start_time=$(date +%s%N 2>/dev/null || date +%s)
    "$@"
    local exit_code=$?
    end_time=$(date +%s%N 2>/dev/null || date +%s)

    # Calculate duration in milliseconds
    if [[ "$start_time" =~ [0-9]{13,} ]]; then
        # Nanosecond precision available
        duration=$(((end_time - start_time) / 1000000))
    else
        # Second precision fallback
        duration=$(((end_time - start_time) * 1000))
    fi

    log_debug "Command '$command_name' took ${duration}ms (exit: $exit_code)"
    return $exit_code
}

# State access functions (following framework pattern)
get_core_status() { echo "$ABADDON_CORE_STATUS"; }
get_core_platform() { echo "$ABADDON_CORE_PLATFORM"; }
get_core_capabilities() { echo "$ABADDON_CORE_CAPABILITIES"; }
get_core_error_message() { echo "$ABADDON_CORE_ERROR_MESSAGE"; }

# Check if last operation succeeded
core_succeeded() { [[ "$ABADDON_CORE_STATUS" == "$ABADDON_CORE_SUCCESS" ]]; }
core_failed() { [[ "$ABADDON_CORE_STATUS" == "$ABADDON_CORE_ERROR" ]]; }

# Module validation function (required by framework)
core_validate() {
    local errors=0

    # Check required functions exist
    local required_functions=(
        "detect_platform" "get_platform_capabilities" "log_info" "log_error"
        "set_core_error" "set_core_success" "reset_core_state"
    )

    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done

    # Check state variables exist
    local required_vars=(
        "ABADDON_CORE_STATUS" "ABADDON_CORE_PLATFORM"
        "ABADDON_CORE_CAPABILITIES" "ABADDON_CORE_ERROR_MESSAGE"
    )

    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done

    return $errors
}

log_debug "Abaddon Core module loaded successfully with standardized state management"
