#!/usr/bin/env bash
# Abaddon Core - Shared utilities for both pure POSIX and modern variants
# Universal logging, platform detection, and common helpers

# Guard against multiple loads
[[ -n "${ABADDON_CORE_LOADED:-}" ]] && return 0
readonly ABADDON_CORE_LOADED=1

# Universal color definitions (portable)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Logging levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_SUCCESS=2
readonly LOG_LEVEL_WARN=3
readonly LOG_LEVEL_ERROR=4

# Current log level (can be overridden by environment)
ABADDON_LOG_LEVEL="${ABADDON_LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Enhanced logging system with level support
log_debug() {
    [[ $ABADDON_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] || return 0
    echo -e "${CYAN}[DEBUG]${NC} $*" >&2
}

log_info() {
    [[ $ABADDON_LOG_LEVEL -le $LOG_LEVEL_INFO ]] || return 0
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    [[ $ABADDON_LOG_LEVEL -le $LOG_LEVEL_SUCCESS ]] || return 0
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    [[ $ABADDON_LOG_LEVEL -le $LOG_LEVEL_WARN ]] || return 0
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Enhanced platform detection with capabilities
detect_platform() {
    case "$(uname -s)" in
        Darwin) 
            echo "macos"
            ;;
        Linux)
            if [[ -f /etc/os-release ]]; then
                # Source os-release to get ID
                local os_id
                os_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
                echo "linux_${os_id}"
            else
                echo "linux_unknown"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get platform capabilities
get_platform_capabilities() {
    local platform
    platform=$(detect_platform)
    
    case "$platform" in
        macos)
            echo "homebrew,networksetup,launchctl,pbcopy,open"
            ;;
        linux_ubuntu|linux_debian)
            echo "apt,systemctl,xclip,xdg-open"
            ;;
        linux_fedora|linux_rhel|linux_centos)
            echo "dnf,systemctl,xclip,xdg-open"
            ;;
        linux_arch)
            echo "pacman,systemctl,xclip,xdg-open"
            ;;
        linux_*)
            echo "systemctl,xclip,xdg-open"
            ;;
        windows)
            echo "powershell,clip,start"
            ;;
        *)
            echo "basic"
            ;;
    esac
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
            echo "le"  # version1 <= version2
        else
            echo "gt"  # version1 > version2
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
        1)   log_info "General error - check command syntax and arguments" ;;
        2)   log_info "Misuse of shell builtins - check command usage" ;;
        126) log_info "Command not executable - check permissions" ;;
        127) log_info "Command not found - check if tool is installed" ;;
        130) log_info "Script interrupted by user (Ctrl+C)" ;;
        *)   log_info "Unexpected error code - see documentation" ;;
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
        duration=$(( (end_time - start_time) / 1000000 ))
    else
        # Second precision fallback
        duration=$(( (end_time - start_time) * 1000 ))
    fi
    
    log_debug "Command '$command_name' took ${duration}ms (exit: $exit_code)"
    return $exit_code
}

log_debug "Abaddon Core module loaded successfully"