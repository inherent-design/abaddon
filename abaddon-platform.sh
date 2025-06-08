#!/usr/bin/env bash
# Abaddon Platform - Opinionated tool management and promotion system
# Fail-fast tool validation with clear installation guidance

# Guard against multiple loads
[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] && return 0
readonly ABADDON_PLATFORM_LOADED=1

# Require abaddon-core for logging
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-platform.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

# Modern tool registry - detects tools regardless of installation source
# Format: "tool_name:common_path:description:suggested_source"
declare -A MODERN_TOOLS=(
    ["fd"]="/opt/homebrew/bin/fd:Fast file finding:distro packages or brew"
    ["rg"]="/opt/homebrew/bin/rg:Fast text search:distro packages or brew"
    ["eza"]="/opt/homebrew/bin/eza:Modern file listing:cargo/brew/distro packages"
    ["gdu"]="/opt/homebrew/bin/gdu:Fast disk usage analyzer:go toolchain recommended"
    ["bat"]="~/.cargo/bin/bat:Syntax highlighted file viewer:cargo recommended"
    ["jq"]="/opt/homebrew/bin/jq:JSON processor:distro packages or brew"
    ["yq"]="/opt/homebrew/bin/yq:YAML processor:distro packages or brew"
)

# Platform-specific tools that are optional but recommended
declare -A PLATFORM_TOOLS=(
    # macOS specific
    ["networksetup"]="/usr/sbin/networksetup:Network configuration:Built-in macOS tool"
    ["brew"]="/opt/homebrew/bin/brew:Package manager:See https://brew.sh"
    
    # Cross-platform utilities
    ["git"]="/usr/bin/git:Version control:Usually pre-installed"
    ["curl"]="/usr/bin/curl:HTTP client:Usually pre-installed"
    ["jq"]="/opt/homebrew/bin/jq:JSON processor:See modern tools suggestions"
)

# Tool capability definitions
declare -A TOOL_CAPABILITIES=(
    ["fd"]="parallel_search,type_filtering,ignore_patterns,json_output"
    ["rg"]="parallel_search,json_output,type_filtering,context_lines,multiline"
    ["eza"]="rich_listing,json_output,git_status,tree_view,icons,colors"
    ["gdu"]="json_output,progress_display,parallel_analysis,interactive_mode"
    ["bat"]="syntax_highlighting,git_integration,paging,themes"
    ["jq"]="json_parsing,filtering,transformation,streaming"
    ["yq"]="yaml_parsing,json_conversion,filtering,transformation"
)

# Get tool information
get_tool_info() {
    local tool="$1"
    local info_type="${2:-all}"
    
    if [[ -n "${MODERN_TOOLS[$tool]:-}" ]]; then
        IFS=':' read -r expected_path description install_cmd <<<"${MODERN_TOOLS[$tool]}"
    elif [[ -n "${PLATFORM_TOOLS[$tool]:-}" ]]; then
        IFS=':' read -r expected_path description install_cmd <<<"${PLATFORM_TOOLS[$tool]}"
    else
        log_warn "Unknown tool: $tool"
        return 1
    fi
    
    case "$info_type" in
        path) echo "$expected_path" ;;
        description) echo "$description" ;;
        install) echo "$install_cmd" ;;
        capabilities) echo "${TOOL_CAPABILITIES[$tool]:-basic}" ;;
        all) 
            echo "Path: $expected_path"
            echo "Description: $description"
            echo "Install: $install_cmd"
            echo "Capabilities: ${TOOL_CAPABILITIES[$tool]:-basic}"
            ;;
        *) 
            log_error "Invalid info type: $info_type"
            return 1
            ;;
    esac
}

# Check if a tool is available and working
check_tool() {
    local tool="$1"
    local quiet="${2:-false}"
    
    if command -v "$tool" >/dev/null 2>&1; then
        local tool_path
        tool_path=$(command -v "$tool")
        
        # Test if tool actually works
        if "$tool" --version >/dev/null 2>&1 || "$tool" -V >/dev/null 2>&1 || "$tool" -v >/dev/null 2>&1 || "$tool" -version >/dev/null 2>&1; then
            [[ "$quiet" == "false" ]] && log_debug "✓ $tool available at $tool_path"
            return 0
        else
            [[ "$quiet" == "false" ]] && log_warn "✗ $tool found but not working: $tool_path"
            return 1
        fi
    else
        [[ "$quiet" == "false" ]] && log_debug "✗ $tool not found in PATH"
        return 1
    fi
}

# Get tool version
get_tool_version() {
    local tool="$1"
    
    if ! check_tool "$tool" true; then
        echo "not_available"
        return 1
    fi
    
    # Try different version flags
    local version
    if version=$("$tool" --version 2>/dev/null | head -1); then
        echo "$version"
    elif version=$("$tool" -V 2>/dev/null | head -1); then
        echo "$version"
    elif version=$("$tool" -v 2>/dev/null | head -1); then
        echo "$version"
    elif version=$("$tool" -version 2>/dev/null | head -1); then
        echo "$version"
    elif version=$("$tool" version 2>/dev/null | head -1); then
        echo "$version"
    else
        echo "unknown"
    fi
}

# Check tool availability and suggest installations (respects user environment)
check_tool_availability() {
    local required_tools=("${@:-fd rg eza gdu}")
    local missing_tools=()
    local working_tools=()
    local suggest_only="${ABLADDON_SUGGEST_ONLY:-false}"
    
    log_info "Checking modern tool availability..."
    
    for tool in "${required_tools[@]}"; do
        if check_tool "$tool" true; then
            local version
            version=$(get_tool_version "$tool")
            working_tools+=("$tool")
            log_success "$tool: $version"
        else
            missing_tools+=("$tool")
            local description
            description=$(get_tool_info "$tool" description 2>/dev/null || echo "Modern development tool")
            log_warn "Optional: $tool ($description)"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        if [[ "$suggest_only" == "true" ]]; then
            log_info "Found ${#working_tools[@]}/${#required_tools[@]} modern tools"
            suggest_tool_installation "${missing_tools[@]}"
            return 0  # Don't fail in suggestion mode
        else
            echo
            log_info "Modern tools enhance performance but are optional"
            log_info "Available: ${#working_tools[@]}/${#required_tools[@]} tools"
            suggest_tool_installation "${missing_tools[@]}"
            return 1  # Indicate missing tools for stricter callers
        fi
    fi
    
    log_success "All modern tools available (${#working_tools[@]}/${#required_tools[@]} tools)"
    return 0
}

# Backward compatibility alias (deprecated - use check_tool_availability)
promote_required_tools() {
    log_warn "promote_required_tools is deprecated - use check_tool_availability"
    check_tool_availability "$@"
}

# Check tool capabilities
has_capability() {
    local tool="$1"
    local capability="$2"
    
    if ! check_tool "$tool" true; then
        return 1
    fi
    
    local capabilities
    capabilities=$(get_tool_info "$tool" capabilities 2>/dev/null || echo "basic")
    
    if [[ "$capabilities" == *"$capability"* ]]; then
        return 0
    else
        return 1
    fi
}

# Get best tool for a task
get_best_tool() {
    local task="$1"
    
    case "$task" in
        file_search)
            if check_tool "fd" true; then
                echo "fd"
            else
                echo "find"
            fi
            ;;
        text_search)
            if check_tool "rg" true; then
                echo "rg"
            else
                echo "grep"
            fi
            ;;
        file_listing)
            if check_tool "eza" true; then
                echo "eza"
            else
                echo "ls"
            fi
            ;;
        disk_usage)
            if check_tool "gdu" true; then
                echo "gdu"
            elif check_tool "gdu-go" true; then
                echo "gdu-go"
            elif check_tool "ncdu" true; then
                echo "ncdu"
            else
                echo "du"
            fi
            ;;
        file_preview)
            if check_tool "bat" true; then
                echo "bat"
            else
                echo "cat"
            fi
            ;;
        json_processing)
            if check_tool "jq" true; then
                echo "jq"
            else
                echo "none"
            fi
            ;;
        *)
            log_warn "Unknown task: $task"
            return 1
            ;;
    esac
}

# Suggest tool installation options (respects user choice and environment)
suggest_tool_installation() {
    local missing_tools=("${@}")
    local platform
    platform=$(detect_platform)
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        return 0
    fi
    
    echo
    log_info "Missing modern tools detected. Installation suggestions:"
    echo
    
    case "$platform" in
        macos)
            if command -v brew >/dev/null 2>&1; then
                log_info "📦 Homebrew available - suggested commands:"
                for tool in "${missing_tools[@]}"; do
                    local install_cmd
                    install_cmd=$(get_tool_info "$tool" install 2>/dev/null || echo "Check tool documentation")
                    if [[ "$install_cmd" == *"brew"* ]]; then
                        log_info "  $install_cmd"
                    elif [[ "$tool" == "gdu" ]]; then
                        log_info "  # gdu: Multiple options available"
                        log_info "  brew install gdu              # Homebrew (recommended)"
                        log_info "  go install github.com/dundee/gdu@latest  # Go toolchain"
                    elif [[ "$tool" == "bat" ]]; then
                        log_info "  # bat: Multiple options available"
                        log_info "  brew install bat              # Homebrew"
                        log_info "  cargo install bat            # Rust toolchain (recommended)"
                    else
                        log_info "  $install_cmd"
                    fi
                done
            else
                log_info "💡 Consider installing Homebrew for easier tool management:"
                log_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            fi
            ;;
        linux_*)
            log_info "🐧 Linux installation suggestions (choose based on your distro):"
            log_info "  # Debian/Ubuntu:"
            log_info "  sudo apt update && sudo apt install fd-find ripgrep jq"
            log_info "  # Fedora/RHEL:"
            log_info "  sudo dnf install fd-find ripgrep jq"
            log_info "  # Arch Linux:"
            log_info "  sudo pacman -S fd ripgrep eza jq"
            echo
            log_info "  # Universal options:"
            log_info "  cargo install bat eza gdu      # Rust toolchain"
            log_info "  go install github.com/dundee/gdu@latest  # Go toolchain"
            ;;
        *)
            log_info "🔧 Universal installation options:"
            log_info "  # Rust toolchain (if available):"
            log_info "  cargo install bat eza gdu ripgrep fd-find"
            log_info "  # Go toolchain (if available):"
            log_info "  go install github.com/dundee/gdu@latest"
            ;;
    esac
    
    echo
    log_info "💡 Pro tip: Use 'abaddon brew' to manage Homebrew packages safely"
    log_info "After installation, restart your shell or run: source ~/.bash_env && bash"
    echo
}

# Validate development environment
validate_development_environment() {
    local platform
    platform=$(detect_platform)
    
    log_info "Validating development environment for $platform..."
    
    # Check shell environment
    if [[ -z "${BASH_VERSION:-}" ]]; then
        log_warn "Not running in bash - some features may not work"
    else
        log_debug "Bash version: $BASH_VERSION"
        
        # Check for modern bash features
        if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
            log_debug "Modern bash features available"
        else
            log_warn "Old bash version - consider upgrading"
        fi
    fi
    
    # Check PATH configuration
    if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        log_debug "Local bin directory in PATH"
    else
        log_warn "Local bin directory not in PATH"
    fi
    
    # Check for common development tools
    local dev_tools=("git" "curl" "jq")
    for tool in "${dev_tools[@]}"; do
        if check_tool "$tool" true; then
            log_debug "✓ $tool available"
        else
            log_warn "✗ $tool not available"
        fi
    done
    
    # Platform-specific checks
    case "$platform" in
        macos)
            if check_tool "brew" true; then
                log_debug "✓ Homebrew available"
                # Check if homebrew path is in PATH
                if [[ ":$PATH:" == *":/opt/homebrew/bin:"* ]]; then
                    log_debug "✓ Homebrew in PATH"
                else
                    log_warn "Homebrew not properly configured in PATH"
                fi
            else
                log_warn "✗ Homebrew not available - required for modern tools"
            fi
            ;;
        linux_*)
            if check_tool "systemctl" true; then
                log_debug "✓ systemd available"
            else
                log_debug "Non-systemd Linux system"
            fi
            ;;
    esac
    
    return 0
}

# Show comprehensive tool status
show_tool_status() {
    local show_all="${1:-false}"
    
    echo -e "${BOLD}=== Modern Tool Status ===${NC}\n"
    
    # Core modern tools
    echo -e "${CYAN}Core Modern Tools:${NC}"
    for tool in fd rg eza gdu; do
        if check_tool "$tool" true; then
            local version capabilities
            version=$(get_tool_version "$tool")
            capabilities=$(get_tool_info "$tool" capabilities 2>/dev/null || echo "basic")
            echo "  ✅ $tool: $version"
            [[ "$show_all" == "true" ]] && echo "     Capabilities: $capabilities"
        else
            local description
            description=$(get_tool_info "$tool" description 2>/dev/null || echo "Modern development tool")
            echo "  ⚪ $tool: not available"
            [[ "$show_all" == "true" ]] && echo "     Description: $description"
        fi
    done
    
    # Optional tools
    echo -e "\n${CYAN}Optional Tools:${NC}"
    for tool in bat jq yq; do
        if check_tool "$tool" true; then
            local version
            version=$(get_tool_version "$tool")
            echo "  ✅ $tool: $version"
        else
            echo "  ⚪ $tool: not available (optional)"
        fi
    done
    
    # Platform tools
    if [[ "$show_all" == "true" ]]; then
        echo -e "\n${CYAN}Platform Tools:${NC}"
        local platform
        platform=$(detect_platform)
        case "$platform" in
            macos)
                for tool in brew networksetup; do
                    if check_tool "$tool" true; then
                        echo "  ✅ $tool: available"
                    else
                        echo "  ❌ $tool: not available"
                    fi
                done
                ;;
            linux_*)
                for tool in systemctl xclip; do
                    if check_tool "$tool" true; then
                        echo "  ✅ $tool: available"
                    else
                        echo "  ⚪ $tool: not available"
                    fi
                done
                ;;
        esac
    fi
}

log_debug "Abaddon Platform module loaded successfully"