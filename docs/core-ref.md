# Abaddon Core Runtime Reference

> **Runtime Documentation**: Real workflows, function chains, and orchestration patterns from the implemented Abaddon modular foundation.

## 📦 **Module Loading**

### **Actual Module Loading Pattern**
```bash
# Real module loading (from abaddon-tests.sh)
source "$(dirname "${BASH_SOURCE[0]}")/abaddon-core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/abaddon-platform.sh" 
source "$(dirname "${BASH_SOURCE[0]}")/abaddon-progress.sh"

# Verify modules loaded
[[ "${ABADDON_CORE_LOADED:-}" == "1" ]]
[[ "${ABADDON_PLATFORM_LOADED:-}" == "1" ]]
[[ "${ABADDON_PROGRESS_LOADED:-}" == "1" ]]
```

### **P2 Utilities Module Loading**
```bash
# Phase 2 modules with dependencies
source "$(dirname "${BASH_SOURCE[0]}")/abaddon-core.sh"      # Required first
source "$(dirname "${BASH_SOURCE[0]}")/abaddon-cache.sh"     # Performance utilities
source "$(dirname "${BASH_SOURCE[0]}")/abaddon-validation.sh" # Security utilities
source "$(dirname "${BASH_SOURCE[0]}")/abaddon-kv.sh"        # Data access service

# Verify enhanced capabilities
[[ "${ABADDON_CACHE_LOADED:-}" == "1" ]]
[[ "${ABADDON_VALIDATION_LOADED:-}" == "1" ]]
[[ "${ABADDON_KV_LOADED:-}" == "1" ]]
```

### **Load Guard Protection (Real Implementation)**
```bash
# From actual module headers
[[ -n "${ABADDON_CORE_LOADED:-}" ]] && return 0
readonly ABADDON_CORE_LOADED=1

# P2 dependency verification
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: P2 modules require abaddon-core.sh" >&2
    return 1
}
```

## 🔧 **Core Functions (Implemented)**

### **Logging System**
```bash
# From abaddon-core.sh
log_debug "Debug message"     # Level 0 - only shown with ABADDON_LOG_LEVEL=0
log_info "Info message"       # Level 1 - default level
log_success "Success message" # Level 2 
log_warn "Warning message"    # Level 3
log_error "Error message"     # Level 4 - always shown

# Configure logging level
export ABADDON_LOG_LEVEL=0  # Show all messages
export ABADDON_LOG_LEVEL=3  # Show warnings and errors only
```

### **Platform Detection**
```bash
# From abaddon-core.sh
platform=$(detect_platform)
echo "$platform"  # → "macos" | "linux_ubuntu" | "linux_debian" | "linux_centos" | "unknown"

# OS-specific capabilities
case "$platform" in
    "macos")
        # Has: homebrew, networksetup, launchctl, pbcopy, open
        ;;
    "linux_ubuntu"|"linux_debian")
        # Has: apt, systemctl, xclip
        ;;
esac
```

### **Tool Management**
```bash
# From abaddon-platform.sh
if check_tool "fd"; then
    version=$(get_tool_version "fd")  # → "fd 8.7.0"
    echo "Found: $version"
fi

# Best tool selection with fallbacks
best_finder=$(get_best_tool "file_search")  # → "fd" or "find"
best_searcher=$(get_best_tool "text_search") # → "rg" or "grep"
best_lister=$(get_best_tool "file_listing")  # → "eza" or "ls"
```

### **Progress Indicators**
```bash
# From abaddon-progress.sh
icon=$(status_icon "success")   # → "✓" or "[OK]"
icon=$(status_icon "error")     # → "✗" or "[ERROR]"
icon=$(status_icon "warning")   # → "⚠" or "[WARN]"
icon=$(status_icon "working")   # → "⚙" or "[WORK]"

# Section headers
section_header "Tool Check" 1    # Large header
section_header "Details" 2       # Medium header
section_header "Notes" 3         # Small header
```

## ⚡ **P2 Utilities Functions (Implemented)**

### **Cache Operations**
```bash
# From abaddon-cache.sh
cached_execute "parse_config" jq '.name' config.json
result=$(get_cached_result)  # Gets the cached output

# Cache statistics
get_cache_stats
# → Cache Statistics:
#   Hit Rate: 71%
#   Operations: 18
#   Memory Entries: 5

# Cache health
check_cache_health  # Returns 0 if healthy, 1 if issues
```

### **Validation Operations**  
```bash
# From abaddon-validation.sh
if validate_and_extract "json" "$content" "project.name" "default"; then
    value=$(get_extracted_value)     # → extracted value
    status=$(get_validation_status)  # → "success"
else
    error=$(get_validation_error)    # → error description
fi

# Path normalization
normalize_query_path "jq" "project.name"  # → ".project.name"
normalize_query_path "yq" "project.name"  # → ".project.name"
normalize_query_path "xq" "project.name"  # → "project.name"
```

### **KV Data Access**
```bash
# From abaddon-kv.sh
get_config_value "project.name" "config.json" "default_value"
project_name=$(get_kv_value)      # → extracted value
format=$(get_kv_format)           # → "json"
tool=$(get_kv_tool)               # → "jq"
status=$(get_kv_status)           # → "success"

# Multi-format support
get_config_value "app.title" "config.yaml"     # Uses yq
get_config_value "build.target" "config.toml"  # Uses tq
get_config_value "server.host" "config.xml"    # Uses xq
```

## 🔧 **P3 Services Functions (Implemented)**

### **i18n Operations**
```bash
# From abaddon-i18n.sh
i18n_init --app-domain="herald" --app-translations="./translations"

# Translation with variables
t "commands.init.description" "my-project" "web"
translated=$(get_i18n_value)  # → "Initialize my-project with web template"

# Domain routing
t "framework.errors.timeout"     # Framework domain
t "herald.build.success"         # Application domain

# Locale support
t "ui.welcome" --locale="es"     # Spanish with English fallback
```

### **Enhanced KV Operations**
```bash
# From abaddon-kv.sh (with i18n integration)
get_config_value "project.name" "config.json" "default_value"
project_name=$(get_kv_value)      # → extracted value
format=$(get_kv_format)           # → "json"
tool=$(get_kv_tool)               # → "jq"
status=$(get_kv_status)           # → "success"

# Multi-format with caching integration
get_config_value "app.title" "config.yaml"     # Uses yq + cache
get_config_value "build.target" "config.toml"  # Uses tq + cache
get_config_value "server.host" "config.xml"    # Uses xq + cache
```

## 🎯 **P4 Runtime Functions (Partial Implementation)**

### **Commands Operations (Implemented)**
```bash
# From abaddon-commands.sh
commands_init "herald"
register_command "build" "$(t 'commands.build.description')" "build_handler" 75

# Command execution
execute_command "build" --target=production
status=$(get_commands_status)        # → "success"
time=$(get_commands_execution_time)  # → "125ms"

# Command discovery
list_commands                        # → Available commands
command_exists "build"               # → true/false
get_command_info "build" "priority"  # → 75
```

### **Help Operations (Needs Integration)**
```bash
# From abaddon-help.sh (existing functionality)
get_help_text "command.init.description" "en"
show_command_help "init"
show_available_commands

# Planned integration (not yet implemented)
show_command_help_i18n "build" "en"    # Commands + i18n integration
list_commands_with_descriptions         # Dynamic discovery
```

## 🧪 **Real Test Patterns (From Tests)**

### **Module Testing Pattern**
```bash
# From tests/*.sh - actual test implementation
test_function_name() {
    source "$(get_module_path core)"
    
    # Test actual functionality
    result=$(log_info "test message")
    [[ $? -eq 0 ]]  # Check exit code
}
```

### **Integration Testing Pattern**  
```bash
# Cross-module data flow (validated working)
source "$(get_module_path core)"
source "$(get_module_path validation)"
source "$(get_module_path cache)"
source "$(get_module_path kv)"

# Real workflow that works
get_config_value "test.key" "test.json" "default"
[[ "$(get_kv_value)" == "expected_value" ]]
[[ "$(get_kv_status)" == "success" ]]
```

## 🎯 **Current Implementation Status**

### **✅ P1 Foundation (100% Complete)**
- **abaddon-core.sh**: Logging, platform detection, utilities (19 functions)
- **abaddon-platform.sh**: Tool management, graceful degradation (14 functions)  
- **abaddon-progress.sh**: Terminal UX, formatting (15 functions)

### **✅ P2 Performance & Security Layer (100% Complete)**
- **abaddon-cache.sh**: Performance optimization (23 functions)
- **abaddon-validation.sh**: Security & validation (25 functions)
- **abaddon-kv.sh**: Data access service (23 functions)

### **🔄 P3 Data & Communication Services (66% Complete)**
- **abaddon-i18n.sh**: Translation registry (17 functions) ✅
- **abaddon-http.sh**: HTTP client with KV integration 🚧

### **🚧 P4 Application Primitives (0% Complete)**
- **abaddon-state-machine.sh**: Generic state management primitive 🚧
- **abaddon-commands.sh**: Command registry with validation hooks 🔄
- **abaddon-templates.sh**: Variable substitution engine 🚧
- **abaddon-workflows.sh**: Task orchestration primitive 🚧
- **abaddon-help.sh**: Documentation framework 🚧

---

*Reference Status: ✅ P1 Foundation Complete | ✅ P2 Performance & Security Complete | 🔄 P3 Data & Communication 66% Complete | 🚧 P4 Application Primitives 0% Complete*