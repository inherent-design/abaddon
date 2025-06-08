#!/usr/bin/env bash
# Abaddon Validation - Pure validation logic utility module
# Version: 1.0.0
# Purpose: Shared validation services for all Abaddon modules

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_VALIDATION_LOADED:-}" ]] && return 0
readonly ABADDON_VALIDATION_LOADED=1

# Dependency check
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-validation.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

# State variables for validation results
declare -g VALIDATION_STATE_STATUS=""
declare -g VALIDATION_STATE_ERROR=""
declare -g VALIDATION_STATE_DETAILS=""

# Validation result constants
readonly VALIDATION_SUCCESS="success"
readonly VALIDATION_ERROR="error"
readonly VALIDATION_WARNING="warning"

# ============================================================================
# Core Validation Functions
# ============================================================================

# Reset validation state
reset_validation_state() {
    VALIDATION_STATE_STATUS=""
    VALIDATION_STATE_ERROR=""
    VALIDATION_STATE_DETAILS=""
}

# Set validation error state
set_validation_error() {
    local error_message="$1"
    local details="${2:-}"
    
    VALIDATION_STATE_STATUS="$VALIDATION_ERROR"
    VALIDATION_STATE_ERROR="$error_message"
    VALIDATION_STATE_DETAILS="$details"
    
    log_debug "Validation error: $error_message"
    return 1
}

# Set validation success state
set_validation_success() {
    local details="${1:-}"
    
    VALIDATION_STATE_STATUS="$VALIDATION_SUCCESS"
    VALIDATION_STATE_ERROR=""
    VALIDATION_STATE_DETAILS="$details"
    
    log_debug "Validation success: $details"
    return 0
}

# ============================================================================
# Path and File Validation
# ============================================================================

# Validate file path for security (prevent path traversal)
validate_file_path() {
    local file_path="$1"
    local allow_absolute="${2:-false}"
    
    reset_validation_state
    
    # Basic existence check
    if [[ -z "$file_path" ]]; then
        set_validation_error "File path cannot be empty"
        return $?
    fi
    
    # Path traversal prevention
    if [[ "$file_path" =~ \.\./|^/ ]] && [[ "$allow_absolute" != "true" ]]; then
        set_validation_error "Path traversal detected" "Relative paths only: $file_path"
        return $?
    fi
    
    # Null byte injection prevention
    if [[ "$file_path" =~ $'\0' ]]; then
        set_validation_error "Null byte injection detected" "Path: $file_path"
        return $?
    fi
    
    # Control character prevention
    if [[ "$file_path" =~ [[:cntrl:]] ]]; then
        set_validation_error "Control characters detected" "Path: $file_path"
        return $?
    fi
    
    # Length validation (reasonable limit)
    if [[ ${#file_path} -gt 4096 ]]; then
        set_validation_error "Path too long" "Max 4096 characters: ${#file_path}"
        return $?
    fi
    
    set_validation_success "File path validated: $file_path"
    return $?
}

# Validate file exists and is readable
validate_file_exists() {
    local file_path="$1"
    
    reset_validation_state
    
    # First validate the path itself
    if ! validate_file_path "$file_path" true; then
        return 1
    fi
    
    # Check existence
    if [[ ! -f "$file_path" ]]; then
        set_validation_error "File not found" "Path: $file_path"
        return $?
    fi
    
    # Check readability
    if [[ ! -r "$file_path" ]]; then
        set_validation_error "File not readable" "Path: $file_path"
        return $?
    fi
    
    set_validation_success "File exists and readable: $file_path"
    return $?
}

# Validate directory exists and is accessible
validate_directory_path() {
    local dir_path="$1"
    local create_if_missing="${2:-false}"
    
    reset_validation_state
    
    # First validate the path itself
    if ! validate_file_path "$dir_path" true; then
        return 1
    fi
    
    # Check if directory exists
    if [[ ! -d "$dir_path" ]]; then
        if [[ "$create_if_missing" == "true" ]]; then
            if mkdir -p "$dir_path" 2>/dev/null; then
                set_validation_success "Directory created: $dir_path"
                return $?
            else
                set_validation_error "Cannot create directory" "Path: $dir_path"
                return $?
            fi
        else
            set_validation_error "Directory not found" "Path: $dir_path"
            return $?
        fi
    fi
    
    # Check accessibility
    if [[ ! -r "$dir_path" ]] || [[ ! -x "$dir_path" ]]; then
        set_validation_error "Directory not accessible" "Path: $dir_path"
        return $?
    fi
    
    set_validation_success "Directory validated: $dir_path"
    return $?
}

# ============================================================================
# Tool Path Normalization
# ============================================================================

# Normalize query paths for different data extraction tools
# Abaddon standard: paths start with field name (no leading dot)
# Examples: "project.name", "build.targets[0]", "config.database.host"
normalize_query_path() {
    local tool="$1"
    local abaddon_path="$2"
    
    reset_validation_state
    
    if [[ -z "$tool" ]] || [[ -z "$abaddon_path" ]]; then
        set_validation_error "Tool and path are required for normalization"
        return $?
    fi
    
    local normalized_path=""
    
    case "$tool" in
        jq)
            # jq requires leading dot: .project.name
            normalized_path=".$abaddon_path"
            ;;
        yq)
            # yq requires leading dot: .project.name  
            normalized_path=".$abaddon_path"
            ;;
        xq)
            # xq (xml) uses no leading dot: project.name
            normalized_path="$abaddon_path"
            ;;
        tq)
            # tq uses no leading dot: project.name
            normalized_path="$abaddon_path"
            ;;
        *)
            set_validation_error "Unsupported tool for path normalization" "Tool: $tool"
            return $?
            ;;
    esac
    
    # Store result in state variable instead of echo (no stdout pollution)
    VALIDATION_STATE_DETAILS="$normalized_path"
    VALIDATION_STATE_STATUS="$VALIDATION_SUCCESS"
    VALIDATION_STATE_ERROR=""
    log_debug "Path normalized for $tool: $normalized_path"
    return 0
}

# Get the normalized path from last normalization
get_normalized_path() {
    echo "$VALIDATION_STATE_DETAILS"
}

# ============================================================================
# Data Format Validation with Tool Path Normalization
# ============================================================================

# Validate and extract value using appropriate tool with normalized paths
validate_and_extract() {
    local format="$1"
    local content="$2"
    local abaddon_path="$3"
    local default_value="${4:-}"
    
    reset_validation_state
    
    if [[ -z "$format" ]] || [[ -z "$content" ]]; then
        set_validation_error "Format and content are required"
        return $?
    fi
    
    local tool=""
    local extracted_value=""
    
    case "$format" in
        json)
            tool="jq"
            if command -v jq >/dev/null 2>&1; then
                if [[ -n "$abaddon_path" ]]; then
                    if normalize_query_path "$tool" "$abaddon_path"; then
                        local normalized_path
                        normalized_path=$(get_normalized_path)
                        extracted_value=$(echo "$content" | jq -r "$normalized_path // empty" 2>/dev/null)
                    fi
                else
                    # Just validate content without extraction
                    if echo "$content" | jq empty 2>/dev/null; then
                        extracted_value="valid"
                    fi
                fi
            else
                set_validation_error "jq not available for JSON processing"
                return $?
            fi
            ;;
        yaml|yml)
            tool="yq"
            if command -v yq >/dev/null 2>&1; then
                if [[ -n "$abaddon_path" ]]; then
                    if normalize_query_path "$tool" "$abaddon_path"; then
                        local normalized_path
                        normalized_path=$(get_normalized_path)
                        extracted_value=$(echo "$content" | yq eval "$normalized_path // null" 2>/dev/null)
                    fi
                else
                    # Just validate content without extraction
                    if echo "$content" | yq eval 'length' >/dev/null 2>&1; then
                        extracted_value="valid"
                    fi
                fi
            else
                set_validation_error "yq not available for YAML processing"
                return $?
            fi
            ;;
        toml)
            tool="tq"
            if command -v tq >/dev/null 2>&1; then
                if [[ -n "$abaddon_path" ]]; then
                    if normalize_query_path "$tool" "$abaddon_path"; then
                        local normalized_path
                        normalized_path=$(get_normalized_path)
                        extracted_value=$(echo "$content" | tq -r "$normalized_path // empty" 2>/dev/null)
                    fi
                else
                    # Basic TOML validation
                    if echo "$content" | tq '.' >/dev/null 2>&1; then
                        extracted_value="valid"
                    fi
                fi
            else
                set_validation_error "tq not available for TOML processing"
                return $?
            fi
            ;;
        xml)
            tool="xq"
            if command -v xq >/dev/null 2>&1; then
                if [[ -n "$abaddon_path" ]]; then
                    if normalize_query_path "$tool" "$abaddon_path"; then
                        local normalized_path
                        normalized_path=$(get_normalized_path)
                        # xq uses CSS selectors, convert simple paths to CSS
                        local css_selector="${normalized_path//\./ }"
                        extracted_value=$(echo "$content" | xq -q "$css_selector" 2>/dev/null | head -1)
                    fi
                else
                    # Basic XML validation - check if it's well-formed
                    if echo "$content" | xq >/dev/null 2>&1; then
                        extracted_value="valid"
                    fi
                fi
            else
                set_validation_error "xq not available for XML processing"
                return $?
            fi
            ;;
        *)
            set_validation_error "Unsupported format" "Format: $format"
            return $?
            ;;
    esac
    
    # Handle extraction results
    if [[ -z "$extracted_value" ]]; then
        if [[ -n "$default_value" ]]; then
            extracted_value="$default_value"
            VALIDATION_STATE_DETAILS="$extracted_value"
            VALIDATION_STATE_STATUS="$VALIDATION_SUCCESS"
            VALIDATION_STATE_ERROR=""
            log_debug "Used default value for missing field: $extracted_value"
            return 0
        else
            set_validation_error "Field not found and no default provided" "Path: $abaddon_path"
            return $?
        fi
    elif [[ "$extracted_value" == "null" ]]; then
        if [[ -n "$default_value" ]]; then
            extracted_value="$default_value"
            VALIDATION_STATE_DETAILS="$extracted_value"
            VALIDATION_STATE_STATUS="$VALIDATION_SUCCESS"
            VALIDATION_STATE_ERROR=""
            log_debug "Used default value for null field: $extracted_value"
            return 0
        else
            set_validation_error "Field is null and no default provided" "Path: $abaddon_path"
            return $?
        fi
    else
        VALIDATION_STATE_DETAILS="$extracted_value"
        VALIDATION_STATE_STATUS="$VALIDATION_SUCCESS"
        VALIDATION_STATE_ERROR=""
        log_debug "Successfully extracted value: $extracted_value"
        return 0
    fi
}

# Get extracted value from last validation
get_extracted_value() {
    echo "$VALIDATION_STATE_DETAILS"
}

# Validate JSON content
validate_json_content() {
    validate_and_extract "json" "$1" ""
}

# Validate YAML content  
validate_yaml_content() {
    validate_and_extract "yaml" "$1" ""
}

# Validate TOML content
validate_toml_content() {
    validate_and_extract "toml" "$1" ""
}

# Validate XML content
validate_xml_content() {
    validate_and_extract "xml" "$1" ""
}

# ============================================================================
# Business Logic Validation
# ============================================================================

# Validate required field exists in data
validate_field_required() {
    local field_path="$1"
    local data_content="$2"
    local format="${3:-json}"
    
    reset_validation_state
    
    if [[ -z "$field_path" ]]; then
        set_validation_error "Field path cannot be empty"
        return $?
    fi
    
    local field_value=""
    case "$format" in
        json)
            if command -v jq >/dev/null 2>&1; then
                field_value=$(echo "$data_content" | jq -r ".$field_path // empty" 2>/dev/null)
            fi
            ;;
        yaml)
            if command -v yq >/dev/null 2>&1; then
                field_value=$(echo "$data_content" | yq eval ".$field_path // empty" 2>/dev/null)
            fi
            ;;
        *)
            set_validation_error "Unsupported format for field validation" "Format: $format"
            return $?
            ;;
    esac
    
    if [[ -z "$field_value" ]]; then
        set_validation_error "Required field missing" "Field: $field_path"
        return $?
    fi
    
    set_validation_success "Required field present: $field_path"
    return $?
}

# Validate value is within allowed list
validate_value_in_list() {
    local value="$1"
    local allowed_list="$2"  # Comma-separated values
    
    reset_validation_state
    
    if [[ -z "$value" ]]; then
        set_validation_error "Value cannot be empty"
        return $?
    fi
    
    # Convert comma-separated list to array
    IFS=',' read -ra allowed_values <<< "$allowed_list"
    
    for allowed in "${allowed_values[@]}"; do
        if [[ "$value" == "$allowed" ]]; then
            set_validation_success "Value in allowed list: $value"
            return $?
        fi
    done
    
    set_validation_error "Value not in allowed list" "Value: $value, Allowed: $allowed_list"
    return $?
}

# Validate numeric range
validate_numeric_range() {
    local value="$1"
    local min_value="$2"
    local max_value="$3"
    
    reset_validation_state
    
    # Check if value is numeric
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        set_validation_error "Value is not numeric" "Value: $value"
        return $?
    fi
    
    # Check minimum
    if [[ -n "$min_value" ]] && (( value < min_value )); then
        set_validation_error "Value below minimum" "Value: $value, Min: $min_value"
        return $?
    fi
    
    # Check maximum  
    if [[ -n "$max_value" ]] && (( value > max_value )); then
        set_validation_error "Value above maximum" "Value: $value, Max: $max_value"
        return $?
    fi
    
    set_validation_success "Value in range: $value"
    return $?
}

# ============================================================================
# Schema Validation
# ============================================================================

# Validate JSON against schema (if ajv-cli is available)
validate_json_schema() {
    local json_content="$1"
    local schema_file="$2"
    
    reset_validation_state
    
    # First validate inputs
    if ! validate_json_content "$json_content"; then
        return 1
    fi
    
    if ! validate_file_exists "$schema_file"; then
        return 1
    fi
    
    # Check if jsonschema CLI is available for schema validation
    if command -v jsonschema >/dev/null 2>&1; then
        local temp_json=$(mktemp)
        echo "$json_content" > "$temp_json"
        
        if jsonschema validate "$schema_file" "$temp_json" >/dev/null 2>&1; then
            rm -f "$temp_json"
            set_validation_success "JSON schema validation passed"
            return $?
        else
            local error_details=$(jsonschema validate "$schema_file" "$temp_json" 2>&1 | head -3)
            rm -f "$temp_json"
            set_validation_error "JSON schema validation failed" "$error_details"
            return $?
        fi
    else
        # Fallback: basic content validation only
        log_warn "jsonschema CLI not available, performing basic JSON validation only"
        set_validation_success "Basic JSON validation passed (no schema check)"
        return $?
    fi
}

# ============================================================================
# CLI and Input Validation
# ============================================================================

# Validate command name format
validate_command_name() {
    local command_name="$1"
    
    reset_validation_state
    
    if [[ -z "$command_name" ]]; then
        set_validation_error "Command name cannot be empty"
        return $?
    fi
    
    # Command names should be alphanumeric with hyphens
    if [[ ! "$command_name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        set_validation_error "Invalid command name format" "Must be lowercase, alphanumeric with hyphens: $command_name"
        return $?
    fi
    
    set_validation_success "Command name valid: $command_name"
    return $?
}

# Validate project name format
validate_project_name() {
    local project_name="$1"
    
    reset_validation_state
    
    if [[ -z "$project_name" ]]; then
        set_validation_error "Project name cannot be empty"
        return $?
    fi
    
    # Project names should be safe for filesystems
    if [[ ! "$project_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        set_validation_error "Invalid project name format" "Must be alphanumeric with underscores/hyphens: $project_name"
        return $?
    fi
    
    # Length check
    if [[ ${#project_name} -gt 64 ]]; then
        set_validation_error "Project name too long" "Max 64 characters: ${#project_name}"
        return $?
    fi
    
    set_validation_success "Project name valid: $project_name"
    return $?
}

# ============================================================================
# Validation State Access
# ============================================================================

# Get current validation status
get_validation_status() {
    echo "$VALIDATION_STATE_STATUS"
}

# Get validation error message
get_validation_error() {
    echo "$VALIDATION_STATE_ERROR"
}

# Get validation details
get_validation_details() {
    echo "$VALIDATION_STATE_DETAILS"
}

# Check if last validation was successful
validation_succeeded() {
    [[ "$VALIDATION_STATE_STATUS" == "$VALIDATION_SUCCESS" ]]
}

# Check if last validation failed
validation_failed() {
    [[ "$VALIDATION_STATE_STATUS" == "$VALIDATION_ERROR" ]]
}

log_debug "Abaddon validation module loaded"