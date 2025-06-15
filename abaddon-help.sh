#!/usr/bin/env bash
# abaddon-help.sh - Language-Agnostic Help System
# Version: 1.0.0  
# Purpose: i18n-ready help using kv.sh for string token retrieval

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_HELP_LOADED:-}" ]] && return 0
readonly ABADDON_HELP_LOADED=1

# Dependency checks
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-help.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_KV_LOADED:-}" ]] || {
    echo "ERROR: abaddon-help.sh requires abaddon-kv.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_PROGRESS_LOADED:-}" ]] || {
    echo "ERROR: abaddon-help.sh requires abaddon-progress.sh to be loaded first" >&2
    return 1
}

# State variables - NO stdout pollution
declare -g ABADDON_HELP_TEXT=""
declare -g ABADDON_HELP_STATUS=""
declare -g ABADDON_HELP_LANGUAGE=""
declare -g ABADDON_HELP_TOKEN=""

# Configuration
declare -g HELP_DEFAULT_LANGUAGE="en"
declare -g HELP_TRANSLATIONS_DIR="lib/translations"

# Language-agnostic token mapping (help.sh maintains this internally)
declare -A HELP_TOKEN_MAP

# ============================================================================
# Core Token Management
# ============================================================================

# Initialize token mapping for current language features
init_help_tokens() {
    local language="${1:-$HELP_DEFAULT_LANGUAGE}"
    
    log_debug "Initializing help tokens for language: $language"
    
    # Language features map to their i18n tokens
    # Features define what tokens they need, help.sh manages mapping
    HELP_TOKEN_MAP["error.file_not_found"]="errors.file_not_found"
    HELP_TOKEN_MAP["error.invalid_command"]="errors.invalid_command"
    HELP_TOKEN_MAP["error.missing_args"]="errors.missing_arguments"
    HELP_TOKEN_MAP["error.permission_denied"]="errors.permission_denied"
    
    # Command help tokens
    HELP_TOKEN_MAP["command.init.name"]="commands.init.name"
    HELP_TOKEN_MAP["command.init.description"]="commands.init.description"
    HELP_TOKEN_MAP["command.init.usage"]="commands.init.usage"
    HELP_TOKEN_MAP["command.init.examples"]="commands.init.examples"
    
    HELP_TOKEN_MAP["command.build.name"]="commands.build.name"
    HELP_TOKEN_MAP["command.build.description"]="commands.build.description"
    HELP_TOKEN_MAP["command.build.usage"]="commands.build.usage"
    
    HELP_TOKEN_MAP["command.test.name"]="commands.test.name"
    HELP_TOKEN_MAP["command.test.description"]="commands.test.description"
    HELP_TOKEN_MAP["command.test.usage"]="commands.test.usage"
    
    # General UI tokens
    HELP_TOKEN_MAP["ui.available_commands"]="ui.available_commands"
    HELP_TOKEN_MAP["ui.usage"]="ui.usage"
    HELP_TOKEN_MAP["ui.examples"]="ui.examples"
    HELP_TOKEN_MAP["ui.options"]="ui.options"
    HELP_TOKEN_MAP["ui.see_also"]="ui.see_also"
    
    # Status messages
    HELP_TOKEN_MAP["status.success"]="status.success"
    HELP_TOKEN_MAP["status.error"]="status.error"
    HELP_TOKEN_MAP["status.warning"]="status.warning"
    HELP_TOKEN_MAP["status.info"]="status.info"
}

# Resolve language-agnostic token to file path
resolve_help_token() {
    local feature_token="$1"
    local language="${2:-$HELP_DEFAULT_LANGUAGE}"
    
    # Map feature token to i18n path
    local i18n_token="${HELP_TOKEN_MAP[$feature_token]}"
    
    if [[ -z "$i18n_token" ]]; then
        log_error "Unknown help token: $feature_token"
        return 1
    fi
    
    ABADDON_HELP_TOKEN="$i18n_token"
    return 0
}

# Get translation file path for language
get_translation_file() {
    local language="${1:-$HELP_DEFAULT_LANGUAGE}"
    echo "$HELP_TRANSLATIONS_DIR/${language}.json"
}

# ============================================================================
# Public Interface
# ============================================================================

# Main entry point for help text retrieval
get_help_text() {
    local feature_token="$1"
    local language="${2:-$HELP_DEFAULT_LANGUAGE}"
    
    # Clear previous state
    ABADDON_HELP_TEXT=""
    ABADDON_HELP_STATUS=""
    ABADDON_HELP_LANGUAGE="$language"
    ABADDON_HELP_TOKEN=""
    
    # Input validation
    if [[ -z "$feature_token" ]]; then
        ABADDON_HELP_STATUS="error"
        log_error "get_help_text requires feature token"
        return 1
    fi
    
    # Initialize tokens if needed
    if [[ ${#HELP_TOKEN_MAP[@]} -eq 0 ]]; then
        init_help_tokens "$language"
    fi
    
    # Resolve feature token to i18n path
    if ! resolve_help_token "$feature_token" "$language"; then
        ABADDON_HELP_STATUS="error"
        return 1
    fi
    
    # Get translation file
    local translation_file
    translation_file=$(get_translation_file "$language")
    
    if [[ ! -f "$translation_file" ]]; then
        ABADDON_HELP_STATUS="no_translation"
        log_warning "Translation file not found: $translation_file"
        
        # Fallback to default language if different
        if [[ "$language" != "$HELP_DEFAULT_LANGUAGE" ]]; then
            log_debug "Falling back to default language: $HELP_DEFAULT_LANGUAGE"
            get_help_text "$feature_token" "$HELP_DEFAULT_LANGUAGE"
            return $?
        fi
        
        return 1
    fi
    
    # Use kv.sh to retrieve the text
    get_config_value "$ABADDON_HELP_TOKEN" "$translation_file"
    
    case "$KV_STATE_STATUS" in
        success)
            ABADDON_HELP_TEXT="$KV_STATE_VALUE"
            ABADDON_HELP_STATUS="success"
            log_debug "Retrieved help text for '$feature_token': ${ABADDON_HELP_TEXT:0:50}..."
            return 0
            ;;
        not_found)
            ABADDON_HELP_STATUS="not_found"
            log_warning "Help text not found for token: $ABADDON_HELP_TOKEN"
            return 1
            ;;
        *)
            ABADDON_HELP_STATUS="error"
            log_error "Failed to retrieve help text: $KV_STATE_STATUS"
            return 1
            ;;
    esac
}

# Get formatted help with rich terminal output
get_formatted_help() {
    local feature_token="$1"
    local language="${2:-$HELP_DEFAULT_LANGUAGE}"
    
    if get_help_text "$feature_token" "$language"; then
        # Apply rich formatting using progress.sh
        local formatted_text
        formatted_text=$(format_bold "$ABADDON_HELP_TEXT")
        echo "$formatted_text"
        return 0
    else
        # Show error with appropriate icon
        local error_icon
        error_icon=$(status_icon "error" false)
        echo "$error_icon Help not available: $feature_token"
        return 1
    fi
}

# Check if help text exists for a token
help_text_exists() {
    local feature_token="$1"
    local language="${2:-$HELP_DEFAULT_LANGUAGE}"
    
    get_help_text "$feature_token" "$language" >/dev/null 2>&1
    [[ "$ABADDON_HELP_STATUS" == "success" ]]
}

# Get help for command with full formatting
show_command_help() {
    local command="$1"
    local language="${2:-$HELP_DEFAULT_LANGUAGE}"
    
    if [[ -z "$command" ]]; then
        log_error "show_command_help requires command name"
        return 1
    fi
    
    # Display command name
    if get_help_text "command.${command}.name" "$language"; then
        local name_header
        name_header=$(format_bold "$ABADDON_HELP_TEXT")
        echo "$name_header"
        echo
    fi
    
    # Display description
    if get_help_text "command.${command}.description" "$language"; then
        echo "$ABADDON_HELP_TEXT"
        echo
    fi
    
    # Display usage
    if get_help_text "command.${command}.usage" "$language"; then
        local usage_label
        if get_help_text "ui.usage" "$language"; then
            usage_label=$(format_underline "$ABADDON_HELP_TEXT")
            echo "$usage_label"
        fi
        echo "  $ABADDON_HELP_TEXT"
        echo
    fi
    
    # Display examples if available
    if get_help_text "command.${command}.examples" "$language"; then
        local examples_label
        if get_help_text "ui.examples" "$language"; then
            examples_label=$(format_underline "$ABADDON_HELP_TEXT")
            echo "$examples_label"
        fi
        echo "  $ABADDON_HELP_TEXT"
        echo
    fi
}

# Show all available commands
show_available_commands() {
    local language="${1:-$HELP_DEFAULT_LANGUAGE}"
    
    # Header
    if get_help_text "ui.available_commands" "$language"; then
        local header
        header=$(format_bold "$ABADDON_HELP_TEXT")
        echo "$header"
        echo
    fi
    
    # List known commands
    local commands=("init" "build" "test")
    
    for cmd in "${commands[@]}"; do
        local icon
        icon=$(status_icon "info" false)
        
        local cmd_name=""
        local cmd_desc=""
        
        if get_help_text "command.${cmd}.name" "$language"; then
            cmd_name="$ABADDON_HELP_TEXT"
        fi
        
        if get_help_text "command.${cmd}.description" "$language"; then
            cmd_desc="$ABADDON_HELP_TEXT"
        fi
        
        if [[ -n "$cmd_name" && -n "$cmd_desc" ]]; then
            printf "  %s %-12s %s\n" "$icon" "$cmd_name" "$cmd_desc"
        fi
    done
    echo
}

# Display error message with appropriate formatting
show_help_error() {
    local error_token="$1"
    local context="${2:-}"
    local language="${3:-$HELP_DEFAULT_LANGUAGE}"
    
    if get_help_text "$error_token" "$language"; then
        local error_icon
        error_icon=$(status_icon "error" false)
        
        local error_text="$ABADDON_HELP_TEXT"
        if [[ -n "$context" ]]; then
            error_text="${error_text}: $context"
        fi
        
        echo "$error_icon $error_text" >&2
    else
        # Fallback error display
        local error_icon
        error_icon=$(status_icon "error" false)
        echo "$error_icon Error: $error_token" >&2
    fi
}

# ============================================================================
# State Management
# ============================================================================

# Reset help state
reset_help_state() {
    ABADDON_HELP_TEXT=""
    ABADDON_HELP_STATUS=""
    ABADDON_HELP_LANGUAGE=""
    ABADDON_HELP_TOKEN=""
    log_debug "Help state reset"
}

# Set help error state
set_help_error() {
    local error_message="$1"
    ABADDON_HELP_STATUS="error"
    ABADDON_HELP_TEXT="$error_message"
    log_error "Help Error: $error_message"
}

# Set help success state
set_help_success() {
    local value="${1:-}"
    ABADDON_HELP_STATUS="success"
    if [[ -n "$value" ]]; then
        ABADDON_HELP_TEXT="$value"
    fi
    log_debug "Help Success: operation completed"
}

# ============================================================================
# Utility Functions  
# ============================================================================

# List all available languages
list_available_languages() {
    if [[ -d "$HELP_TRANSLATIONS_DIR" ]]; then
        find "$HELP_TRANSLATIONS_DIR" -name "*.json" -exec basename {} .json \;
    fi
}

# Get current language setting
get_current_language() {
    echo "${ABADDON_HELP_LANGUAGE:-$HELP_DEFAULT_LANGUAGE}"
}

# Validate help system functionality
help_validate() {
    local errors=0
    
    # Check core functions exist
    for func in get_help_text show_command_help show_available_commands; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    for var in ABADDON_HELP_TEXT ABADDON_HELP_STATUS ABADDON_HELP_LANGUAGE; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    # Check dependencies
    if ! get_config_value "test" "test" >/dev/null 2>&1; then
        log_error "kv.sh dependency not working"
        ((errors++))
    fi
    
    return $errors
}

# Module information
help_info() {
    echo "abaddon-help.sh - Language-Agnostic Help System"
    echo "Version: 1.0.0"
    echo "Functions: get_help_text, show_command_help, show_available_commands"
    echo "State: ABADDON_HELP_TEXT, ABADDON_HELP_STATUS, ABADDON_HELP_LANGUAGE"
    echo "Translations: $HELP_TRANSLATIONS_DIR"
}

log_debug "abaddon-help.sh loaded successfully"