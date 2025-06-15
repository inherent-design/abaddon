#!/usr/bin/env bash
# Abaddon i18n - Translation and internationalization service
# Version: 2.0.0
# Purpose: Extensible i18n with lean core + application domain support

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_I18N_LOADED:-}" ]] && return 0
readonly ABADDON_I18N_LOADED=1

# Dependency checks
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-i18n.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_KV_LOADED:-}" ]] || {
    echo "ERROR: abaddon-i18n.sh requires abaddon-kv.sh to be loaded first" >&2
    return 1
}

# ============================================================================
# Configuration and State Variables
# ============================================================================

# Configuration - environment configurable
declare -g ABADDON_I18N_DEFAULT_LOCALE="${ABADDON_I18N_DEFAULT_LOCALE:-en}"
declare -g ABADDON_I18N_FRAMEWORK_TRANSLATIONS_DIR="${ABADDON_I18N_FRAMEWORK_TRANSLATIONS_DIR:-${ABADDON_LIB_DIR:-$HOME/.local/lib/abaddon}/translations}"
declare -g ABADDON_I18N_APP_TRANSLATIONS_DIR="${ABADDON_I18N_APP_TRANSLATIONS_DIR:-}"
declare -g ABADDON_I18N_APP_DOMAIN="${ABADDON_I18N_APP_DOMAIN:-}"

# State variables - NO stdout pollution
declare -g ABADDON_I18N_CURRENT_LOCALE=""
declare -g ABADDON_I18N_TRANSLATED_TEXT=""
declare -g ABADDON_I18N_LOOKUP_STATUS=""
declare -g ABADDON_I18N_LAST_KEY=""
declare -g ABADDON_I18N_SUBSTITUTION_COUNT=0
declare -g ABADDON_I18N_ERROR_MESSAGE=""

# I18n result constants
readonly ABADDON_I18N_SUCCESS="success"
readonly ABADDON_I18N_ERROR="error"
readonly ABADDON_I18N_NOT_FOUND="not_found"
readonly ABADDON_I18N_DOMAIN_ERROR="domain_error"

# Domain registry for extensible translation contexts
declare -A ABADDON_I18N_DOMAIN_PATHS
declare -g ABADDON_I18N_INITIALIZED="${ABADDON_I18N_INITIALIZED:-false}"

# ============================================================================
# Core Initialization
# ============================================================================

# Initialize i18n system with extensible domain support
i18n_init() {
    local app_domain=""
    local app_translations_dir=""
    local user_locale_config=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-domain=*)
                app_domain="${1#*=}"
                ;;
            --app-translations=*)
                app_translations_dir="${1#*=}"
                ;;
            --user-locale-config=*)
                user_locale_config="${1#*=}"
                ;;
            *)
                log_error "Unknown i18n_init parameter: $1"
                return 1
                ;;
        esac
        shift
    done
    
    log_debug "Initializing i18n system"
    log_debug "App domain: ${app_domain:-none}"
    log_debug "App translations: ${app_translations_dir:-none}"
    
    # Initialize core abladdon domain
    ABADDON_I18N_DOMAIN_PATHS["abaddon"]="$ABADDON_I18N_FRAMEWORK_TRANSLATIONS_DIR"
    
    # Register primary application domain if provided
    if [[ -n "$app_domain" && -n "$app_translations_dir" ]]; then
        ABADDON_I18N_APP_DOMAIN="$app_domain"
        ABADDON_I18N_APP_TRANSLATIONS_DIR="$app_translations_dir"
        ABADDON_I18N_DOMAIN_PATHS["$app_domain"]="$app_translations_dir"
        log_debug "Registered app domain: $app_domain -> $app_translations_dir"
    fi
    
    # Detect locale
    detect_locale "$user_locale_config"
    
    ABADDON_I18N_INITIALIZED="true"
    log_debug "i18n system initialized (locale: $ABADDON_I18N_CURRENT_LOCALE)"
    return 0
}

# Detect current locale from environment and config
detect_locale() {
    local user_config_file="$1"
    local detected_locale=""
    
    # Priority 1: User configuration file
    if [[ -n "$user_config_file" && -f "$user_config_file" ]]; then
        get_config_value "locale" "$user_config_file" ""
        local config_locale=$(get_kv_value)
        if [[ -n "$config_locale" ]]; then
            detected_locale="$config_locale"
            log_debug "Locale from config: $detected_locale"
        fi
    fi
    
    # Priority 2: LANG environment variable
    if [[ -z "$detected_locale" && -n "${LANG:-}" ]]; then
        # Extract language code (en_US.UTF-8 -> en)
        detected_locale="${LANG%%_*}"
        detected_locale="${detected_locale%.*}"
        log_debug "Locale from LANG: $detected_locale"
    fi
    
    # Priority 3: Default fallback
    if [[ -z "$detected_locale" ]]; then
        detected_locale="$ABADDON_I18N_DEFAULT_LOCALE"
        log_debug "Locale from default: $detected_locale"
    fi
    
    ABADDON_I18N_CURRENT_LOCALE="$detected_locale"
}

# Add application domain (for runtime extension)
add_i18n_domain() {
    local domain="$1"
    local translations_dir="$2"
    
    if [[ -z "$domain" || -z "$translations_dir" ]]; then
        log_error "Domain name and translations directory are required"
        return 1
    fi
    
    # Validate translations directory exists
    if [[ ! -d "$translations_dir" ]]; then
        log_error "Translations directory does not exist: $translations_dir"
        return 1
    fi
    
    # Register domain
    ABADDON_I18N_DOMAIN_PATHS["$domain"]="$translations_dir"
    log_debug "Added i18n domain: $domain -> $translations_dir"
    return 0
}

# ============================================================================
# Translation Functions
# ============================================================================

# Main translation function with variable substitution
# Usage: t 'domain.key' [var1] [var2] ...
t() {
    local key="$1"
    shift
    local variables=("$@")
    
    if [[ "$ABADDON_I18N_INITIALIZED" != "true" ]]; then
        log_error "i18n system not initialized - call i18n_init first"
        ABADDON_I18N_TRANSLATED_TEXT="[i18n_not_initialized:$key]"
        ABADDON_I18N_LOOKUP_STATUS="$ABADDON_I18N_ERROR"
        return 1
    fi
    
    ABADDON_I18N_LAST_KEY="$key"
    ABADDON_I18N_SUBSTITUTION_COUNT=${#variables[@]}
    
    # Extract domain from key (domain.path.to.string)
    local domain="${key%%.*}"
    local key_path="${key#*.}"
    
    # Route to appropriate translation directory
    local translations_dir="${ABADDON_I18N_DOMAIN_PATHS[$domain]:-}"
    
    if [[ -z "$translations_dir" ]]; then
        log_debug "Unknown domain: $domain, falling back to app domain"
        if [[ -n "$ABADDON_I18N_APP_DOMAIN" ]]; then
            translations_dir="$ABADDON_I18N_APP_TRANSLATIONS_DIR"
            key_path="$key"  # Use full key if domain not recognized
        else
            ABADDON_I18N_TRANSLATED_TEXT="[unknown_domain:$key]"
            ABADDON_I18N_LOOKUP_STATUS="$ABADDON_I18N_DOMAIN_ERROR"
            return 1
        fi
    fi
    
    # Look up translation string
    local translation_file="$translations_dir/${ABADDON_I18N_CURRENT_LOCALE}.json"
    
    # Fallback to English if locale file doesn't exist
    if [[ ! -f "$translation_file" ]]; then
        translation_file="$translations_dir/en.json"
        log_debug "Locale file not found, falling back to English"
    fi
    
    if [[ ! -f "$translation_file" ]]; then
        ABADDON_I18N_TRANSLATED_TEXT="[missing_translation_file:$key]"
        ABADDON_I18N_LOOKUP_STATUS="$ABADDON_I18N_ERROR"
        return 1
    fi
    
    # Get translation using KV system (with caching)
    get_config_value "$key_path" "$translation_file" ""
    local raw_text=$(get_kv_value)
    local kv_status=$(get_kv_status)
    
    if [[ "$kv_status" != "success" || -z "$raw_text" ]]; then
        ABADDON_I18N_TRANSLATED_TEXT="[missing_key:$key]"
        ABADDON_I18N_LOOKUP_STATUS="$ABADDON_I18N_NOT_FOUND"
        return 1
    fi
    
    # Perform variable substitution
    substitute_variables "$raw_text" "${variables[@]}"
    
    ABADDON_I18N_LOOKUP_STATUS="$ABADDON_I18N_SUCCESS"
    log_debug "Translation successful: $key -> ${#ABADDON_I18N_TRANSLATED_TEXT} chars"
    return 0
}

# Variable substitution with {0}, {1}, {n} placeholders
substitute_variables() {
    local text="$1"
    shift
    local variables=("$@")
    
    local result="$text"
    
    # Replace {0}, {1}, {2}, etc. with provided variables
    for i in "${!variables[@]}"; do
        local placeholder="{$i}"
        local value="${variables[$i]}"
        result="${result//$placeholder/$value}"
    done
    
    ABADDON_I18N_TRANSLATED_TEXT="$result"
}

# ============================================================================
# State Access Functions
# ============================================================================

# ============================================================================
# State Access Functions (P3 standardized)
# ============================================================================

# Get the translated text (clean data access)
get_i18n_value() {
    echo "$ABADDON_I18N_TRANSLATED_TEXT"
}

# Alias for backward compatibility
get_translated_text() {
    echo "$ABADDON_I18N_TRANSLATED_TEXT"
}

# Get translation lookup status
get_i18n_status() {
    echo "$ABADDON_I18N_LOOKUP_STATUS"
}

# Alias for backward compatibility
get_translation_status() {
    echo "$ABADDON_I18N_LOOKUP_STATUS"
}

# Get last translation key
get_i18n_last_key() {
    echo "$ABADDON_I18N_LAST_KEY"
}

# Get current locale
get_i18n_locale() {
    echo "$ABADDON_I18N_CURRENT_LOCALE"
}

# Get substitution count for last translation
get_i18n_substitution_count() {
    echo "$ABADDON_I18N_SUBSTITUTION_COUNT"
}

# Get error message
get_i18n_error_message() {
    echo "$ABADDON_I18N_ERROR_MESSAGE"
}

# Check if last operation succeeded
i18n_succeeded() { [[ "$ABADDON_I18N_LOOKUP_STATUS" == "$ABADDON_I18N_SUCCESS" ]]; }
i18n_failed() { [[ "$ABADDON_I18N_LOOKUP_STATUS" != "$ABADDON_I18N_SUCCESS" ]]; }

# ============================================================================
# Utility Functions
# ============================================================================

# Check if i18n system is ready
is_i18n_ready() {
    [[ "$ABADDON_I18N_INITIALIZED" == "true" ]]
}

# List available domains
list_i18n_domains() {
    local domains=()
    for domain in "${!ABADDON_I18N_DOMAIN_PATHS[@]}"; do
        domains+=("$domain")
    done
    printf '%s\n' "${domains[@]}"
}

# Alias for backward compatibility
list_translation_domains() {
    list_i18n_domains
}

# Check if translation file exists for current locale
check_i18n_domain_file() {
    local domain="$1"
    local translations_dir="${ABADDON_I18N_DOMAIN_PATHS[$domain]:-}"
    
    if [[ -z "$translations_dir" ]]; then
        return 1
    fi
    
    local translation_file="$translations_dir/${ABADDON_I18N_CURRENT_LOCALE}.json"
    [[ -f "$translation_file" ]]
}

# Validate i18n module (for DFCPT testing)
validate_i18n() {
    log_debug "Validating i18n module state"
    
    # Check initialization
    if [[ "$I18N_INITIALIZED" != "true" ]]; then
        log_error "i18n module not initialized"
        return 1
    fi
    
    # Check required directories
    if [[ ! -d "$ABADDON_I18N_FRAMEWORK_TRANSLATIONS_DIR" ]]; then
        log_error "Framework translations directory missing: $ABADDON_I18N_FRAMEWORK_TRANSLATIONS_DIR"
        return 1
    fi
    
    # Check locale detection
    if [[ -z "$ABADDON_I18N_STATE_CURRENT_LOCALE" ]]; then
        log_error "Current locale not detected"
        return 1
    fi
    
    log_debug "i18n module validation successful"
    return 0
}

# ============================================================================
# i18n State Management
# ============================================================================

# Reset i18n state (P3 standardized)
reset_i18n_state() {
    ABADDON_I18N_CURRENT_LOCALE=""
    ABADDON_I18N_TRANSLATED_TEXT=""
    ABADDON_I18N_LOOKUP_STATUS=""
    ABADDON_I18N_LAST_KEY=""
    ABADDON_I18N_SUBSTITUTION_COUNT=0
    ABADDON_I18N_ERROR_MESSAGE=""
    ABADDON_I18N_INITIALIZED="false"
    ABADDON_I18N_APP_DOMAIN=""
    ABADDON_I18N_APP_TRANSLATIONS_DIR=""
    unset ABADDON_I18N_DOMAIN_PATHS 2>/dev/null || true
    declare -A ABADDON_I18N_DOMAIN_PATHS
    log_debug "i18n state reset"
}

# Legacy alias for backward compatibility
clear_i18n_state() {
    reset_i18n_state
}

# Set i18n error state
set_i18n_error() {
    local error_message="$1"
    ABADDON_I18N_LOOKUP_STATUS="$ABADDON_I18N_ERROR"
    ABADDON_I18N_ERROR_MESSAGE="$error_message"
    ABADDON_I18N_TRANSLATED_TEXT="$error_message"
    log_error "i18n Error: $error_message"
}

# Set i18n success state
set_i18n_success() {
    local translated_text="$1"
    ABADDON_I18N_LOOKUP_STATUS="$ABADDON_I18N_SUCCESS"
    ABADDON_I18N_ERROR_MESSAGE=""
    ABADDON_I18N_TRANSLATED_TEXT="$translated_text"
    log_debug "i18n Success: translation found"
}

# ============================================================================
# Module Validation and Information
# ============================================================================

# Validate i18n module functionality (P3 standardized)
i18n_validate() {
    local errors=0
    
    # Check required functions exist
    local required_functions=(
        "i18n_init" "t" "add_i18n_domain"
        "reset_i18n_state" "set_i18n_error" "set_i18n_success"
        "get_i18n_value" "get_i18n_status" "list_i18n_domains"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_I18N_CURRENT_LOCALE" "ABADDON_I18N_TRANSLATED_TEXT" "ABADDON_I18N_LOOKUP_STATUS"
        "ABADDON_I18N_LAST_KEY" "ABADDON_I18N_SUBSTITUTION_COUNT" "ABADDON_I18N_ERROR_MESSAGE"
        "ABADDON_I18N_INITIALIZED"
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
    
    if [[ -z "${ABADDON_KV_LOADED:-}" ]]; then
        log_error "KV dependency not loaded"
        ((errors++))
    fi
    
    return $errors
}

# Legacy alias for backward compatibility
validate_i18n() {
    i18n_validate
}

# Module information
i18n_info() {
    echo "Abaddon i18n - Extensible translation registry with variable substitution"
    echo "Version: 2.0.0"
    echo "Dependencies: core.sh, kv.sh"
    echo "Features: Multi-domain translation, locale detection, variable substitution, runtime extension"
    echo "Main Functions:"
    echo "  i18n_init(--app-domain=name --app-translations=dir)"
    echo "  t(domain.key [var1] [var2] ...)"
    echo "  add_i18n_domain(domain, translations_dir)"
    echo "  get_i18n_value(), get_i18n_status(), get_i18n_locale()"
    echo "  list_i18n_domains()"
}