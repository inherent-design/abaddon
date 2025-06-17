#!/usr/bin/env bash
# Abaddon Tool Detection - Flutter-doctor-like intelligent tool and capability detection
# Version: 1.0.0 - Enhanced platform intelligence
# Purpose: Comprehensive tool detection, capability promotion, and user guidance

set -u  # Catch undefined variables (linting-like behavior)

# Guard against multiple loads
[[ -n "${ABADDON_TOOL_DETECTION_LOADED:-}" ]] && return 0
readonly ABADDON_TOOL_DETECTION_LOADED=1

# Require dependencies
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-tool-detection.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] || {
    echo "ERROR: abaddon-tool-detection.sh requires abaddon-platform.sh to be loaded first" >&2
    return 1
}

# Tool detection module state variables
declare -g ABADDON_TOOL_DETECTION_STATUS=""
declare -g ABADDON_TOOL_DETECTION_ERROR_MESSAGE=""
declare -g ABADDON_TOOL_DETECTION_AVAILABLE_TOOLS=""
declare -g ABADDON_TOOL_DETECTION_MISSING_TOOLS=""
declare -g ABADDON_TOOL_DETECTION_PACKAGE_MANAGERS=""

# Tool detection module constants
readonly ABADDON_TOOL_DETECTION_SUCCESS="success"
readonly ABADDON_TOOL_DETECTION_ERROR="error"

# Modern tool registry with enhanced metadata
declare -A ABADDON_MODERN_TOOLS=(
    # Core development tools
    ["fd"]="file_search:Fast file finding:distro packages or brew:rust"
    ["rg"]="text_search:Fast text search:distro packages or brew:rust" 
    ["eza"]="file_listing:Modern file listing:cargo/brew/distro packages:rust"
    ["gdu"]="disk_usage:Fast disk usage analyzer:go toolchain recommended:go"
    ["bat"]="file_preview:Syntax highlighted file viewer:cargo recommended:rust"
    
    # Data processing tools
    ["jq"]="json_processing:JSON processor:distro packages or brew:c"
    ["yq"]="yaml_processing:YAML processor:distro packages or brew:go"
    ["tq"]="toml_processing:TOML processor:cargo install:rust"
    ["xq"]="xml_processing:XML processor:cargo install:rust"
    
    # System monitoring
    ["htop"]="system_monitoring:Interactive process viewer:distro packages:c"
    ["btop"]="system_monitoring:Modern resource monitor:distro packages:cpp"
    ["procs"]="process_management:Modern ps replacement:cargo install:rust"
    
    # Network tools
    ["curlie"]="http_client:Modern curl wrapper:cargo install:rust"
    ["httpie"]="http_client:User-friendly HTTP client:pip install:python"
    
    # Git enhancement
    ["delta"]="git_diff:Better git diff viewer:cargo install:rust"
    ["gitui"]="git_interface:Terminal git interface:cargo install:rust"
)

# Tool capability definitions with enhanced metadata
declare -A ABADDON_TOOL_CAPABILITIES=(
    ["fd"]="parallel_search,type_filtering,ignore_patterns,json_output,regex_support"
    ["rg"]="parallel_search,json_output,type_filtering,context_lines,multiline,regex_support"
    ["eza"]="rich_listing,json_output,git_status,tree_view,icons,colors,long_format"
    ["gdu"]="json_output,progress_display,parallel_analysis,interactive_mode"
    ["bat"]="syntax_highlighting,git_integration,paging,themes,line_numbers"
    ["jq"]="json_parsing,filtering,transformation,streaming,arithmetic"
    ["yq"]="yaml_parsing,json_conversion,filtering,transformation,merge_operations"
    ["tq"]="toml_parsing,json_conversion,filtering"
    ["xq"]="xml_parsing,css_selectors,json_conversion"
    ["htop"]="interactive_monitoring,process_tree,cpu_meters,memory_usage"
    ["btop"]="modern_interface,gpu_monitoring,network_stats,process_control"
    ["delta"]="syntax_highlighting,side_by_side,line_numbers,blame_support"
    ["curlie"]="json_formatting,syntax_highlighting,session_persistence"
    ["httpie"]="json_support,form_data,authentication,session_management"
)

# Package manager registry with platform affinity
declare -A ABADDON_PACKAGE_MANAGERS=(
    # macOS package managers
    ["brew"]="macos:Package manager for macOS:https://brew.sh"
    ["port"]="macos:MacPorts package manager:https://www.macports.org"
    
    # Linux package managers
    ["pacman"]="linux_arch:Arch Linux package manager:built-in"
    ["yay"]="linux_arch:AUR helper for Arch Linux:pacman -S yay"
    ["apt"]="linux_debian:Debian/Ubuntu package manager:built-in"
    ["apt-get"]="linux_debian:Legacy APT interface:built-in"
    ["dpkg"]="linux_debian:Debian package installer:built-in"
    ["dnf"]="linux_fedora:Fedora package manager:built-in"
    ["yum"]="linux_rhel:RHEL/CentOS package manager:built-in"
    ["rpm"]="linux_rhel:RPM package installer:built-in"
    ["zypper"]="linux_suse:SUSE package manager:built-in"
    ["apk"]="linux_alpine:Alpine Linux package manager:built-in"
    ["emerge"]="linux_gentoo:Gentoo package manager:built-in"
    
    # Universal package managers
    ["snap"]="linux:Universal Linux packages:snapd"
    ["flatpak"]="linux:Sandboxed application distribution:flatpak"
    
    # Language-specific package managers
    ["cargo"]="rust:Rust package manager:rustup"
    ["npm"]="javascript:Node.js package manager:nodejs"
    ["pip"]="python:Python package manager:python"
    ["go"]="go:Go module manager:golang"
)

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all Abaddon modules)
# ============================================================================

# Clear all tool detection module state variables
clear_tool_detection_state() {
    ABADDON_TOOL_DETECTION_STATUS=""
    ABADDON_TOOL_DETECTION_ERROR_MESSAGE=""
    ABADDON_TOOL_DETECTION_AVAILABLE_TOOLS=""
    ABADDON_TOOL_DETECTION_MISSING_TOOLS=""
    ABADDON_TOOL_DETECTION_PACKAGE_MANAGERS=""
    log_debug "Tool detection module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_tool_detection_status() {
    if [[ "$ABADDON_TOOL_DETECTION_STATUS" == "$ABADDON_TOOL_DETECTION_SUCCESS" ]]; then
        echo "ready"
    elif [[ "$ABADDON_TOOL_DETECTION_STATUS" == "$ABADDON_TOOL_DETECTION_ERROR" ]]; then
        echo "error"
    elif [[ -n "$ABADDON_TOOL_DETECTION_PACKAGE_MANAGERS" ]]; then
        echo "ready"
    else
        echo "incomplete"
    fi
}

# Export tool detection state for cross-module access
export_tool_detection_state() {
    echo "ABADDON_TOOL_DETECTION_STATUS='$ABADDON_TOOL_DETECTION_STATUS'"
    echo "ABADDON_TOOL_DETECTION_ERROR_MESSAGE='$ABADDON_TOOL_DETECTION_ERROR_MESSAGE'"
    echo "ABADDON_TOOL_DETECTION_AVAILABLE_TOOLS='$ABADDON_TOOL_DETECTION_AVAILABLE_TOOLS'"
    echo "ABADDON_TOOL_DETECTION_MISSING_TOOLS='$ABADDON_TOOL_DETECTION_MISSING_TOOLS'"
    echo "ABADDON_TOOL_DETECTION_PACKAGE_MANAGERS='$ABADDON_TOOL_DETECTION_PACKAGE_MANAGERS'"
}

# Validate tool detection module state consistency
validate_tool_detection_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "detect_package_managers" "detect_tool_variants" "check_tool_enhanced"
        "tool_detection_doctor" "suggest_tool_installation_enhanced"
        "clear_tool_detection_state" "get_tool_detection_status" "export_tool_detection_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_TOOL_DETECTION_STATUS" "ABADDON_TOOL_DETECTION_ERROR_MESSAGE"
        "ABADDON_TOOL_DETECTION_AVAILABLE_TOOLS" "ABADDON_TOOL_DETECTION_MISSING_TOOLS"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            validation_messages+=("Missing state variable: $var")
            ((errors++))
        fi
    done
    
    # Check dependencies are loaded
    if [[ -z "${ABADDON_CORE_LOADED:-}" ]]; then
        validation_messages+=("Required dependency not loaded: abaddon-core.sh")
        ((errors++))
    fi
    
    if [[ -z "${ABADDON_PLATFORM_LOADED:-}" ]]; then
        validation_messages+=("Required dependency not loaded: abaddon-platform.sh")
        ((errors++))
    fi
    
    # Output validation results
    if [[ $errors -eq 0 ]]; then
        log_debug "Tool detection module validation: PASSED"
        return 0
    else
        log_error "Tool detection module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# Set tool detection error state
set_tool_detection_error() {
    local error_message="$1"
    ABADDON_TOOL_DETECTION_STATUS="$ABADDON_TOOL_DETECTION_ERROR"
    ABADDON_TOOL_DETECTION_ERROR_MESSAGE="$error_message"
    log_error "Tool detection error: $error_message"
}

# Set tool detection success state
set_tool_detection_success() {
    ABADDON_TOOL_DETECTION_STATUS="$ABADDON_TOOL_DETECTION_SUCCESS"
    ABADDON_TOOL_DETECTION_ERROR_MESSAGE=""
}

# ============================================================================
# Package Manager Detection
# ============================================================================

# Detect available package managers with platform awareness
detect_package_managers() {
    local platform_family=$(get_platform_family)
    local os_type=$(get_os_type)
    local managers=()
    
    log_debug "Detecting package managers for platform: $platform_family ($os_type)"
    
    # Platform-specific package managers (prioritized by platform)
    case "$platform_family" in
        macos)
            command -v brew >/dev/null 2>&1 && managers+=("brew")
            command -v port >/dev/null 2>&1 && managers+=("port")
            ;;
        linux)
            # Detect by distribution
            case "$os_type" in
                linux_arch*|linux_manjaro*)
                    command -v pacman >/dev/null 2>&1 && managers+=("pacman")
                    command -v yay >/dev/null 2>&1 && managers+=("yay")
                    ;;
                linux_debian*|linux_ubuntu*)
                    command -v apt >/dev/null 2>&1 && managers+=("apt")
                    command -v apt-get >/dev/null 2>&1 && managers+=("apt-get")
                    command -v dpkg >/dev/null 2>&1 && managers+=("dpkg")
                    ;;
                linux_fedora*|linux_rhel*|linux_centos*)
                    command -v dnf >/dev/null 2>&1 && managers+=("dnf")
                    command -v yum >/dev/null 2>&1 && managers+=("yum")
                    command -v rpm >/dev/null 2>&1 && managers+=("rpm")
                    ;;
                linux_suse*|linux_opensuse*)
                    command -v zypper >/dev/null 2>&1 && managers+=("zypper")
                    ;;
                linux_alpine*)
                    command -v apk >/dev/null 2>&1 && managers+=("apk")
                    ;;
                linux_gentoo*)
                    command -v emerge >/dev/null 2>&1 && managers+=("emerge")
                    ;;
                *)
                    # Generic Linux detection fallback
                    command -v apt >/dev/null 2>&1 && managers+=("apt")
                    command -v dnf >/dev/null 2>&1 && managers+=("dnf")
                    command -v yum >/dev/null 2>&1 && managers+=("yum")
                    command -v pacman >/dev/null 2>&1 && managers+=("pacman")
                    command -v zypper >/dev/null 2>&1 && managers+=("zypper")
                    command -v apk >/dev/null 2>&1 && managers+=("apk")
                    ;;
            esac
            
            # Universal Linux package managers
            command -v snap >/dev/null 2>&1 && managers+=("snap")
            command -v flatpak >/dev/null 2>&1 && managers+=("flatpak")
            ;;
    esac
    
    # Language-specific package managers (cross-platform)
    command -v cargo >/dev/null 2>&1 && managers+=("cargo")
    command -v npm >/dev/null 2>&1 && managers+=("npm")
    command -v pip >/dev/null 2>&1 && managers+=("pip")
    command -v go >/dev/null 2>&1 && managers+=("go")
    
    ABADDON_TOOL_DETECTION_PACKAGE_MANAGERS="${managers[*]}"
    echo "${managers[@]}"
}

# Rank package managers by effectiveness for development tools
rank_package_managers() {
    local available=("$@")
    local ranked=()
    local platform_family=$(get_platform_family)
    
    # Platform-native managers first
    case "$platform_family" in
        macos)
            for mgr in "${available[@]}"; do
                case "$mgr" in
                    brew) ranked=("$mgr" "${ranked[@]}") ;;  # Highest priority
                    port) ranked+=("$mgr") ;;               # Lower priority
                esac
            done
            ;;
        linux)
            for mgr in "${available[@]}"; do
                case "$mgr" in
                    pacman|apt|dnf|zypper|apk) ranked=("$mgr" "${ranked[@]}") ;;
                    yay) ranked=("$mgr" "${ranked[@]}") ;;  # AUR helper priority
                    snap|flatpak) ranked+=("$mgr") ;;      # Universal but lower
                esac
            done
            ;;
    esac
    
    # Language-specific managers (cross-platform)
    for mgr in "${available[@]}"; do
        case "$mgr" in
            cargo|npm|pip|go) 
                if [[ ! " ${ranked[*]} " =~ " $mgr " ]]; then
                    ranked+=("$mgr")
                fi
                ;;
        esac
    done
    
    # Add any remaining managers
    for mgr in "${available[@]}"; do
        if [[ ! " ${ranked[*]} " =~ " $mgr " ]]; then
            ranked+=("$mgr")
        fi
    done
    
    echo "${ranked[@]}"
}

# ============================================================================
# Tool Variant Detection (GNU vs BSD vs uutils vs g-prefixed)
# ============================================================================

# Detect tool variants with comprehensive coreutils analysis
detect_tool_variants() {
    local variants=()
    
    log_debug "Detecting tool variants and coreutils implementations"
    
    # Test core utilities for implementation type
    detect_coreutils_implementation() {
        local impl="unknown"
        
        # Test ls first (most reliable indicator)
        if command -v ls >/dev/null 2>&1; then
            if ls --version 2>/dev/null | grep -q "GNU coreutils"; then
                impl="gnu"
            elif ls --version 2>/dev/null | grep -q "uutils"; then
                impl="uutils"  # Rust-powered coreutils
            elif ls --version 2>&1 | grep -q "illegal option"; then
                impl="bsd"
            fi
        fi
        
        echo "$impl"
    }
    
    # Test for g-prefixed GNU tools (common on macOS with Homebrew)
    detect_g_prefixed_tools() {
        local g_tools=()
        local common_tools=("ls" "cp" "mv" "rm" "cat" "head" "tail" "sort" "uniq" "grep" "sed" "awk" "find" "timeout")
        
        for tool in "${common_tools[@]}"; do
            local g_tool="g$tool"
            if command -v "$g_tool" >/dev/null 2>&1; then
                # Verify it's actually GNU
                if "$g_tool" --version 2>/dev/null | grep -q "GNU"; then
                    g_tools+=("$g_tool")
                fi
            fi
        done
        
        echo "${g_tools[@]}"
    }
    
    # Main coreutils detection
    local coreutils_impl=$(detect_coreutils_implementation)
    variants+=("coreutils_$coreutils_impl")
    
    # G-prefixed tools detection
    local g_tools=($(detect_g_prefixed_tools))
    if [[ ${#g_tools[@]} -gt 0 ]]; then
        variants+=("gnu_prefixed_tools:${#g_tools[@]}")
        log_debug "Found ${#g_tools[@]} g-prefixed GNU tools: ${g_tools[*]}"
    fi
    
    # Bash version detection
    if [[ -n "$BASH_VERSION" ]]; then
        local bash_major="${BASH_VERSINFO[0]}"
        variants+=("bash_$bash_major")
    fi
    
    # sed variant detection
    if command -v sed >/dev/null 2>&1; then
        if sed --version 2>/dev/null | grep -q "GNU"; then
            variants+=("gnu_sed")
        else
            variants+=("bsd_sed")
        fi
    fi
    
    # awk variant detection
    if command -v gawk >/dev/null 2>&1; then
        variants+=("gawk")
    elif command -v nawk >/dev/null 2>&1; then
        variants+=("nawk")
    elif command -v mawk >/dev/null 2>&1; then
        variants+=("mawk")
    elif command -v awk >/dev/null 2>&1; then
        variants+=("awk_generic")
    fi
    
    # find variant detection
    if command -v find >/dev/null 2>&1; then
        if find --version 2>/dev/null | grep -q "GNU"; then
            variants+=("gnu_find")
        else
            variants+=("bsd_find")
        fi
    fi
    
    echo "${variants[@]}"
}

# Get preferred tool name (handles g-prefixed variants)
get_preferred_tool() {
    local base_tool="$1"
    local platform_family=$(get_platform_family)
    
    # Check for g-prefixed version first on macOS (prefer GNU tools)
    if [[ "$platform_family" == "macos" ]]; then
        local g_tool="g$base_tool"
        if command -v "$g_tool" >/dev/null 2>&1; then
            # Verify it's GNU
            if "$g_tool" --version 2>/dev/null | grep -q "GNU"; then
                echo "$g_tool"
                return 0
            fi
        fi
    fi
    
    # Fall back to base tool
    if command -v "$base_tool" >/dev/null 2>&1; then
        echo "$base_tool"
        return 0
    fi
    
    return 1
}

# ============================================================================
# Enhanced Tool Detection
# ============================================================================

# Enhanced tool checking with version and capability detection
check_tool_enhanced() {
    local tool="$1"
    local quiet="${2:-false}"
    
    # First check if tool exists
    if ! command -v "$tool" >/dev/null 2>&1; then
        [[ "$quiet" == "false" ]] && log_debug "✗ $tool not found in PATH"
        return 1
    fi
    
    local tool_path=$(command -v "$tool")
    
    # Test if tool actually works by trying version command
    local version_output=""
    local version_commands=("--version" "-V" "-v" "-version" "version")
    local working=false
    
    for version_cmd in "${version_commands[@]}"; do
        if version_output=$("$tool" "$version_cmd" 2>/dev/null); then
            working=true
            break
        fi
    done
    
    if [[ "$working" == "true" ]]; then
        [[ "$quiet" == "false" ]] && log_debug "✓ $tool available at $tool_path"
        return 0
    else
        [[ "$quiet" == "false" ]] && log_warn "✗ $tool found but not working: $tool_path"
        return 1
    fi
}

# Get enhanced tool version with implementation details
get_tool_version_enhanced() {
    local tool="$1"
    
    if ! check_tool_enhanced "$tool" true; then
        echo "not_available"
        return 1
    fi
    
    # Try different version flags
    local version_info=""
    local version_commands=("--version" "-V" "-v" "-version" "version")
    
    for version_cmd in "${version_commands[@]}"; do
        if version_info=$("$tool" "$version_cmd" 2>/dev/null | head -1); then
            # Enhance version info with implementation details
            local enhanced_info="$version_info"
            
            # Detect specific implementations
            if echo "$version_info" | grep -q "GNU"; then
                enhanced_info="$enhanced_info (GNU)"
            elif echo "$version_info" | grep -q "uutils"; then
                enhanced_info="$enhanced_info (uutils/Rust)"
            elif echo "$version_info" | grep -q "BSD"; then
                enhanced_info="$enhanced_info (BSD)"
            fi
            
            echo "$enhanced_info"
            return 0
        fi
    done
    
    echo "version_unknown"
    return 0
}

# Check tool capabilities with enhanced detection
check_tool_capabilities() {
    local tool="$1"
    local capability="$2"
    
    if ! check_tool_enhanced "$tool" true; then
        return 1
    fi
    
    # Get capabilities from registry
    local capabilities="${ABADDON_TOOL_CAPABILITIES[$tool]:-basic}"
    
    if [[ "$capabilities" == *"$capability"* ]]; then
        return 0
    else
        return 1
    fi
}

# Get best tool for a task with variant awareness
get_best_tool_enhanced() {
    local task="$1"
    local platform_family=$(get_platform_family)
    
    case "$task" in
        file_search)
            if check_tool_enhanced "fd" true; then
                echo "fd"
            else
                local find_tool=$(get_preferred_tool "find")
                echo "${find_tool:-find}"
            fi
            ;;
        text_search)
            if check_tool_enhanced "rg" true; then
                echo "rg"
            else
                local grep_tool=$(get_preferred_tool "grep")
                echo "${grep_tool:-grep}"
            fi
            ;;
        file_listing)
            if check_tool_enhanced "eza" true; then
                echo "eza"
            else
                local ls_tool=$(get_preferred_tool "ls")
                echo "${ls_tool:-ls}"
            fi
            ;;
        disk_usage)
            if check_tool_enhanced "gdu" true; then
                echo "gdu"
            elif check_tool_enhanced "ncdu" true; then
                echo "ncdu"
            else
                echo "du"
            fi
            ;;
        file_preview)
            if check_tool_enhanced "bat" true; then
                echo "bat"
            else
                local cat_tool=$(get_preferred_tool "cat")
                echo "${cat_tool:-cat}"
            fi
            ;;
        json_processing)
            if check_tool_enhanced "jq" true; then
                echo "jq"
            else
                echo "none"
            fi
            ;;
        yaml_processing)
            if check_tool_enhanced "yq" true; then
                echo "yq"
            else
                echo "none"
            fi
            ;;
        timeout_command)
            # Handle the timeout vs gtimeout situation
            if [[ "$platform_family" == "macos" ]]; then
                if check_tool_enhanced "gtimeout" true; then
                    echo "gtimeout"
                elif check_tool_enhanced "timeout" true; then
                    echo "timeout"
                else
                    echo "none"
                fi
            else
                if check_tool_enhanced "timeout" true; then
                    echo "timeout"
                else
                    echo "none"
                fi
            fi
            ;;
        *)
            log_warn "Unknown task: $task"
            return 1
            ;;
    esac
}

# ============================================================================
# Hardware and Capability Analysis (Non-Intrusive)
# ============================================================================

# Detect development environment capabilities
analyze_development_environment() {
    local analysis=()
    local platform_family=$(get_platform_family)
    local os_type=$(get_os_type)
    
    # Package management capabilities
    local pkg_managers=($(detect_package_managers))
    analysis+=("package_managers:${pkg_managers[*]}")
    
    # Platform variant
    analysis+=("platform:$os_type")
    
    # Tool variants
    local tool_variants=($(detect_tool_variants))
    analysis+=("tool_variants:${tool_variants[*]}")
    
    # System resources (non-intrusive)
    local resources=($(get_system_resources))
    analysis+=("resources:${resources[*]}")
    
    # Network capabilities
    local net_caps=()
    command -v curl >/dev/null && net_caps+=("curl")
    command -v wget >/dev/null && net_caps+=("wget")
    command -v ssh >/dev/null && net_caps+=("ssh")
    analysis+=("network:${net_caps[*]}")
    
    # Development tools
    local dev_tools=()
    command -v git >/dev/null && dev_tools+=("git")
    command -v docker >/dev/null && dev_tools+=("docker")
    command -v make >/dev/null && dev_tools+=("make")
    analysis+=("dev_tools:${dev_tools[*]}")
    
    echo "${analysis[@]}"
}

# ============================================================================
# Flutter-Doctor Style Reporting
# ============================================================================

# Comprehensive environment doctor (Flutter-doctor inspired)
tool_detection_doctor() {
    clear_tool_detection_state
    
    echo -e "${ABADDON_CORE_COLOR_BOLD}🩺 Abaddon Environment Doctor${ABADDON_CORE_COLOR_NC}"
    echo
    
    # System overview
    echo -e "${ABADDON_CORE_COLOR_CYAN}📋 System Information:${ABADDON_CORE_COLOR_NC}"
    local platform=$(get_os_type)
    local arch=$(get_architecture)
    echo "  Platform: $platform"
    echo "  Architecture: $arch"
    
    # Check for constrained environment
    if is_constrained_environment; then
        echo -e "  ${ABADDON_CORE_COLOR_YELLOW}⚠️  Constrained environment detected${ABADDON_CORE_COLOR_NC}"
    fi
    echo
    
    # Package managers
    echo -e "${ABADDON_CORE_COLOR_CYAN}📦 Package Managers:${ABADDON_CORE_COLOR_NC}"
    local pkg_managers=($(detect_package_managers))
    if [[ ${#pkg_managers[@]} -gt 0 ]]; then
        local ranked_managers=($(rank_package_managers "${pkg_managers[@]}"))
        for mgr in "${ranked_managers[@]}"; do
            local mgr_info="${ABADDON_PACKAGE_MANAGERS[$mgr]:-unknown:Unknown package manager:unknown}"
            IFS=':' read -r platform_affinity description install_info <<< "$mgr_info"
            echo "  ✅ $mgr ($description)"
        done
    else
        echo -e "  ${ABADDON_CORE_COLOR_YELLOW}⚠️  No package managers detected${ABADDON_CORE_COLOR_NC}"
    fi
    echo
    
    # Tool variants analysis  
    echo -e "${ABADDON_CORE_COLOR_CYAN}🔧 Tool Variants:${ABADDON_CORE_COLOR_NC}"
    local tool_variants=($(detect_tool_variants))
    for variant in "${tool_variants[@]}"; do
        if [[ "$variant" == coreutils_* ]]; then
            local impl="${variant#coreutils_}"
            case "$impl" in
                gnu) echo "  ✅ GNU coreutils (standard Linux tools)" ;;
                bsd) echo "  ✅ BSD coreutils (macOS/FreeBSD native)" ;;
                uutils) echo "  ✅ uutils coreutils (Rust-powered modern tools)" ;;
                *) echo "  ⚪ Unknown coreutils implementation: $impl" ;;
            esac
        elif [[ "$variant" == gnu_prefixed_tools:* ]]; then
            local count="${variant#gnu_prefixed_tools:}"
            echo "  ✅ GNU prefixed tools available ($count g-prefixed commands)"
        fi
    done
    echo
    
    # Modern development tools
    echo -e "${ABADDON_CORE_COLOR_CYAN}⚡ Modern Development Tools:${ABADDON_CORE_COLOR_NC}"
    check_modern_tools_status
    echo
    
    # Recommendations
    echo -e "${ABADDON_CORE_COLOR_CYAN}💡 Recommendations:${ABADDON_CORE_COLOR_NC}"
    generate_environment_recommendations
    
    set_tool_detection_success
}

# Check status of modern development tools
check_modern_tools_status() {
    local available_tools=()
    local missing_tools=()
    
    for tool in "${!ABADDON_MODERN_TOOLS[@]}"; do
        if check_tool_enhanced "$tool" true; then
            local version=$(get_tool_version_enhanced "$tool")
            echo "  ✅ $tool: $version"
            available_tools+=("$tool")
        else
            local tool_info="${ABADDON_MODERN_TOOLS[$tool]}"
            IFS=':' read -r capability description install_method language <<< "$tool_info"
            echo "  ⚪ $tool: not available ($description)"
            missing_tools+=("$tool")
        fi
    done
    
    ABADDON_TOOL_DETECTION_AVAILABLE_TOOLS="${available_tools[*]}"
    ABADDON_TOOL_DETECTION_MISSING_TOOLS="${missing_tools[*]}"
}

# Generate intelligent recommendations based on environment analysis
generate_environment_recommendations() {
    local pkg_managers=($(detect_package_managers))
    local platform_family=$(get_platform_family)
    local missing_tools=(${ABADDON_TOOL_DETECTION_MISSING_TOOLS})
    
    if [[ ${#pkg_managers[@]} -eq 0 ]]; then
        case "$platform_family" in
            macos)
                echo "  📥 Install Homebrew for easier tool management:"
                echo "     /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                ;;
            linux)
                echo "  📥 Consider installing additional package managers like snap or flatpak"
                ;;
        esac
    fi
    
    if [[ ${#missing_tools[@]} -gt 3 ]]; then
        echo "  🚀 Install modern development tools for enhanced performance"
        echo "  📖 Run 'abaddon tools install' for guided installation"
    fi
    
    # Platform-specific recommendations
    case "$platform_family" in
        macos)
            if ! command -v gtimeout >/dev/null 2>&1; then
                echo "  ⏱️  Consider installing GNU coreutils: brew install coreutils"
            fi
            ;;
    esac
}

# ============================================================================
# Enhanced Installation Suggestions
# ============================================================================

# Enhanced tool installation suggestions with intelligence
suggest_tool_installation_enhanced() {
    local missing_tools=("${@}")
    local platform_family=$(get_platform_family)
    local pkg_managers=($(detect_package_managers))
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        return 0
    fi
    
    echo
    log_info "Missing modern tools detected. Enhanced installation guidance:"
    echo
    
    # Get ranked package managers
    local ranked_managers=()
    if [[ ${#pkg_managers[@]} -gt 0 ]]; then
        ranked_managers=($(rank_package_managers "${pkg_managers[@]}"))
    fi
    
    case "$platform_family" in
        macos)
            suggest_macos_installation "${missing_tools[@]}"
            ;;
        linux)
            suggest_linux_installation "${missing_tools[@]}"
            ;;
        *)
            suggest_universal_installation "${missing_tools[@]}"
            ;;
    esac
    
    echo
    log_info "💡 Pro tips:"
    log_info "  • Restart your shell after installation: source ~/.bash_env && bash"
    log_info "  • Run 'abaddon doctor' to verify installation"
    if [[ ${#ranked_managers[@]} -gt 0 ]]; then
        log_info "  • Primary package manager detected: ${ranked_managers[0]}"
    fi
}

# macOS-specific installation suggestions
suggest_macos_installation() {
    local missing_tools=("$@")
    
    if command -v brew >/dev/null 2>&1; then
        log_info "📦 Homebrew available - recommended installation:"
        echo
        for tool in "${missing_tools[@]}"; do
            local tool_info="${ABADDON_MODERN_TOOLS[$tool]:-}"
            if [[ -n "$tool_info" ]]; then
                IFS=':' read -r capability description install_method language <<< "$tool_info"
                
                case "$tool" in
                    gdu)
                        log_info "  # $tool ($description)"
                        log_info "  brew install gdu"
                        ;;
                    bat|eza|fd|rg)
                        log_info "  brew install $tool"
                        ;;
                    *)
                        log_info "  brew install $tool  # $description"
                        ;;
                esac
            fi
        done
        
        # Additional recommendations
        echo
        log_info "📝 Additional recommendations:"
        log_info "  brew install coreutils  # GNU tools (gtimeout, gls, etc.)"
    else
        log_info "💡 Install Homebrew first for best macOS experience:"
        log_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
}

# Linux-specific installation suggestions
suggest_linux_installation() {
    local missing_tools=("$@")
    local os_type=$(get_os_type)
    
    log_info "🐧 Linux installation suggestions:"
    echo
    
    # Distribution-specific recommendations
    case "$os_type" in
        linux_debian*|linux_ubuntu*)
            log_info "  # Debian/Ubuntu (APT):"
            log_info "  sudo apt update && sudo apt install fd-find ripgrep jq"
            log_info "  cargo install bat eza gdu  # Rust tools"
            ;;
        linux_fedora*|linux_rhel*)
            log_info "  # Fedora/RHEL (DNF):"
            log_info "  sudo dnf install fd-find ripgrep jq"
            log_info "  cargo install bat eza gdu  # Rust tools"
            ;;
        linux_arch*|linux_manjaro*)
            log_info "  # Arch Linux (Pacman):"
            log_info "  sudo pacman -S fd ripgrep eza jq bat"
            log_info "  yay -S gdu  # AUR package"
            ;;
        linux_alpine*)
            log_info "  # Alpine Linux (APK):"
            log_info "  apk add fd ripgrep jq"
            log_info "  cargo install bat eza gdu  # Rust tools"
            ;;
        *)
            log_info "  # Generic Linux (multiple options):"
            log_info "  # Try your distribution's package manager first"
            ;;
    esac
    
    echo
    log_info "  # Universal options:"
    log_info "  cargo install bat eza gdu ripgrep fd-find  # Rust toolchain"
    log_info "  go install github.com/dundee/gdu@latest    # Go toolchain"
}

# Universal installation suggestions
suggest_universal_installation() {
    local missing_tools=("$@")
    
    log_info "🔧 Universal installation options:"
    echo
    log_info "  # Rust toolchain (if available):"
    log_info "  cargo install bat eza gdu ripgrep fd-find"
    echo
    log_info "  # Go toolchain (if available):"
    log_info "  go install github.com/dundee/gdu@latest"
    echo
    log_info "  # Language-specific tools:"
    log_info "  npm install -g @bitnami/jq     # Node.js"
    log_info "  pip install httpie            # Python"
}

# ============================================================================
# State Access Functions
# ============================================================================

get_tool_detection_error_message() { echo "$ABADDON_TOOL_DETECTION_ERROR_MESSAGE"; }
get_available_tools() { echo "$ABADDON_TOOL_DETECTION_AVAILABLE_TOOLS"; }
get_missing_tools() { echo "$ABADDON_TOOL_DETECTION_MISSING_TOOLS"; }
get_detected_package_managers() { echo "$ABADDON_TOOL_DETECTION_PACKAGE_MANAGERS"; }

# Check if last operation succeeded
tool_detection_succeeded() { [[ "$ABADDON_TOOL_DETECTION_STATUS" == "$ABADDON_TOOL_DETECTION_SUCCESS" ]]; }
tool_detection_failed() { [[ "$ABADDON_TOOL_DETECTION_STATUS" == "$ABADDON_TOOL_DETECTION_ERROR" ]]; }

# ============================================================================
# Module Validation and Information
# ============================================================================

# Module validation function (required by framework)
tool_detection_validate() {
    local errors=0
    
    # Check required functions exist
    local required_functions=(
        "detect_package_managers" "detect_tool_variants" "check_tool_enhanced"
        "tool_detection_doctor" "get_best_tool_enhanced" "get_preferred_tool"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_TOOL_DETECTION_STATUS" "ABADDON_TOOL_DETECTION_ERROR_MESSAGE"
        "ABADDON_TOOL_DETECTION_AVAILABLE_TOOLS" "ABADDON_TOOL_DETECTION_MISSING_TOOLS"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    # Check dependencies are loaded
    if [[ -z "${ABADDON_CORE_LOADED:-}" ]]; then
        log_error "Core dependency not loaded"
        ((errors++))
    fi
    
    if [[ -z "${ABADDON_PLATFORM_LOADED:-}" ]]; then
        log_error "Platform dependency not loaded"
        ((errors++))
    fi
    
    return $errors
}

# Module information
tool_detection_info() {
    echo "Abaddon Tool Detection - Flutter-doctor-like intelligent capability detection"
    echo "Version: 1.0.0 - Enhanced platform intelligence"
    echo "Features: Package manager detection, tool variant analysis, capability promotion"
    echo "Dependencies: core.sh, platform.sh"
    echo "Main Functions:"
    echo "  tool_detection_doctor() - Comprehensive environment analysis"
    echo "  detect_package_managers() - Platform-aware package manager detection"
    echo "  get_best_tool_enhanced(task) - Intelligent tool selection with variants"
    echo "  check_tool_enhanced(tool) - Enhanced tool availability checking"
}

# Initialize tool detection analysis on module load
log_debug "Abaddon Tool Detection module loaded successfully - intelligent capabilities active"