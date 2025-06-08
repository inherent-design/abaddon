# Abaddon Core Runtime Reference

> **Runtime Documentation**: Real workflows, function chains, and orchestration patterns from the implemented Abladdon modular foundation.

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

### **Phase 2 Module Loading**
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

# Phase 2 dependency verification
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: Phase 2 modules require abaddon-core.sh" >&2
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

## ⚡ **Phase 2 Functions (Implemented)**

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

### **✅ Fully Implemented & Tested (100% Coverage)**
- **abaddon-core.sh**: Logging, platform detection, utilities (19 functions)
- **abaddon-platform.sh**: Tool management, graceful degradation (14 functions)  
- **abaddon-progress.sh**: Terminal UX, formatting (15 functions)
- **abaddon-cache.sh**: Performance optimization (23 functions)
- **abaddon-validation.sh**: Security & validation (25 functions)
- **abaddon-kv.sh**: Data access service (23 functions)

### **🔄 Application Layer (Partial)**
- **abaddon-help.sh**: Token resolution (existing, needs updates)

### **❌ Not Yet Implemented**
- **abaddon-i18n.sh**: Translation registry
- **abaddon-runtime.sh**: Central orchestrator

---

*Reference Status: ✅ Phase 1 Complete | ✅ Phase 2 Complete | 🎯 Phase 3 Application Layer Ready*