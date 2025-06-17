#!/usr/bin/env bash
# Abaddon Data Types - User-facing data validation and parsing
# Version: 1.0.0
# Purpose: Identifiers, UUIDs, datetimes, URI encoding, schema validation

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_DATATYPES_LOADED:-}" ]] && return 0
readonly ABADDON_DATATYPES_LOADED=1

# Dependency checks
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-datatypes.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

# ============================================================================
# Configuration and State Variables
# ============================================================================

# State variables - NO stdout pollution
declare -g ABADDON_DATATYPES_STATUS=""
declare -g ABADDON_DATATYPES_ERROR_MESSAGE=""
declare -g ABADDON_DATATYPES_VALIDATED_VALUE=""
declare -g ABADDON_DATATYPES_VALIDATION_TYPE=""

# Data types result constants
readonly ABADDON_DATATYPES_SUCCESS="success"
readonly ABADDON_DATATYPES_ERROR="error"
readonly ABADDON_DATATYPES_WARNING="warning"

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all Abaddon modules)
# ============================================================================

# Clear all datatypes module state variables
clear_datatypes_state() {
    ABADDON_DATATYPES_STATUS=""
    ABADDON_DATATYPES_ERROR_MESSAGE=""
    ABADDON_DATATYPES_VALIDATED_VALUE=""
    ABADDON_DATATYPES_VALIDATION_TYPE=""
    log_debug "Datatypes module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_datatypes_status() {
    if [[ "$ABADDON_DATATYPES_STATUS" == "$ABADDON_DATATYPES_SUCCESS" ]]; then
        echo "ready"
    elif [[ "$ABADDON_DATATYPES_STATUS" == "$ABADDON_DATATYPES_ERROR" ]]; then
        echo "error"
    elif [[ -n "${ABADDON_CORE_LOADED:-}" ]]; then
        echo "ready"
    else
        echo "unknown"
    fi
}

# Export datatypes state for cross-module access
export_datatypes_state() {
    echo "ABADDON_DATATYPES_STATUS='$ABADDON_DATATYPES_STATUS'"
    echo "ABADDON_DATATYPES_ERROR_MESSAGE='$ABADDON_DATATYPES_ERROR_MESSAGE'"
    echo "ABADDON_DATATYPES_VALIDATED_VALUE='$ABADDON_DATATYPES_VALIDATED_VALUE'"
    echo "ABADDON_DATATYPES_VALIDATION_TYPE='$ABADDON_DATATYPES_VALIDATION_TYPE'"
}

# Validate datatypes module state consistency
validate_datatypes_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "validate_identifier" "validate_uuid" "validate_iso_datetime"
        "uri_encode" "uri_decode" "html_escape" "html_unescape"
        "clear_datatypes_state" "get_datatypes_status" "export_datatypes_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_DATATYPES_STATUS" "ABADDON_DATATYPES_ERROR_MESSAGE"
        "ABADDON_DATATYPES_VALIDATED_VALUE" "ABADDON_DATATYPES_VALIDATION_TYPE"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            validation_messages+=("Missing state variable: $var")
            ((errors++))
        fi
    done
    
    # Check dependencies are loaded
    local required_deps=(
        "ABADDON_CORE_LOADED"
    )
    
    for dep in "${required_deps[@]}"; do
        if [[ -z "${!dep:-}" ]]; then
            validation_messages+=("Required dependency not loaded: ${dep/_LOADED/}")
            ((errors++))
        fi
    done
    
    # Output validation results
    if [[ $errors -eq 0 ]]; then
        log_debug "Datatypes module validation: PASSED"
        return 0
    else
        log_error "Datatypes module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# ============================================================================
# Core Data Validation Functions
# ============================================================================

# Validate identifier (variable names, state names, etc.)
validate_identifier() {
    local identifier="$1"
    local strict="${2:-true}"
    
    clear_datatypes_state
    ABADDON_DATATYPES_VALIDATION_TYPE="identifier"
    
    if [[ -z "$identifier" ]]; then
        set_datatypes_error "Identifier cannot be empty"
        return 1
    fi
    
    # Basic identifier pattern: start with letter/underscore, followed by letters/numbers/underscores
    if [[ ! "$identifier" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        set_datatypes_error "Invalid identifier format: $identifier (must start with letter/underscore, contain only alphanumeric/underscore)"
        return 1
    fi
    
    # Optional strict mode: additional constraints
    if [[ "$strict" == "true" ]]; then
        # Prevent reserved words
        local reserved_words=("if" "then" "else" "fi" "for" "while" "do" "done" "case" "esac" "function" "return" "exit" "break" "continue")
        for word in "${reserved_words[@]}"; do
            if [[ "$identifier" == "$word" ]]; then
                set_datatypes_error "Reserved word not allowed as identifier: $identifier"
                return 1
            fi
        done
        
        # Length limit for practical use
        if [[ ${#identifier} -gt 64 ]]; then
            set_datatypes_error "Identifier too long: $identifier (max 64 characters in strict mode)"
            return 1
        fi
    fi
    
    set_datatypes_success "$identifier"
    return 0
}

# Validate UUID (both v4 and generic formats)
validate_uuid() {
    local uuid="$1"
    local version="${2:-any}"
    
    clear_datatypes_state
    ABADDON_DATATYPES_VALIDATION_TYPE="uuid"
    
    if [[ -z "$uuid" ]]; then
        set_datatypes_error "UUID cannot be empty"
        return 1
    fi
    
    # Remove hyphens for length check
    local uuid_no_hyphens="${uuid//-/}"
    
    # Check overall format: 8-4-4-4-12 hex characters
    if [[ ! "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        set_datatypes_error "Invalid UUID format: $uuid (expected: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)"
        return 1
    fi
    
    # Version-specific validation
    if [[ "$version" == "4" ]]; then
        # UUID v4: version digit must be 4, variant bits must be 10xx
        local version_char="${uuid:14:1}"
        local variant_char="${uuid:19:1}"
        
        if [[ "$version_char" != "4" ]]; then
            set_datatypes_error "Invalid UUID v4: version digit must be 4, got $version_char"
            return 1
        fi
        
        if [[ ! "$variant_char" =~ ^[89abAB]$ ]]; then
            set_datatypes_error "Invalid UUID v4: variant must be 8, 9, A, or B, got $variant_char"
            return 1
        fi
    fi
    
    set_datatypes_success "$uuid"
    return 0
}

# Validate ISO 8601 datetime
validate_iso_datetime() {
    local datetime="$1"
    local require_timezone="${2:-false}"
    
    clear_datatypes_state
    ABADDON_DATATYPES_VALIDATION_TYPE="iso_datetime"
    
    if [[ -z "$datetime" ]]; then
        set_datatypes_error "Datetime cannot be empty"
        return 1
    fi
    
    # ISO 8601 patterns (simplified but practical)
    local iso_basic="^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$"
    local iso_with_ms="^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$"
    local iso_with_tz="^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{3})?([+-][0-9]{2}:[0-9]{2}|Z)$"
    
    if [[ "$require_timezone" == "true" ]]; then
        if [[ ! "$datetime" =~ $iso_with_tz ]]; then
            set_datatypes_error "Invalid ISO datetime with timezone: $datetime (expected: YYYY-MM-DDTHH:MM:SS[.mmm][+/-HH:MM|Z])"
            return 1
        fi
    else
        if [[ ! "$datetime" =~ $iso_basic && ! "$datetime" =~ $iso_with_ms && ! "$datetime" =~ $iso_with_tz ]]; then
            set_datatypes_error "Invalid ISO datetime: $datetime (expected: YYYY-MM-DDTHH:MM:SS[.mmm][timezone])"
            return 1
        fi
    fi
    
    # Basic range validation (years 1000-9999)
    local year="${datetime:0:4}"
    if [[ $year -lt 1000 || $year -gt 9999 ]]; then
        set_datatypes_error "Invalid year in datetime: $year (must be 1000-9999)"
        return 1
    fi
    
    set_datatypes_success "$datetime"
    return 0
}

# ============================================================================
# Encoding/Decoding Functions
# ============================================================================

# URI encode (percent encoding)
uri_encode() {
    local input="$1"
    
    clear_datatypes_state
    ABADDON_DATATYPES_VALIDATION_TYPE="uri_encode"
    
    if [[ -z "$input" ]]; then
        set_datatypes_success ""
        return 0
    fi
    
    # Use printf to convert each character to hex
    local encoded=""
    local char
    local i
    
    for ((i = 0; i < ${#input}; i++)); do
        char="${input:$i:1}"
        case "$char" in
            [a-zA-Z0-9._~-])
                # Unreserved characters - no encoding needed
                encoded+="$char"
                ;;
            *)
                # Encode everything else
                printf -v hex_char "%%%02X" "'$char"
                encoded+="$hex_char"
                ;;
        esac
    done
    
    set_datatypes_success "$encoded"
    return 0
}

# URI decode (percent decoding)
uri_decode() {
    local input="$1"
    
    clear_datatypes_state
    ABADDON_DATATYPES_VALIDATION_TYPE="uri_decode"
    
    if [[ -z "$input" ]]; then
        set_datatypes_success ""
        return 0
    fi
    
    # Decode percent-encoded sequences
    local decoded="${input//+/ }"  # Replace + with space (form encoding)
    
    # Decode %XX sequences using a simpler approach
    # Handle common percent-encoded characters
    decoded="${decoded//%20/ }"      # space
    decoded="${decoded//%21/!}"      # exclamation
    decoded="${decoded//%22/\"}"     # quote
    decoded="${decoded//%23/#}"      # hash
    decoded="${decoded//%24/$}"      # dollar
    decoded="${decoded//%25/%}"      # percent
    decoded="${decoded//%26/&}"      # ampersand
    decoded="${decoded//%27/\'}"     # apostrophe
    decoded="${decoded//%28/(}"      # left paren
    decoded="${decoded//%29/)}"      # right paren
    decoded="${decoded//%2A/*}"      # asterisk
    decoded="${decoded//%2B/+}"      # plus
    decoded="${decoded//%2C/,}"      # comma
    decoded="${decoded//%2D/-}"      # hyphen
    decoded="${decoded//%2E/.}"      # period
    decoded="${decoded//%2F//}"      # slash
    decoded="${decoded//%3A/:}"      # colon
    decoded="${decoded//%3B/;}"      # semicolon
    decoded="${decoded//%3C/<}"      # less than
    decoded="${decoded//%3D/=}"      # equals
    decoded="${decoded//%3E/>}"      # greater than
    decoded="${decoded//%3F/?}"      # question mark
    decoded="${decoded//%40/@}"      # at sign
    
    set_datatypes_success "$decoded"
    return 0
}

# HTML escape
html_escape() {
    local input="$1"
    
    clear_datatypes_state
    ABADDON_DATATYPES_VALIDATION_TYPE="html_escape"
    
    if [[ -z "$input" ]]; then
        set_datatypes_success ""
        return 0
    fi
    
    local escaped=""
    local char
    local i
    
    # Process character by character to avoid substitution issues
    for ((i = 0; i < ${#input}; i++)); do
        char="${input:$i:1}"
        case "$char" in
            '&')  escaped+="&amp;" ;;
            '<')  escaped+="&lt;" ;;
            '>')  escaped+="&gt;" ;;
            '"')  escaped+="&quot;" ;;
            "'")  escaped+="&#39;" ;;
            *)    escaped+="$char" ;;
        esac
    done
    
    set_datatypes_success "$escaped"
    return 0
}

# HTML unescape
html_unescape() {
    local input="$1"
    
    clear_datatypes_state
    ABADDON_DATATYPES_VALIDATION_TYPE="html_unescape"
    
    if [[ -z "$input" ]]; then
        set_datatypes_success ""
        return 0
    fi
    
    local unescaped="$input"
    unescaped="${unescaped//&#39;/\'}"
    unescaped="${unescaped//&quot;/\"}"
    unescaped="${unescaped//&gt;/>}"
    unescaped="${unescaped//&lt;/<}"
    unescaped="${unescaped//&amp;/&}"   # Must be last
    
    set_datatypes_success "$unescaped"
    return 0
}

# ============================================================================
# JSON/YAML Key Validation
# ============================================================================

# Validate JSON-compatible key
validate_json_key() {
    local key="$1"
    
    clear_datatypes_state
    ABADDON_DATATYPES_VALIDATION_TYPE="json_key"
    
    if [[ -z "$key" ]]; then
        set_datatypes_error "JSON key cannot be empty"
        return 1
    fi
    
    # JSON keys are strings, so any string is technically valid
    # But for practical CLI use, restrict to reasonable patterns
    if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*$ ]]; then
        set_datatypes_error "Invalid JSON key format: $key (recommended: alphanumeric, underscore, dot, hyphen)"
        return 1
    fi
    
    set_datatypes_success "$key"
    return 0
}

# ============================================================================
# State Management Functions
# ============================================================================

# Set datatypes error state
set_datatypes_error() {
    local error_message="$1"
    ABADDON_DATATYPES_STATUS="$ABADDON_DATATYPES_ERROR"
    ABADDON_DATATYPES_ERROR_MESSAGE="$error_message"
    ABADDON_DATATYPES_VALIDATED_VALUE=""
    log_error "Datatypes Error: $error_message"
}

# Set datatypes success state
set_datatypes_success() {
    local validated_value="$1"
    ABADDON_DATATYPES_STATUS="$ABADDON_DATATYPES_SUCCESS"
    ABADDON_DATATYPES_ERROR_MESSAGE=""
    ABADDON_DATATYPES_VALIDATED_VALUE="$validated_value"
    log_debug "Datatypes Success: validation passed"
}

# ============================================================================
# State Access Functions
# ============================================================================

get_datatypes_value() { echo "$ABADDON_DATATYPES_VALIDATED_VALUE"; }
get_datatypes_error() { echo "$ABADDON_DATATYPES_ERROR_MESSAGE"; }
get_datatypes_validation_type() { echo "$ABADDON_DATATYPES_VALIDATION_TYPE"; }

# Check if last operation succeeded
datatypes_succeeded() { [[ "$ABADDON_DATATYPES_STATUS" == "$ABADDON_DATATYPES_SUCCESS" ]]; }
datatypes_failed() { [[ "$ABADDON_DATATYPES_STATUS" != "$ABADDON_DATATYPES_SUCCESS" ]]; }

# ============================================================================
# Module Information
# ============================================================================

# Module validation
datatypes_validate() {
    local errors=0
    
    # Check core functions exist
    for func in validate_identifier validate_uuid validate_iso_datetime uri_encode uri_decode; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    for var in ABADDON_DATATYPES_STATUS ABADDON_DATATYPES_VALIDATED_VALUE; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    return $errors
}

# Module information
datatypes_info() {
    echo "abaddon-datatypes.sh - User-Facing Data Validation and Parsing"
    echo "Version: 1.0.0"
    echo "Functions: validate_identifier, validate_uuid, validate_iso_datetime"
    echo "Encoding: uri_encode, uri_decode, html_escape, html_unescape"
    echo "State: ABADDON_DATATYPES_STATUS, ABADDON_DATATYPES_VALIDATED_VALUE"
    echo "Integration: self-contained, only requires core.sh"
}

log_debug "abaddon-datatypes.sh loaded successfully"