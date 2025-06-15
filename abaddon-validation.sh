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

[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] || {
    echo "ERROR: abaddon-validation.sh requires abaddon-platform.sh to be loaded first" >&2
    return 1
}

# State variables for validation results
declare -g ABADDON_VALIDATION_STATUS=""
declare -g ABADDON_VALIDATION_ERROR_MESSAGE=""
declare -g ABADDON_VALIDATION_DETAILS=""

# Validation result constants
readonly ABADDON_VALIDATION_SUCCESS="success"
readonly ABADDON_VALIDATION_ERROR="error"
readonly ABADDON_VALIDATION_WARNING="warning"

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all Abaddon modules)
# ============================================================================

# Clear all validation module state variables
clear_validation_state() {
    ABADDON_VALIDATION_STATUS=""
    ABADDON_VALIDATION_ERROR_MESSAGE=""
    ABADDON_VALIDATION_DETAILS=""
    log_debug "Validation module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_validation_status() {
    if [[ "$ABADDON_VALIDATION_STATUS" == "$ABADDON_VALIDATION_SUCCESS" ]]; then
        echo "ready"
    elif [[ "$ABADDON_VALIDATION_STATUS" == "$ABADDON_VALIDATION_ERROR" ]]; then
        echo "error"
    elif [[ -n "${ABADDON_CORE_LOADED:-}" && -n "${ABADDON_PLATFORM_LOADED:-}" ]]; then
        echo "ready"
    else
        echo "incomplete"
    fi
}

# Export validation state for cross-module access
export_validation_state() {
    echo "ABADDON_VALIDATION_STATUS='$ABADDON_VALIDATION_STATUS'"
    echo "ABADDON_VALIDATION_ERROR_MESSAGE='$ABADDON_VALIDATION_ERROR_MESSAGE'"
    echo "ABADDON_VALIDATION_DETAILS='$ABADDON_VALIDATION_DETAILS'"
}

# Validate validation module state consistency
validate_validation_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "validate_file_path" "validate_file_exists" "validate_directory_path"
        "validate_json_content" "validate_yaml_content" "validate_field_required"
        "clear_validation_state" "get_validation_status" "export_validation_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_VALIDATION_STATUS" "ABADDON_VALIDATION_ERROR_MESSAGE" "ABADDON_VALIDATION_DETAILS"
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
        log_debug "Validation module validation: PASSED"
        return 0
    else
        log_error "Validation module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# Set validation error state
set_validation_error() {
    local error_message="$1"
    local details="${2:-}"
    
    ABADDON_VALIDATION_STATUS="$ABADDON_VALIDATION_ERROR"
    ABADDON_VALIDATION_ERROR_MESSAGE="$error_message"
    ABADDON_VALIDATION_DETAILS="$details"
    
    log_debug "Validation error: $error_message"
    return 1
}

# Set validation success state
set_validation_success() {
    local details="${1:-}"
    
    ABADDON_VALIDATION_STATUS="$ABADDON_VALIDATION_SUCCESS"
    ABADDON_VALIDATION_ERROR_MESSAGE=""
    ABADDON_VALIDATION_DETAILS="$details"
    
    log_debug "Validation success: $details"
    return 0
}

# ============================================================================
# Core Validation Functions
# ============================================================================

# Validate file path for security (prevent path traversal)
validate_file_path() {
    local file_path="$1"
    local allow_absolute="${2:-false}"
    
    clear_validation_state
    
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
    
    clear_validation_state
    
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
    
    clear_validation_state
    
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
    
    clear_validation_state
    
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
    ABADDON_VALIDATION_DETAILS="$normalized_path"
    ABADDON_VALIDATION_STATUS="$ABADDON_VALIDATION_SUCCESS"
    ABADDON_VALIDATION_ERROR_MESSAGE=""
    log_debug "Path normalized for $tool: $normalized_path"
    return 0
}

# Get the normalized path from last normalization
get_normalized_path() {
    echo "$ABADDON_VALIDATION_DETAILS"
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
    
    clear_validation_state
    
    if [[ -z "$format" ]] || [[ -z "$content" ]]; then
        set_validation_error "Format and content are required"
        return $?
    fi
    
    local tool=""
    local extracted_value=""
    
    case "$format" in
        json)
            tool=$(get_best_tool "json_processing")
            if [[ "$tool" != "none" ]]; then
                if [[ -n "$abaddon_path" ]]; then
                    if normalize_query_path "$tool" "$abaddon_path"; then
                        local normalized_path
                        normalized_path=$(get_normalized_path)
                        extracted_value=$(echo "$content" | "$tool" -r "$normalized_path // empty" 2>/dev/null)
                    fi
                else
                    # Just validate content without extraction
                    if echo "$content" | "$tool" empty 2>/dev/null; then
                        extracted_value="valid"
                    fi
                fi
            else
                set_validation_error "No tool available for JSON processing"
                return $?
            fi
            ;;
        yaml|yml)
            tool=$(get_best_tool "yaml_processing")
            if [[ "$tool" != "none" ]]; then
                if [[ -n "$abaddon_path" ]]; then
                    if normalize_query_path "$tool" "$abaddon_path"; then
                        local normalized_path
                        normalized_path=$(get_normalized_path)
                        extracted_value=$(echo "$content" | "$tool" eval "$normalized_path // \"null\"" 2>/dev/null)
                    fi
                else
                    # Just validate content without extraction
                    if echo "$content" | "$tool" eval 'length' >/dev/null 2>&1; then
                        extracted_value="valid"
                    fi
                fi
            else
                set_validation_error "No tool available for YAML processing"
                return $?
            fi
            ;;
        toml)
            tool=$(get_best_tool "toml_processing")
            if [[ "$tool" != "none" ]]; then
                if [[ -n "$abaddon_path" ]]; then
                    if normalize_query_path "$tool" "$abaddon_path"; then
                        local normalized_path
                        normalized_path=$(get_normalized_path)
                        extracted_value=$(echo "$content" | "$tool" -r "$normalized_path // empty" 2>/dev/null)
                    fi
                else
                    # Basic TOML validation
                    if echo "$content" | "$tool" '.' >/dev/null 2>&1; then
                        extracted_value="valid"
                    fi
                fi
            else
                set_validation_error "No tool available for TOML processing"
                return $?
            fi
            ;;
        xml)
            tool=$(get_best_tool "xml_processing")
            if [[ "$tool" != "none" ]]; then
                if [[ -n "$abaddon_path" ]]; then
                    if normalize_query_path "$tool" "$abaddon_path"; then
                        local normalized_path
                        normalized_path=$(get_normalized_path)
                        # xq uses CSS selectors, convert simple paths to CSS
                        local css_selector="${normalized_path//\./ }"
                        extracted_value=$(echo "$content" | "$tool" -q "$css_selector" 2>/dev/null | head -1)
                    fi
                else
                    # Basic XML validation - check if it's well-formed
                    if echo "$content" | "$tool" >/dev/null 2>&1; then
                        extracted_value="valid"
                    fi
                fi
            else
                set_validation_error "No tool available for XML processing"
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
            ABADDON_VALIDATION_DETAILS="$extracted_value"
            ABADDON_VALIDATION_STATUS="$ABADDON_VALIDATION_SUCCESS"
            ABADDON_VALIDATION_ERROR_MESSAGE=""
            log_debug "Used default value for missing field: $extracted_value"
            return 0
        else
            set_validation_error "Field not found and no default provided" "Path: $abaddon_path"
            return $?
        fi
    elif [[ "$extracted_value" == "null" ]]; then
        if [[ -n "$default_value" ]]; then
            extracted_value="$default_value"
            ABADDON_VALIDATION_DETAILS="$extracted_value"
            ABADDON_VALIDATION_STATUS="$ABADDON_VALIDATION_SUCCESS"
            ABADDON_VALIDATION_ERROR_MESSAGE=""
            log_debug "Used default value for null field: $extracted_value"
            return 0
        else
            set_validation_error "Field is null and no default provided" "Path: $abaddon_path"
            return $?
        fi
    else
        ABADDON_VALIDATION_DETAILS="$extracted_value"
        ABADDON_VALIDATION_STATUS="$ABADDON_VALIDATION_SUCCESS"
        ABADDON_VALIDATION_ERROR_MESSAGE=""
        log_debug "Successfully extracted value: $extracted_value"
        return 0
    fi
}

# Get extracted value from last validation
get_extracted_value() {
    echo "$ABADDON_VALIDATION_DETAILS"
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
    
    clear_validation_state
    
    if [[ -z "$field_path" ]]; then
        set_validation_error "Field path cannot be empty"
        return $?
    fi
    
    local field_value=""
    case "$format" in
        json)
            local tool
            tool=$(get_best_tool "json_processing")
            if [[ "$tool" != "none" ]]; then
                field_value=$(echo "$data_content" | "$tool" -r ".$field_path // empty" 2>/dev/null)
            fi
            ;;
        yaml)
            local tool
            tool=$(get_best_tool "yaml_processing")
            if [[ "$tool" != "none" ]]; then
                field_value=$(echo "$data_content" | "$tool" eval ".$field_path // \"empty\"" 2>/dev/null)
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
    
    clear_validation_state
    
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
    
    clear_validation_state
    
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
    
    clear_validation_state
    
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
    
    clear_validation_state
    
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
    
    clear_validation_state
    
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
    echo "$ABADDON_VALIDATION_STATUS"
}

# Get validation error message
get_validation_error() {
    echo "$ABADDON_VALIDATION_ERROR_MESSAGE"
}

# Get validation details
get_validation_details() {
    echo "$ABADDON_VALIDATION_DETAILS"
}

# Check if last validation was successful
validation_succeeded() {
    [[ "$ABADDON_VALIDATION_STATUS" == "$ABADDON_VALIDATION_SUCCESS" ]]
}

# Check if last validation failed
validation_failed() {
    [[ "$ABADDON_VALIDATION_STATUS" == "$ABADDON_VALIDATION_ERROR" ]]
}

# ============================================================================
# Module Validation and Information
# ============================================================================

# Validate validation module functionality
validation_validate() {
    local errors=0
    
    # Check required functions exist
    local required_functions=(
        "validate_file_path" "validate_file_exists" "validate_json_content"
        "clear_validation_state" "set_validation_error" "set_validation_success"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_VALIDATION_STATUS" "ABADDON_VALIDATION_ERROR" "ABADDON_VALIDATION_DETAILS"
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
validation_info() {
    echo "Abaddon Validation - Security & tool path normalization"
    echo "Version: 1.0.0"
    echo "Dependencies: core.sh, platform.sh"
    echo "Features: Path validation, content validation, tool normalization"
    echo "Main Functions:"
    echo "  validate_file_path(path, [allow_absolute])"
    echo "  validate_and_extract(format, content, path, [default])"
    echo "  normalize_query_path(abaddon_path, tool)"
    echo "  validate_json_content(content)"
}

log_debug "Abaddon validation module loaded"