#!/usr/bin/env bash
# Abaddon KV - Enhanced Key/Value Abstraction Layer
# Version: 2.0.0
# Purpose: Tool-agnostic interface using validation.sh and cache.sh

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_KV_LOADED:-}" ]] && return 0
readonly ABADDON_KV_LOADED=1

# Dependency checks (bottom-up order)
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-kv.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_CACHE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-kv.sh requires abaddon-cache.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_VALIDATION_LOADED:-}" ]] || {
    echo "ERROR: abaddon-kv.sh requires abaddon-validation.sh to be loaded first" >&2
    return 1
}

# State variables - NO stdout pollution
declare -g KV_STATE_VALUE=""
declare -g KV_STATE_STATUS=""
declare -g KV_STATE_FORMAT=""
declare -g KV_STATE_TOOL=""
declare -g KV_STATE_FILE=""
declare -g KV_STATE_PATH=""

# KV result constants
readonly KV_SUCCESS="success"
readonly KV_ERROR="error"
readonly KV_NOT_FOUND="not_found"
readonly KV_INVALID_FILE="invalid_file"

# Tool availability cache
declare -A KV_TOOL_AVAILABLE
declare -g KV_TOOLS_DETECTED=""

# Performance tracking
declare -g KV_OPERATIONS=0
declare -g KV_CACHE_HITS=0

# ============================================================================
# Tool Detection and Management
# ============================================================================

# Detect and cache available data extraction tools
detect_kv_tools() {
    if [[ -n "$KV_TOOLS_DETECTED" ]]; then
        return 0
    fi
    
    log_debug "Detecting KV tools"
    
    # Check all supported tools
    local tools=("jq" "yq" "xq" "tq")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            KV_TOOL_AVAILABLE["$tool"]="true"
            log_debug "$tool: available"
        else
            KV_TOOL_AVAILABLE["$tool"]="false"
            log_debug "$tool: not available"
        fi
    done
    
    KV_TOOLS_DETECTED="true"
    log_debug "Tool detection complete"
}

# Get appropriate tool for format
get_tool_for_format() {
    local format="$1"
    
    case "$format" in
        json)
            if [[ "${KV_TOOL_AVAILABLE[jq]}" == "true" ]]; then
                echo "jq"
                return 0
            fi
            ;;
        yaml|yml)
            if [[ "${KV_TOOL_AVAILABLE[yq]}" == "true" ]]; then
                echo "yq"
                return 0
            fi
            ;;
        toml)
            if [[ "${KV_TOOL_AVAILABLE[tq]}" == "true" ]]; then
                echo "tq"
                return 0
            fi
            ;;
        xml)
            if [[ "${KV_TOOL_AVAILABLE[xq]}" == "true" ]]; then
                echo "xq"
                return 0
            fi
            ;;
        *)
            return 1
            ;;
    esac
    
    return 1
}

# ============================================================================
# File Format Detection
# ============================================================================

# Detect file format using validation.sh
detect_file_format() {
    local file_path="$1"
    
    # First validate file exists and is readable
    if ! validate_file_exists "$file_path"; then
        return 1
    fi
    
    local file_content
    if ! file_content=$(cat "$file_path" 2>/dev/null); then
        return 1
    fi
    
    # Try different formats in order of likelihood
    local formats=("json" "yaml" "toml" "xml")
    for format in "${formats[@]}"; do
        if validate_and_extract "$format" "$file_content" ""; then
            KV_STATE_FORMAT="$format"
            log_debug "Detected format: $format for $file_path"
            return 0
        fi
    done
    
    # Fallback to file extension
    case "${file_path##*.}" in
        json) KV_STATE_FORMAT="json" ;;
        yaml|yml) KV_STATE_FORMAT="yaml" ;;
        toml) KV_STATE_FORMAT="toml" ;;
        xml) KV_STATE_FORMAT="xml" ;;
        *)
            KV_STATE_FORMAT="unknown"
            log_error "Unable to detect format for: $file_path"
            return 1
            ;;
    esac
    
    log_debug "Format detected by extension: $KV_STATE_FORMAT"
    return 0
}

# ============================================================================
# Core KV Operations with Caching
# ============================================================================

# Reset KV state
reset_kv_state() {
    KV_STATE_VALUE=""
    KV_STATE_STATUS=""
    KV_STATE_FORMAT=""
    KV_STATE_TOOL=""
    KV_STATE_FILE=""
    KV_STATE_PATH=""
}

# Set KV error state
set_kv_error() {
    local error_message="$1"
    KV_STATE_VALUE="$error_message"
    KV_STATE_STATUS="error"
    log_error "KV Error: $error_message"
}

# Set KV success state
set_kv_success() {
    local value="$1"
    KV_STATE_VALUE="$value"
    KV_STATE_STATUS="success"
    log_debug "KV Success: extracted value"
}

# Execute cached file parsing
execute_cached_extraction() {
    local file_path="$1"
    local abaddon_path="$2"
    local default_value="${3:-}"
    
    KV_OPERATIONS=$((KV_OPERATIONS + 1))
    
    # Generate cache key
    local cache_key
    cache_key=$(generate_cache_key "kv_extract" "$file_path:$abaddon_path:$KV_STATE_FORMAT")
    
    # Try cache first
    local cached_result
    if cached_result=$(cache_get "$cache_key"); then
        KV_CACHE_HITS=$((KV_CACHE_HITS + 1))
        set_kv_success "$cached_result"
        log_debug "Cache hit for: $abaddon_path in $file_path"
        return 0
    fi
    
    # Cache miss - perform extraction
    local file_content
    if ! file_content=$(cat "$file_path" 2>/dev/null); then
        set_kv_error "Cannot read file: $file_path"
        return 1
    fi
    
    # Use validation.sh for extraction with normalized paths
    if validate_and_extract "$KV_STATE_FORMAT" "$file_content" "$abaddon_path" "$default_value"; then
        local extracted_value
        extracted_value=$(get_extracted_value)
        
        # Cache successful extraction
        cache_store "$cache_key" "$extracted_value"
        set_kv_success "$extracted_value"
        return 0
    else
        local validation_error
        validation_error=$(get_validation_error)
        set_kv_error "Extraction failed: $validation_error"
        return 1
    fi
}

# ============================================================================
# Public Interface
# ============================================================================

# Main entry point for key/value retrieval
# Uses Abaddon path syntax: "project.name", "build.targets[0]"
get_config_value() {
    local abaddon_path="$1"
    local file_path="$2"
    local default_value="${3:-}"
    
    reset_kv_state
    KV_STATE_FILE="$file_path"
    KV_STATE_PATH="$abaddon_path"
    
    # Input validation using validation.sh
    if [[ -z "$abaddon_path" ]] || [[ -z "$file_path" ]]; then
        set_kv_error "Path and file are required"
        return 1
    fi
    
    # Validate file path
    if ! validate_file_exists "$file_path"; then
        local validation_error
        validation_error=$(get_validation_error)
        set_kv_error "File validation failed: $validation_error"
        return 1
    fi
    
    # Detect available tools
    detect_kv_tools
    
    # Detect file format
    if ! detect_file_format "$file_path"; then
        set_kv_error "Unable to detect file format"
        return 1
    fi
    
    # Get appropriate tool
    local tool
    if ! tool=$(get_tool_for_format "$KV_STATE_FORMAT"); then
        set_kv_error "No tool available for format: $KV_STATE_FORMAT"
        return 1
    fi
    
    KV_STATE_TOOL="$tool"
    
    # Execute extraction with caching
    if execute_cached_extraction "$file_path" "$abaddon_path" "$default_value"; then
        log_debug "Successfully extracted '$abaddon_path' from '$file_path': $KV_STATE_VALUE"
        return 0
    else
        return 1
    fi
}

# Check if key exists (no caching, quick check)
kv_key_exists() {
    local abaddon_path="$1"
    local file_path="$2"
    
    get_config_value "$abaddon_path" "$file_path" >/dev/null 2>&1
    [[ "$KV_STATE_STATUS" == "success" ]]
}

# Get multiple values efficiently with batch caching
get_config_values() {
    local file_path="$1"
    shift
    local paths=("$@")
    
    if [[ ${#paths[@]} -eq 0 ]]; then
        log_error "No paths provided for batch extraction"
        return 1
    fi
    
    # Use batch operations for performance
    local operations=()
    for path in "${paths[@]}"; do
        operations+=("get_config_value \"$path\" \"$file_path\"")
    done
    
    # Execute batch
    batch_operations "kv_batch_extract" "${operations[@]}"
    
    # Results are stored in individual KV_STATE_VALUE calls
    return $?
}

# Validate configuration file against schema
validate_config_file() {
    local file_path="$1"
    local schema_file="${2:-}"
    
    reset_kv_state
    
    # Validate file exists
    if ! validate_file_exists "$file_path"; then
        local validation_error
        validation_error=$(get_validation_error)
        set_kv_error "Config file validation failed: $validation_error"
        return 1
    fi
    
    # Detect format
    if ! detect_file_format "$file_path"; then
        set_kv_error "Cannot detect config file format"
        return 1
    fi
    
    # Read file content
    local file_content
    if ! file_content=$(cat "$file_path" 2>/dev/null); then
        set_kv_error "Cannot read config file"
        return 1
    fi
    
    # Validate content based on format
    case "$KV_STATE_FORMAT" in
        json)
            if [[ -n "$schema_file" ]]; then
                if validate_json_schema "$file_content" "$schema_file"; then
                    set_kv_success "valid"
                    return 0
                else
                    local validation_error
                    validation_error=$(get_validation_error)
                    set_kv_error "JSON schema validation failed: $validation_error"
                    return 1
                fi
            else
                if validate_json_content "$file_content"; then
                    set_kv_success "valid"
                    return 0
                else
                    local validation_error
                    validation_error=$(get_validation_error)
                    set_kv_error "JSON validation failed: $validation_error"
                    return 1
                fi
            fi
            ;;
        yaml)
            if validate_yaml_content "$file_content"; then
                set_kv_success "valid"
                return 0
            else
                local validation_error
                validation_error=$(get_validation_error)
                set_kv_error "YAML validation failed: $validation_error"
                return 1
            fi
            ;;
        toml)
            if validate_toml_content "$file_content"; then
                set_kv_success "valid"
                return 0
            else
                local validation_error
                validation_error=$(get_validation_error)
                set_kv_error "TOML validation failed: $validation_error"
                return 1
            fi
            ;;
        xml)
            if validate_xml_content "$file_content"; then
                set_kv_success "valid"
                return 0
            else
                local validation_error
                validation_error=$(get_validation_error)
                set_kv_error "XML validation failed: $validation_error"
                return 1
            fi
            ;;
        *)
            set_kv_error "Unsupported format for validation: $KV_STATE_FORMAT"
            return 1
            ;;
    esac
}

# ============================================================================
# State Access Functions
# ============================================================================

# Get current KV state
get_kv_status() { echo "$KV_STATE_STATUS"; }
get_kv_value() { echo "$KV_STATE_VALUE"; }
get_kv_format() { echo "$KV_STATE_FORMAT"; }
get_kv_tool() { echo "$KV_STATE_TOOL"; }
get_kv_file() { echo "$KV_STATE_FILE"; }
get_kv_path() { echo "$KV_STATE_PATH"; }

# Check if last operation succeeded
kv_succeeded() { [[ "$KV_STATE_STATUS" == "success" ]]; }
kv_failed() { [[ "$KV_STATE_STATUS" != "success" ]]; }

# ============================================================================
# Performance and Statistics
# ============================================================================

# Get KV performance statistics
get_kv_stats() {
    local hit_rate=0
    if (( KV_OPERATIONS > 0 )); then
        hit_rate=$(( KV_CACHE_HITS * 100 / KV_OPERATIONS ))
    fi
    
    echo "KV Statistics:"
    echo "  Operations: $KV_OPERATIONS"
    echo "  Cache Hits: $KV_CACHE_HITS"
    echo "  Cache Hit Rate: ${hit_rate}%"
    echo "  Available Tools: $(printf '%s ' "${!KV_TOOL_AVAILABLE[@]}")"
    echo "  Last File: $KV_STATE_FILE"
    echo "  Last Format: $KV_STATE_FORMAT"
    echo "  Last Tool: $KV_STATE_TOOL"
}

# ============================================================================
# Module Validation and Information
# ============================================================================

# Validate module functionality
kv_validate() {
    local errors=0
    
    # Check required functions exist
    local required_functions=(
        "get_config_value" "kv_key_exists" "get_config_values"
        "validate_config_file" "detect_kv_tools" "detect_file_format"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "KV_STATE_VALUE" "KV_STATE_STATUS" "KV_STATE_FORMAT" 
        "KV_STATE_TOOL" "KV_STATE_FILE" "KV_STATE_PATH"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    # Check dependencies are loaded
    if [[ -z "${ABADDON_CACHE_LOADED:-}" ]]; then
        log_error "Cache dependency not loaded"
        ((errors++))
    fi
    
    if [[ -z "${ABADDON_VALIDATION_LOADED:-}" ]]; then
        log_error "Validation dependency not loaded"
        ((errors++))
    fi
    
    return $errors
}

# Module information
kv_info() {
    echo "Abaddon KV - Enhanced Key/Value Abstraction Layer"
    echo "Version: 2.0.0"
    echo "Dependencies: cache.sh, validation.sh"
    echo "Supported Formats: JSON, YAML, TOML, XML"
    echo "Features: Caching, validation, normalized paths"
    echo "Main Functions:"
    echo "  get_config_value(path, file, [default])"
    echo "  kv_key_exists(path, file)"
    echo "  get_config_values(file, path1, path2, ...)"
    echo "  validate_config_file(file, [schema])"
}

# Initialize tools on module load
detect_kv_tools

log_debug "Abaddon KV module v2.0.0 loaded with caching and validation"