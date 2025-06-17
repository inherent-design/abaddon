#!/usr/bin/env bash
# Abaddon Platform - Core platform services and OS detection
# Version: 2.0.0 - Enhanced for adaptive architecture
# Purpose: Essential platform detection and cross-platform compatibility

set -u  # Catch undefined variables (linting-like behavior)

# Guard against multiple loads
[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] && return 0
readonly ABADDON_PLATFORM_LOADED=1

# Require abaddon-core for logging
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-platform.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

# Platform module state variables (following framework pattern)
declare -g ABADDON_PLATFORM_STATUS=""
declare -g ABADDON_PLATFORM_ERROR_MESSAGE=""
declare -g ABADDON_PLATFORM_OS_TYPE=""
declare -g ABADDON_PLATFORM_OS_VERSION=""
declare -g ABADDON_PLATFORM_ARCHITECTURE=""

# Platform module constants
readonly ABADDON_PLATFORM_SUCCESS="success"
readonly ABADDON_PLATFORM_ERROR="error"

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all Abaddon modules)
# ============================================================================

# Clear all platform module state variables
clear_platform_state() {
    ABADDON_PLATFORM_STATUS=""
    ABADDON_PLATFORM_ERROR_MESSAGE=""
    ABADDON_PLATFORM_OS_TYPE=""
    ABADDON_PLATFORM_OS_VERSION=""
    ABADDON_PLATFORM_ARCHITECTURE=""
    log_debug "Platform module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_platform_status() {
    if [[ "$ABADDON_PLATFORM_STATUS" == "$ABADDON_PLATFORM_SUCCESS" ]]; then
        echo "ready"
    elif [[ "$ABADDON_PLATFORM_STATUS" == "$ABADDON_PLATFORM_ERROR" ]]; then
        echo "error"
    elif [[ -n "$ABADDON_PLATFORM_OS_TYPE" ]]; then
        echo "ready"
    else
        echo "incomplete"
    fi
}

# Export platform state for cross-module access
export_platform_state() {
    echo "ABADDON_PLATFORM_STATUS='$ABADDON_PLATFORM_STATUS'"
    echo "ABADDON_PLATFORM_ERROR_MESSAGE='$ABADDON_PLATFORM_ERROR_MESSAGE'"
    echo "ABADDON_PLATFORM_OS_TYPE='$ABADDON_PLATFORM_OS_TYPE'"
    echo "ABADDON_PLATFORM_OS_VERSION='$ABADDON_PLATFORM_OS_VERSION'"
    echo "ABADDON_PLATFORM_ARCHITECTURE='$ABADDON_PLATFORM_ARCHITECTURE'"
}

# Validate platform module state consistency
validate_platform_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "detect_platform" "detect_os_type" "detect_architecture" "is_platform"
        "clear_platform_state" "get_platform_status" "export_platform_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_PLATFORM_STATUS" "ABADDON_PLATFORM_ERROR_MESSAGE"
        "ABADDON_PLATFORM_OS_TYPE" "ABADDON_PLATFORM_OS_VERSION" "ABADDON_PLATFORM_ARCHITECTURE"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            validation_messages+=("Missing state variable: $var")
            ((errors++))
        fi
    done
    
    # Check core dependency is loaded
    if [[ -z "${ABADDON_CORE_LOADED:-}" ]]; then
        validation_messages+=("Required dependency not loaded: abaddon-core.sh")
        ((errors++))
    fi
    
    # Output validation results
    if [[ $errors -eq 0 ]]; then
        log_debug "Platform module validation: PASSED"
        return 0
    else
        log_error "Platform module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# Set platform error state
set_platform_error() {
    local error_message="$1"
    ABADDON_PLATFORM_STATUS="$ABADDON_PLATFORM_ERROR"
    ABADDON_PLATFORM_ERROR_MESSAGE="$error_message"
    log_error "Platform error: $error_message"
}

# Set platform success state
set_platform_success() {
    ABADDON_PLATFORM_STATUS="$ABADDON_PLATFORM_SUCCESS"
    ABADDON_PLATFORM_ERROR_MESSAGE=""
}

# ============================================================================
# Core Platform Detection
# ============================================================================

# Detect operating system type with enhanced classification
detect_os_type() {
    local os_type=$(uname -s)
    local detected_type=""
    
    case "$os_type" in
        Linux)
            # Enhanced Linux variant detection
            if grep -qi microsoft /proc/version 2>/dev/null; then
                if grep -qi "WSL2" /proc/version 2>/dev/null; then
                    detected_type="linux_wsl2"
                else
                    detected_type="linux_wsl1"
                fi
            elif [[ -f /.dockerenv ]]; then
                detected_type="linux_docker"
            elif [[ -f /run/.containerenv ]]; then
                detected_type="linux_podman"
            elif [[ -f /etc/os-release ]]; then
                . /etc/os-release 2>/dev/null
                detected_type="linux_${ID:-unknown}"
            else
                detected_type="linux_unknown"
            fi
            ;;
        Darwin)
            # macOS version detection
            local macos_version=""
            if command -v sw_vers >/dev/null 2>&1; then
                macos_version=$(sw_vers -productVersion 2>/dev/null | cut -d. -f1-2)
            fi
            detected_type="macos${macos_version:+_$macos_version}"
            ;;
        CYGWIN*)
            detected_type="windows_cygwin"
            ;;
        MINGW*|MSYS*)
            detected_type="windows_mingw"
            ;;
        FreeBSD)
            local freebsd_version=$(uname -r | cut -d. -f1)
            detected_type="freebsd_${freebsd_version}"
            ;;
        OpenBSD)
            detected_type="openbsd"
            ;;
        NetBSD)
            detected_type="netbsd"
            ;;
        SunOS)
            detected_type="solaris"
            ;;
        AIX)
            detected_type="aix"
            ;;
        *)
            detected_type="unknown_${os_type,,}"
            ;;
    esac
    
    ABADDON_PLATFORM_OS_TYPE="$detected_type"
    echo "$detected_type"
}

# Detect OS version with platform-specific methods
detect_os_version() {
    local version="unknown"
    
    case "$(uname -s)" in
        Linux)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release 2>/dev/null
                version="${VERSION_ID:-${VERSION:-unknown}}"
            elif [[ -f /etc/lsb-release ]]; then
                . /etc/lsb-release 2>/dev/null
                version="${DISTRIB_RELEASE:-unknown}"
            fi
            ;;
        Darwin)
            if command -v sw_vers >/dev/null 2>&1; then
                version=$(sw_vers -productVersion 2>/dev/null)
            fi
            ;;
        FreeBSD|OpenBSD|NetBSD)
            version=$(uname -r)
            ;;
        CYGWIN*|MINGW*|MSYS*)
            # Try to get Windows version
            if command -v wmic >/dev/null 2>&1; then
                version=$(wmic os get Version /value 2>/dev/null | grep "Version=" | cut -d= -f2 | tr -d '\r\n')
            fi
            ;;
    esac
    
    ABADDON_PLATFORM_OS_VERSION="$version"
    echo "$version"
}

# Detect system architecture with enhanced classification
detect_architecture() {
    local arch=$(uname -m)
    local detected_arch=""
    
    case "$arch" in
        x86_64|amd64)
            detected_arch="x86_64"
            ;;
        i386|i486|i586|i686)
            detected_arch="x86"
            ;;
        arm64|aarch64)
            detected_arch="arm64"
            ;;
        armv7*|armv6*)
            detected_arch="arm32"
            ;;
        aarch64_be|armv8*)
            detected_arch="arm64"
            ;;
        ppc64le)
            detected_arch="ppc64le"
            ;;
        ppc64)
            detected_arch="ppc64"
            ;;
        s390x)
            detected_arch="s390x"
            ;;
        riscv64)
            detected_arch="riscv64"
            ;;
        *)
            detected_arch="unknown_$arch"
            ;;
    esac
    
    ABADDON_PLATFORM_ARCHITECTURE="$detected_arch"
    echo "$detected_arch"
}

# Comprehensive platform detection (initializes all platform state)
detect_platform() {
    clear_platform_state
    log_debug "Detecting platform information"
    
    # Detect all platform components
    local os_type=$(detect_os_type)
    local os_version=$(detect_os_version)
    local architecture=$(detect_architecture)
    
    # Validate detection results
    if [[ -z "$os_type" || "$os_type" == "unknown_"* ]]; then
        set_platform_error "Unable to detect OS type reliably"
        return 1
    fi
    
    # Store results and set success
    ABADDON_PLATFORM_OS_TYPE="$os_type"
    ABADDON_PLATFORM_OS_VERSION="$os_version"
    ABADDON_PLATFORM_ARCHITECTURE="$architecture"
    
    set_platform_success
    log_debug "Platform detected: $os_type/$os_version/$architecture"
    
    # Return combined platform string for compatibility
    echo "${os_type}"
}

# ============================================================================
# Platform Query Functions
# ============================================================================

# Check if current platform matches pattern
is_platform() {
    local pattern="$1"
    local current_platform="${ABADDON_PLATFORM_OS_TYPE:-$(detect_os_type)}"
    
    case "$pattern" in
        linux|linux_*)
            [[ "$current_platform" == linux* ]]
            ;;
        macos|darwin)
            [[ "$current_platform" == macos* ]]
            ;;
        windows|win)
            [[ "$current_platform" == windows* ]]
            ;;
        freebsd)
            [[ "$current_platform" == freebsd* ]]
            ;;
        wsl|wsl1|wsl2)
            [[ "$current_platform" == *wsl* ]]
            ;;
        container|docker)
            [[ "$current_platform" == *docker* || "$current_platform" == *podman* ]]
            ;;
        unix)
            [[ "$current_platform" == linux* || "$current_platform" == macos* || "$current_platform" == freebsd* ]]
            ;;
        *)
            [[ "$current_platform" == "$pattern"* ]]
            ;;
    esac
}

# Get current OS type
get_os_type() {
    echo "${ABADDON_PLATFORM_OS_TYPE:-$(detect_os_type)}"
}

# Get current OS version
get_os_version() {
    echo "${ABADDON_PLATFORM_OS_VERSION:-$(detect_os_version)}"
}

# Get current architecture
get_architecture() {
    echo "${ABADDON_PLATFORM_ARCHITECTURE:-$(detect_architecture)}"
}

# Get platform family (simplified classification)
get_platform_family() {
    local os_type="${ABADDON_PLATFORM_OS_TYPE:-$(detect_os_type)}"
    
    case "$os_type" in
        linux*)
            echo "linux"
            ;;
        macos*)
            echo "macos"
            ;;
        windows*)
            echo "windows"
            ;;
        freebsd*|openbsd*|netbsd*)
            echo "bsd"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ============================================================================
# Cross-Platform Compatibility Helpers
# ============================================================================

# Check if platform supports specific features
platform_supports() {
    local feature="$1"
    local os_type="${ABADDON_PLATFORM_OS_TYPE:-$(detect_os_type)}"
    
    case "$feature" in
        systemd)
            [[ "$os_type" == linux* ]] && command -v systemctl >/dev/null 2>&1
            ;;
        homebrew)
            [[ "$os_type" == macos* ]] && command -v brew >/dev/null 2>&1
            ;;
        apt)
            [[ "$os_type" == linux* ]] && command -v apt >/dev/null 2>&1
            ;;
        yum|dnf)
            [[ "$os_type" == linux* ]] && (command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1)
            ;;
        launchctl)
            [[ "$os_type" == macos* ]] && command -v launchctl >/dev/null 2>&1
            ;;
        wsl)
            [[ "$os_type" == *wsl* ]]
            ;;
        containers)
            [[ "$os_type" == *docker* || "$os_type" == *podman* ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Get platform-specific paths
get_platform_path() {
    local path_type="$1"
    local os_type="${ABADDON_PLATFORM_OS_TYPE:-$(detect_os_type)}"
    
    case "$path_type" in
        home)
            echo "${HOME:-/tmp}"
            ;;
        tmp)
            case "$os_type" in
                macos*) echo "${TMPDIR:-/tmp}" ;;
                *) echo "/tmp" ;;
            esac
            ;;
        config)
            case "$os_type" in
                macos*) echo "${HOME}/Library/Application Support" ;;
                *) echo "${XDG_CONFIG_HOME:-$HOME/.config}" ;;
            esac
            ;;
        cache)
            case "$os_type" in
                macos*) echo "${HOME}/Library/Caches" ;;
                *) echo "${XDG_CACHE_HOME:-$HOME/.cache}" ;;
            esac
            ;;
        data)
            case "$os_type" in
                macos*) echo "${HOME}/Library/Application Support" ;;
                *) echo "${XDG_DATA_HOME:-$HOME/.local/share}" ;;
            esac
            ;;
        bin)
            case "$os_type" in
                macos*) 
                    if [[ -d "/opt/homebrew/bin" ]]; then
                        echo "/opt/homebrew/bin"
                    else
                        echo "/usr/local/bin"
                    fi
                    ;;
                *) echo "${HOME}/.local/bin" ;;
            esac
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# Environment Analysis
# ============================================================================

# Get basic system resource information (non-intrusive)
get_system_resources() {
    local resources=()
    local os_type="${ABADDON_PLATFORM_OS_TYPE:-$(detect_os_type)}"
    
    case "$os_type" in
        linux*)
            # CPU cores
            if [[ -r /proc/cpuinfo ]]; then
                local cores=$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "unknown")
                resources+=("cpu_cores:$cores")
            fi
            
            # Memory (in GB)
            if [[ -r /proc/meminfo ]]; then
                local mem_kb=$(grep "MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
                if [[ -n "$mem_kb" && "$mem_kb" != "0" ]]; then
                    local mem_gb=$((mem_kb / 1024 / 1024))
                    resources+=("memory_gb:$mem_gb")
                fi
            fi
            ;;
        macos*)
            # CPU cores
            local cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
            resources+=("cpu_cores:$cores")
            
            # Memory (in GB)
            local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
            if [[ "$mem_bytes" != "0" ]]; then
                local mem_gb=$((mem_bytes / 1024 / 1024 / 1024))
                resources+=("memory_gb:$mem_gb")
            fi
            ;;
    esac
    
    echo "${resources[@]}"
}

# Check if running in constrained environment
is_constrained_environment() {
    local os_type="${ABADDON_PLATFORM_OS_TYPE:-$(detect_os_type)}"
    
    # Container environments
    [[ "$os_type" == *docker* || "$os_type" == *podman* ]] && return 0
    
    # WSL1 (more constrained than WSL2)
    [[ "$os_type" == *wsl1* ]] && return 0
    
    # Check for very limited resources
    local resources=($(get_system_resources))
    for resource in "${resources[@]}"; do
        if [[ "$resource" == memory_gb:* ]]; then
            local mem_gb="${resource#memory_gb:}"
            # Less than 2GB is considered constrained
            [[ "$mem_gb" != "unknown" && "$mem_gb" -lt 2 ]] && return 0
        fi
    done
    
    return 1
}

# ============================================================================
# State Access Functions
# ============================================================================

get_platform_error_message() { echo "$ABADDON_PLATFORM_ERROR_MESSAGE"; }

# Check if last operation succeeded
platform_succeeded() { [[ "$ABADDON_PLATFORM_STATUS" == "$ABADDON_PLATFORM_SUCCESS" ]]; }
platform_failed() { [[ "$ABADDON_PLATFORM_STATUS" == "$ABADDON_PLATFORM_ERROR" ]]; }

# ============================================================================
# Module Validation and Information
# ============================================================================

# Module validation function (required by framework)
platform_validate() {
    local errors=0
    
    # Check required functions exist
    local required_functions=(
        "detect_platform" "detect_os_type" "detect_architecture" "is_platform"
        "get_os_type" "get_os_version" "get_architecture" "platform_supports"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_PLATFORM_STATUS" "ABADDON_PLATFORM_ERROR_MESSAGE"
        "ABADDON_PLATFORM_OS_TYPE" "ABADDON_PLATFORM_OS_VERSION" "ABADDON_PLATFORM_ARCHITECTURE"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    # Check dependency is loaded
    if [[ -z "${ABADDON_CORE_LOADED:-}" ]]; then
        log_error "Core dependency not loaded"
        ((errors++))
    fi
    
    return $errors
}

# Module information
platform_info() {
    echo "Abaddon Platform - Core platform services and OS detection"
    echo "Version: 2.0.0 - Enhanced for adaptive architecture"
    echo "Features: OS detection, platform classification, resource analysis"
    echo "Dependencies: core.sh"
    echo "Main Functions:"
    echo "  detect_platform() - Comprehensive platform detection"
    echo "  is_platform(pattern) - Platform pattern matching"
    echo "  platform_supports(feature) - Feature availability checking"
    echo "  get_platform_path(type) - Platform-specific path resolution"
}

# Initialize platform detection on module load
if ! detect_platform >/dev/null; then
    log_warn "Platform detection failed, some features may not work correctly"
fi

log_debug "Abaddon Platform module loaded successfully - core services active"