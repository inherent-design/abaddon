#!/usr/bin/env bash
# Abaddon KV - Enhanced Key/Value Abstraction Layer
# Version: 2.0.0
# Purpose: Tool-agnostic interface using validation.sh and cache.sh

set -u # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_KV_LOADED:-}" ]] && return 0
readonly ABADDON_KV_LOADED=1

# Dependency checks (bottom-up order)
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-kv.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] || {
    echo "ERROR: abaddon-kv.sh requires abaddon-platform.sh to be loaded first" >&2
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
declare -g ABADDON_KV_VALUE=""
declare -g ABADDON_KV_STATUS=""
declare -g ABADDON_KV_FORMAT=""
declare -g ABADDON_KV_TOOL=""
declare -g ABADDON_KV_FILE=""
declare -g ABADDON_KV_PATH=""
declare -g ABADDON_KV_SOURCE=""

# KV result constants
readonly ABADDON_KV_SUCCESS="success"
readonly ABADDON_KV_ERROR="error"
readonly ABADDON_KV_NOT_FOUND="not_found"
readonly ABADDON_KV_INVALID_FILE="invalid_file"

# Removed tool detection - Platform module is authority for tool detection

# Performance tracking
declare -g ABADDON_KV_OPERATIONS=0
declare -g ABADDON_KV_CACHE_HITS=0

# KV module state variables (following framework pattern)
declare -g ABADDON_KV_ERROR_MESSAGE=""

# ============================================================================
# Tool Management - Uses Platform Authority
# ============================================================================

# Get appropriate tool for format using Platform authority
get_tool_for_format() {
    local format="$1"

    case "$format" in
    json)
        local tool
        tool=$(get_best_tool "json_processing")
        if [[ "$tool" != "none" ]]; then
            echo "$tool"
            return 0
        fi
        ;;
    yaml | yml)
        local tool
        tool=$(get_best_tool "yaml_processing")
        if [[ "$tool" != "none" ]]; then
            echo "$tool"
            return 0
        fi
        ;;
    toml)
        local tool
        tool=$(get_best_tool "toml_processing")
        if [[ "$tool" != "none" ]]; then
            echo "$tool"
            return 0
        fi
        ;;
    xml)
        local tool
        tool=$(get_best_tool "xml_processing")
        if [[ "$tool" != "none" ]]; then
            echo "$tool"
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
            ABADDON_KV_FORMAT="$format"
            log_debug "Detected format: $format for $file_path"
            return 0
        fi
    done

    # Fallback to file extension
    case "${file_path##*.}" in
    json) ABADDON_KV_FORMAT="json" ;;
    yaml | yml) ABADDON_KV_FORMAT="yaml" ;;
    toml) ABADDON_KV_FORMAT="toml" ;;
    xml) ABADDON_KV_FORMAT="xml" ;;
    *)
        ABADDON_KV_FORMAT="unknown"
        log_error "Unable to detect format for: $file_path"
        return 1
        ;;
    esac

    log_debug "Format detected by extension: $ABADDON_KV_FORMAT"
    return 0
}

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all Abaddon modules)
# ============================================================================

# Clear all KV module state variables
clear_kv_state() {
    ABADDON_KV_VALUE=""
    ABADDON_KV_STATUS=""
    ABADDON_KV_ERROR_MESSAGE=""
    ABADDON_KV_FORMAT=""
    ABADDON_KV_TOOL=""
    ABADDON_KV_FILE=""
    ABADDON_KV_PATH=""
    ABADDON_KV_SOURCE=""
    ABADDON_KV_OPERATIONS=0
    ABADDON_KV_CACHE_HITS=0
    log_debug "KV module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_kv_status() {
    if [[ "$ABADDON_KV_STATUS" == "$ABADDON_KV_SUCCESS" ]]; then
        echo "ready"
    elif [[ "$ABADDON_KV_STATUS" == "$ABADDON_KV_ERROR" ]]; then
        echo "error"
    elif [[ -n "${ABADDON_CORE_LOADED:-}" && -n "${ABADDON_PLATFORM_LOADED:-}" && -n "${ABADDON_CACHE_LOADED:-}" && -n "${ABADDON_VALIDATION_LOADED:-}" ]]; then
        echo "ready"
    else
        echo "incomplete"
    fi
}

# Export KV state for cross-module access
export_kv_state() {
    echo "ABADDON_KV_STATUS='$ABADDON_KV_STATUS'"
    echo "ABADDON_KV_ERROR_MESSAGE='$ABADDON_KV_ERROR_MESSAGE'"
    echo "ABADDON_KV_VALUE='$ABADDON_KV_VALUE'"
    echo "ABADDON_KV_FORMAT='$ABADDON_KV_FORMAT'"
    echo "ABADDON_KV_TOOL='$ABADDON_KV_TOOL'"
    echo "ABADDON_KV_FILE='$ABADDON_KV_FILE'"
    echo "ABADDON_KV_PATH='$ABADDON_KV_PATH'"
    echo "ABADDON_KV_SOURCE='$ABADDON_KV_SOURCE'"
    echo "ABADDON_KV_OPERATIONS='$ABADDON_KV_OPERATIONS'"
    echo "ABADDON_KV_CACHE_HITS='$ABADDON_KV_CACHE_HITS'"
}

# Validate KV module state consistency
validate_kv_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "get_config_value" "kv_key_exists" "get_config_values" "detect_file_format"
        "clear_kv_state" "get_kv_status" "export_kv_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_KV_STATUS" "ABADDON_KV_ERROR_MESSAGE" "ABADDON_KV_VALUE"
        "ABADDON_KV_FORMAT" "ABADDON_KV_TOOL" "ABADDON_KV_FILE" "ABADDON_KV_PATH"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            validation_messages+=("Missing state variable: $var")
            ((errors++))
        fi
    done
    
    # Check dependencies are loaded
    local required_deps=(
        "ABADDON_CORE_LOADED" "ABADDON_PLATFORM_LOADED" 
        "ABADDON_CACHE_LOADED" "ABADDON_VALIDATION_LOADED"
    )
    
    for dep in "${required_deps[@]}"; do
        if [[ -z "${!dep:-}" ]]; then
            validation_messages+=("Required dependency not loaded: ${dep/_LOADED/}")
            ((errors++))
        fi
    done
    
    # Output validation results
    if [[ $errors -eq 0 ]]; then
        log_debug "KV module validation: PASSED"
        return 0
    else
        log_error "KV module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# Set KV error state
set_kv_error() {
    local error_message="$1"
    ABADDON_KV_STATUS="$ABADDON_KV_ERROR"
    ABADDON_KV_ERROR_MESSAGE="$error_message"
    ABADDON_KV_VALUE="$error_message"  # KV interface: VALUE stores both results and errors
    log_error "KV Error: $error_message"
}

# Set KV success state
set_kv_success() {
    local value="$1"
    ABADDON_KV_STATUS="$ABADDON_KV_SUCCESS"
    ABADDON_KV_ERROR_MESSAGE=""
    ABADDON_KV_VALUE="$value"
    log_debug "KV Success: extracted value"
}

# ============================================================================
# Core KV Operations with Caching
# ============================================================================

# Execute cached file parsing
execute_cached_extraction() {
    local file_path="$1"
    local abaddon_path="$2"
    local default_value="${3:-}"

    ABADDON_KV_OPERATIONS=$((ABADDON_KV_OPERATIONS + 1))

    # Generate cache key
    local cache_key
    cache_key=$(generate_cache_key "kv_extract" "$file_path:$abaddon_path:$ABADDON_KV_FORMAT")

    # Try cache first
    local cached_result
    if cached_result=$(cache_get "$cache_key"); then
        ABADDON_KV_CACHE_HITS=$((ABADDON_KV_CACHE_HITS + 1))
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
    if validate_and_extract "$ABADDON_KV_FORMAT" "$file_content" "$abaddon_path" "$default_value"; then
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

    clear_kv_state
    ABADDON_KV_FILE="$file_path"
    ABADDON_KV_PATH="$abaddon_path"

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

    # Tool detection is handled by Platform module - no local detection needed

    # Detect file format
    if ! detect_file_format "$file_path"; then
        set_kv_error "Unable to detect file format"
        return 1
    fi

    # Get appropriate tool
    local tool
    if ! tool=$(get_tool_for_format "$ABADDON_KV_FORMAT"); then
        set_kv_error "No tool available for format: $ABADDON_KV_FORMAT"
        return 1
    fi

    ABADDON_KV_TOOL="$tool"

    # Execute extraction with caching
    if execute_cached_extraction "$file_path" "$abaddon_path" "$default_value"; then
        log_debug "Successfully extracted '$abaddon_path' from '$file_path': $ABADDON_KV_VALUE"
        return 0
    else
        return 1
    fi
}

# ============================================================================
# NEW KV API v2.0 - String Support
# ============================================================================

# Extract value from string data (in-memory parsing)
# Usage: kv_extract_string "path.to.value" "json" '{"key": "value"}' ["default"]
kv_extract_string() {
    local path="$1"
    local format="$2"
    local data="$3"
    local default_value="${4:-}"

    clear_kv_state
    ABADDON_KV_PATH="$path"
    ABADDON_KV_FORMAT="$format"
    ABADDON_KV_SOURCE="string"

    # Input validation
    if [[ -z "$path" ]] || [[ -z "$format" ]] || [[ -z "$data" ]]; then
        set_kv_error "Path, format, and data are required"
        return 1
    fi

    # Tool detection is handled by Platform module - no local detection needed

    # Validate format is supported
    local tool
    if ! tool=$(get_tool_for_format "$format"); then
        set_kv_error "Unsupported format: $format"
        return 1
    fi

    ABADDON_KV_TOOL="$tool"

    # Execute string extraction
    if execute_string_extraction "$format" "$data" "$path" "$default_value"; then
        log_debug "KV string extraction successful: $path from $format data"
        return 0
    else
        set_kv_error "KV string extraction failed: ${ABADDON_KV_VALUE:-unknown error}"
        return 1
    fi
}

# Execute string extraction (core implementation)
execute_string_extraction() {
    local format="$1"
    local data="$2"  
    local path="$3"
    local default_value="$4"
    local tool="$ABADDON_KV_TOOL"

    # Create cache key for string data
    local cache_key="kv_string_${format}_$(echo -n "${data}${path}" | sha256sum | cut -d' ' -f1)"

    # Check cache first
    if cache_get "$cache_key" >/dev/null 2>&1; then
        ABADDON_KV_VALUE="$(cache_get "$cache_key")"
        set_kv_success "$ABADDON_KV_VALUE"
        log_debug "KV string cache hit: $path"
        return 0
    fi

    # Extract based on tool
    local extracted_value=""
    case "$tool" in
        jq)
            # Use jq with input from stdin
            extracted_value=$(echo "$data" | jq -r ".$path // empty" 2>/dev/null)
            ;;
        yq)
            # Use yq with input from stdin  
            extracted_value=$(echo "$data" | yq e ".$path // \"empty\"" - 2>/dev/null)
            ;;
        *)
            set_kv_error "Tool '$tool' not supported for string extraction"
            return 1
            ;;
    esac

    # Handle extraction result
    if [[ -n "$extracted_value" && "$extracted_value" != "null" && "$extracted_value" != "empty" ]]; then
        ABADDON_KV_VALUE="$extracted_value"
        set_kv_success "$ABADDON_KV_VALUE"
        
        # Cache the result
        cache_store "$cache_key" "$ABADDON_KV_VALUE"
        
        log_debug "String extraction successful: '$path' = '$ABADDON_KV_VALUE'"
        return 0
    elif [[ -n "$default_value" ]]; then
        ABADDON_KV_VALUE="$default_value"
        set_kv_success "$ABADDON_KV_VALUE"
        log_debug "String extraction used default: '$path' = '$default_value'"
        return 0
    else
        set_kv_error "Path '$path' not found in $format data"
        return 1
    fi
}

# New convenience functions with clean API
kv_extract_file() {
    get_config_value "$@"  # Use existing implementation
}

# Check if key exists (no caching, quick check)
kv_key_exists() {
    local abaddon_path="$1"
    local file_path="$2"

    get_config_value "$abaddon_path" "$file_path" >/dev/null 2>&1
    [[ "$ABADDON_KV_STATUS" == "$ABADDON_KV_SUCCESS" ]]
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

    clear_kv_state

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
    case "$ABADDON_KV_FORMAT" in
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
        set_kv_error "Unsupported format for validation: $ABADDON_KV_FORMAT"
        return 1
        ;;
    esac
}

# ============================================================================
# State Access Functions
# ============================================================================

# Get current KV state
get_kv_status() { echo "$ABADDON_KV_STATUS"; }
get_kv_value() { echo "$ABADDON_KV_VALUE"; }
get_kv_format() { echo "$ABADDON_KV_FORMAT"; }
get_kv_tool() { echo "$ABADDON_KV_TOOL"; }
get_kv_file() { echo "$ABADDON_KV_FILE"; }
get_kv_path() { echo "$ABADDON_KV_PATH"; }

# Check if last operation succeeded
kv_succeeded() { [[ "$ABADDON_KV_STATUS" == "$ABADDON_KV_SUCCESS" ]]; }
kv_failed() { [[ "$ABADDON_KV_STATUS" != "$ABADDON_KV_SUCCESS" ]]; }

# ============================================================================
# Performance and Statistics
# ============================================================================

# Get KV performance statistics
get_kv_stats() {
    local hit_rate=0
    if ((ABADDON_KV_OPERATIONS > 0)); then
        hit_rate=$((ABADDON_KV_CACHE_HITS * 100 / ABADDON_KV_OPERATIONS))
    fi

    echo "KV Statistics:"
    echo "  Operations: $ABADDON_KV_OPERATIONS"
    echo "  Cache Hits: $ABADDON_KV_CACHE_HITS"
    echo "  Cache Hit Rate: ${hit_rate}%"
    echo "  Available Tools: $(printf '%s ' "${!ABADDON_KV_TOOL_AVAILABLE[@]}")"
    echo "  Last File: $ABADDON_KV_FILE"
    echo "  Last Format: $ABADDON_KV_FORMAT"
    echo "  Last Tool: $ABADDON_KV_TOOL"
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
        "validate_config_file" "get_tool_for_format" "detect_file_format"
    )

    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done

    # Check state variables exist
    local required_vars=(
        "ABADDON_KV_VALUE" "ABADDON_KV_STATUS" "ABADDON_KV_FORMAT"
        "ABADDON_KV_TOOL" "ABADDON_KV_FILE" "ABADDON_KV_PATH"
    )

    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done

    # Check dependencies are loaded
    if [[ -z "${ABADDON_PLATFORM_LOADED:-}" ]]; then
        log_error "Platform dependency not loaded"
        ((errors++))
    fi

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
    echo "Dependencies: platform.sh, cache.sh, validation.sh"
    echo "Supported Formats: JSON, YAML, TOML, XML"
    echo "Features: Caching, validation, normalized paths"
    echo "Main Functions:"
    echo "  get_config_value(path, file, [default])"
    echo "  kv_key_exists(path, file)"
    echo "  get_config_values(file, path1, path2, ...)"
    echo "  validate_config_file(file, [schema])"
}

log_debug "Abaddon KV module v2.0.0 loaded with Platform-based tool detection"
