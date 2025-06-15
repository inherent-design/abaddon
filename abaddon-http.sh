#!/usr/bin/env bash
# Abaddon HTTP - Generic HTTP client with response parsing integration
# Version: 1.0.0
# Purpose: HTTP client primitive integrating cache, validation, and KV parsing

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_HTTP_LOADED:-}" ]] && return 0
readonly ABADDON_HTTP_LOADED=1

# Dependency checks
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-http.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] || {
    echo "ERROR: abaddon-http.sh requires abaddon-platform.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_CACHE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-http.sh requires abaddon-cache.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_VALIDATION_LOADED:-}" ]] || {
    echo "ERROR: abaddon-http.sh requires abaddon-validation.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_KV_LOADED:-}" ]] || {
    echo "ERROR: abaddon-http.sh requires abaddon-kv.sh to be loaded first" >&2
    return 1
}

# ============================================================================
# Configuration and State Variables
# ============================================================================

# Configuration - environment configurable
declare -g ABADDON_HTTP_USER_AGENT="${ABADDON_HTTP_USER_AGENT:-Abaddon-HTTP/1.0.0}"
declare -g ABADDON_HTTP_TIMEOUT="${ABADDON_HTTP_TIMEOUT:-30}"
declare -g ABADDON_HTTP_MAX_REDIRECTS="${ABADDON_HTTP_MAX_REDIRECTS:-5}"
declare -g ABADDON_HTTP_RETRY_COUNT="${ABADDON_HTTP_RETRY_COUNT:-3}"
declare -g ABADDON_HTTP_RETRY_DELAY="${ABADDON_HTTP_RETRY_DELAY:-1}"
declare -g ABADDON_HTTP_CACHE_ENABLED="${ABADDON_HTTP_CACHE_ENABLED:-true}"

# State variables - NO stdout pollution
declare -g ABADDON_HTTP_RESPONSE_BODY=""
declare -g ABADDON_HTTP_RESPONSE_HEADERS=""
declare -g ABADDON_HTTP_STATUS_CODE=""
declare -g ABADDON_HTTP_STATUS=""
declare -g ABADDON_HTTP_ERROR_MESSAGE=""
declare -g ABADDON_HTTP_LAST_URL=""
declare -g ABADDON_HTTP_LAST_METHOD=""
declare -g ABADDON_HTTP_EXECUTION_TIME=""

# HTTP result constants
readonly ABADDON_HTTP_SUCCESS="success"
readonly ABADDON_HTTP_ERROR="error"
readonly ABADDON_HTTP_NETWORK_ERROR="network_error"
readonly ABADDON_HTTP_TIMEOUT_ERROR="timeout_error"
readonly ABADDON_HTTP_INVALID_URL="invalid_url"
readonly ABADDON_HTTP_HTTP_ERROR="http_error"

# HTTP client detection and preferences
declare -g ABADDON_HTTP_CLIENT=""
declare -g ABADDON_HTTP_CLIENT_DETECTED="${ABADDON_HTTP_CLIENT_DETECTED:-false}"

# Performance tracking
declare -g ABADDON_HTTP_REQUESTS=0
declare -g ABADDON_HTTP_CACHE_HITS=0
declare -g ABADDON_HTTP_NETWORK_ERRORS=0

# ============================================================================
# HTTP Client Detection and Configuration
# ============================================================================

# Detect available HTTP client using Platform module
detect_http_client() {
    if [[ "$ABADDON_HTTP_CLIENT_DETECTED" == "true" ]]; then
        return 0
    fi
    
    log_debug "Detecting available HTTP client using Platform module"
    
    # Use Platform module's tool detection with preference order
    local best_client
    best_client=$(get_best_tool "http_client" 2>/dev/null)
    
    if [[ -n "$best_client" && "$best_client" != "none" ]]; then
        ABADDON_HTTP_CLIENT="$best_client"
        log_debug "Using $best_client as HTTP client (via Platform detection)"
    else
        # Fallback to manual detection if Platform doesn't have http_client category
        log_debug "Platform http_client category not found, using manual detection"
        
        # Preference order: curl > wget > fetch
        if check_tool "curl"; then
            ABADDON_HTTP_CLIENT="curl"
            log_debug "Using curl as HTTP client"
        elif check_tool "wget"; then
            ABADDON_HTTP_CLIENT="wget"  
            log_debug "Using wget as HTTP client"
        elif check_tool "fetch"; then
            ABADDON_HTTP_CLIENT="fetch"
            log_debug "Using fetch as HTTP client"
        else
            ABADDON_HTTP_CLIENT=""
            log_error "No HTTP client available (curl, wget, or fetch required)"
            ABADDON_HTTP_CLIENT_DETECTED="true"
            return 1
        fi
    fi
    
    ABADDON_HTTP_CLIENT_DETECTED="true"
    log_debug "HTTP client detection complete: $ABADDON_HTTP_CLIENT"
    return 0
}

# ============================================================================
# Core HTTP Functions
# ============================================================================

# Generic HTTP request function
http_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    shift 3
    local headers=("$@")
    
    # Reset state
    reset_http_state
    
    # Input validation
    if [[ -z "$method" || -z "$url" ]]; then
        ABADDON_HTTP_STATUS="$ABADDON_HTTP_ERROR"
        ABADDON_HTTP_ERROR_MESSAGE="http_request requires method and URL"
        log_error "$ABADDON_HTTP_ERROR_MESSAGE"
        return 1
    fi
    
    # Validate URL
    if ! validate_url "$url"; then
        ABADDON_HTTP_STATUS="$ABADDON_HTTP_INVALID_URL"
        ABADDON_HTTP_ERROR_MESSAGE="Invalid URL format: $url"
        log_error "$ABADDON_HTTP_ERROR_MESSAGE"
        return 1
    fi
    
    # Detect HTTP client
    if ! detect_http_client; then
        ABADDON_HTTP_STATUS="$ABADDON_HTTP_ERROR"
        ABADDON_HTTP_ERROR_MESSAGE="No HTTP client available"
        return 1
    fi
    
    # Check cache for GET requests
    local cache_key=""
    if [[ "$method" == "GET" && "$ABADDON_HTTP_CACHE_ENABLED" == "true" ]]; then
        cache_key="http_${method}_$(echo -n "$url" | sha256sum | cut -d' ' -f1)"
        if cache_get "$cache_key" >/dev/null 2>&1; then
            ABADDON_HTTP_RESPONSE_BODY="$(cache_get "$cache_key")"
            ABADDON_HTTP_STATUS="$ABADDON_HTTP_SUCCESS"
            ABADDON_HTTP_STATUS_CODE="200"
            ABADDON_HTTP_LAST_URL="$url"
            ABADDON_HTTP_LAST_METHOD="$method"
            ((ABADDON_HTTP_CACHE_HITS++))
            log_debug "HTTP cache hit for $method $url"
            return 0
        fi
    fi
    
    # Track state
    ABADDON_HTTP_LAST_URL="$url"
    ABADDON_HTTP_LAST_METHOD="$method"
    ((ABADDON_HTTP_REQUESTS++))
    
    # Execute request with timing
    local start_time end_time
    start_time=$(date +%s%N 2>/dev/null || date +%s)
    
    local temp_response temp_headers
    temp_response=$(mktemp)
    temp_headers=$(mktemp)
    
    # Cleanup temporary files on exit
    trap "rm -f '$temp_response' '$temp_headers'" EXIT
    
    local exit_code=0
    
    # Handle file:// URLs directly
    if [[ "$url" =~ ^file:// ]]; then
        execute_file_request "$method" "$url" "$data" "$temp_response" "$temp_headers"
        exit_code=$?
    else
        case "$ABADDON_HTTP_CLIENT" in
            curl)
                execute_curl_request "$method" "$url" "$data" "$temp_response" "$temp_headers" "${headers[@]}"
                exit_code=$?
                ;;
            wget)
                execute_wget_request "$method" "$url" "$data" "$temp_response" "$temp_headers" "${headers[@]}"
                exit_code=$?
                ;;
            fetch)
                execute_fetch_request "$method" "$url" "$data" "$temp_response" "$temp_headers" "${headers[@]}"
                exit_code=$?
                ;;
            *)
                ABADDON_HTTP_STATUS="$ABADDON_HTTP_ERROR"
                ABADDON_HTTP_ERROR_MESSAGE="Unknown HTTP client: $ABADDON_HTTP_CLIENT"
                return 1
                ;;
        esac
    fi
    
    # Calculate execution time
    end_time=$(date +%s%N 2>/dev/null || date +%s)
    if [[ "$start_time" =~ [0-9]{13,} ]]; then
        local duration=$(((end_time - start_time) / 1000000))
        ABADDON_HTTP_EXECUTION_TIME="${duration}ms"
    else
        local duration=$((end_time - start_time))
        ABADDON_HTTP_EXECUTION_TIME="${duration}s"
    fi
    
    # Process response
    if [[ $exit_code -eq 0 && -f "$temp_response" ]]; then
        ABADDON_HTTP_RESPONSE_BODY="$(cat "$temp_response")"
        if [[ -f "$temp_headers" ]]; then
            ABADDON_HTTP_RESPONSE_HEADERS="$(cat "$temp_headers")"
        fi
        
        # Cache successful GET responses
        if [[ "$method" == "GET" && "$ABADDON_HTTP_CACHE_ENABLED" == "true" && -n "$cache_key" ]]; then
            cache_store "$cache_key" "$ABADDON_HTTP_RESPONSE_BODY"
        fi
        
        ABADDON_HTTP_STATUS="$ABADDON_HTTP_SUCCESS"
        log_debug "HTTP $method $url completed in $ABADDON_HTTP_EXECUTION_TIME"
    else
        ((ABADDON_HTTP_NETWORK_ERRORS++))
        ABADDON_HTTP_STATUS="$ABADDON_HTTP_NETWORK_ERROR"
        ABADDON_HTTP_ERROR_MESSAGE="HTTP request failed (exit code: $exit_code)"
        log_error "$ABADDON_HTTP_ERROR_MESSAGE"
    fi
    
    # Cleanup
    rm -f "$temp_response" "$temp_headers"
    trap - EXIT
    
    return $exit_code
}

# HTTP GET request
http_get() {
    local url="$1"
    shift
    local headers=("$@")
    
    log_debug "HTTP GET: $url"
    http_request "GET" "$url" "" "${headers[@]}"
}

# HTTP POST request
http_post() {
    local url="$1"
    local data="$2"
    shift 2
    local headers=("$@")
    
    log_debug "HTTP POST: $url (data length: ${#data})"
    http_request "POST" "$url" "$data" "${headers[@]}"
}

# HTTP PUT request
http_put() {
    local url="$1"
    local data="$2"
    shift 2
    local headers=("$@")
    
    log_debug "HTTP PUT: $url (data length: ${#data})"
    http_request "PUT" "$url" "$data" "${headers[@]}"
}

# HTTP DELETE request
http_delete() {
    local url="$1"
    shift
    local headers=("$@")
    
    log_debug "HTTP DELETE: $url"
    http_request "DELETE" "$url" "" "${headers[@]}"
}

# ============================================================================
# Response Parsing Integration
# ============================================================================

# Parse HTTP response using KV system
http_parse_response() {
    local format="$1"
    local path="$2"
    local default_value="${3:-}"
    
    if [[ -z "$ABADDON_HTTP_RESPONSE_BODY" ]]; then
        ABADDON_HTTP_STATUS="$ABADDON_HTTP_ERROR"
        ABADDON_HTTP_ERROR_MESSAGE="No HTTP response body to parse"
        log_error "$ABADDON_HTTP_ERROR_MESSAGE"
        return 1
    fi
    
    if [[ "$ABADDON_HTTP_STATUS" != "$ABADDON_HTTP_SUCCESS" ]]; then
        ABADDON_HTTP_ERROR_MESSAGE="Cannot parse response: HTTP request failed"
        log_error "$ABADDON_HTTP_ERROR_MESSAGE"
        return 1
    fi
    
    # Use new KV string extraction API - no temp files needed!
    kv_extract_string "$path" "$format" "$ABADDON_HTTP_RESPONSE_BODY" "$default_value"
}

# ============================================================================
# HTTP Client Implementations
# ============================================================================

# Execute curl request
execute_curl_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local response_file="$4"
    local headers_file="$5"
    shift 5
    local headers=("$@")
    
    local curl_args=(
        --silent
        --show-error
        --location
        --max-redirs "$ABADDON_HTTP_MAX_REDIRECTS"
        --max-time "$ABADDON_HTTP_TIMEOUT"
        --user-agent "$ABADDON_HTTP_USER_AGENT"
        --output "$response_file"
        --dump-header "$headers_file"
        --request "$method"
    )
    
    # Add custom headers
    for header in "${headers[@]}"; do
        curl_args+=(--header "$header")
    done
    
    # Add data for POST/PUT with automatic Content-Type detection
    if [[ -n "$data" && ("$method" == "POST" || "$method" == "PUT") ]]; then
        # Auto-detect JSON data and set Content-Type if not already specified
        local content_type_set=false
        for header in "${headers[@]}"; do
            if [[ "$header" =~ ^[Cc]ontent-[Tt]ype: ]]; then
                content_type_set=true
                break
            fi
        done
        
        # If data looks like JSON and no Content-Type set, add JSON header
        if [[ "$content_type_set" == "false" && "$data" =~ ^\s*[\{\[] ]]; then
            curl_args+=(--header "Content-Type: application/json")
        fi
        
        curl_args+=(--data "$data")
    fi
    
    curl "${curl_args[@]}" "$url"
    local exit_code=$?
    
    # Extract status code from headers
    if [[ -f "$headers_file" ]]; then
        ABADDON_HTTP_STATUS_CODE="$(head -1 "$headers_file" | cut -d' ' -f2)"
    fi
    
    return $exit_code
}

# Execute wget request
execute_wget_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local response_file="$4"
    local headers_file="$5"
    shift 5
    local headers=("$@")
    
    local wget_args=(
        --quiet
        --timeout="$ABADDON_HTTP_TIMEOUT"
        --user-agent="$ABADDON_HTTP_USER_AGENT"
        --output-document="$response_file"
        --save-headers
    )
    
    # Add custom headers
    for header in "${headers[@]}"; do
        wget_args+=(--header="$header")
    done
    
    # wget has limited method support
    case "$method" in
        GET)
            ;;
        POST)
            if [[ -n "$data" ]]; then
                wget_args+=(--post-data="$data")
            fi
            ;;
        *)
            log_error "wget does not support $method method"
            return 1
            ;;
    esac
    
    wget "${wget_args[@]}" "$url"
    local exit_code=$?
    
    # wget saves headers to response file, separate them
    if [[ -f "$response_file" && $exit_code -eq 0 ]]; then
        # Find empty line separating headers from body
        local separator_line
        separator_line=$(grep -n '^$' "$response_file" | head -1 | cut -d: -f1)
        
        if [[ -n "$separator_line" ]]; then
            head -n "$((separator_line - 1))" "$response_file" > "$headers_file"
            tail -n "+$((separator_line + 1))" "$response_file" > "${response_file}.tmp"
            mv "${response_file}.tmp" "$response_file"
            
            # Extract status code
            ABADDON_HTTP_STATUS_CODE="$(head -1 "$headers_file" | cut -d' ' -f2)"
        fi
    fi
    
    return $exit_code
}

# Execute fetch request (FreeBSD)
execute_fetch_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local response_file="$4"
    local headers_file="$5"
    shift 5
    local headers=("$@")
    
    # Basic fetch implementation (limited functionality)
    fetch -q -o "$response_file" "$url"
    local exit_code=$?
    
    # fetch has very limited header support
    echo "HTTP/1.1 200 OK" > "$headers_file"
    ABADDON_HTTP_STATUS_CODE="200"
    
    return $exit_code
}

# Execute file:// URL request
execute_file_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local response_file="$4"
    local headers_file="$5"
    
    # Extract file path from file:// URL
    local file_path="${url#file://}"
    
    # Handle different methods
    case "$method" in
        GET)
            if [[ -f "$file_path" && -r "$file_path" ]]; then
                cat "$file_path" > "$response_file"
                echo "HTTP/1.1 200 OK" > "$headers_file"
                echo "Content-Type: application/octet-stream" >> "$headers_file"
                ABADDON_HTTP_STATUS_CODE="200"
                return 0
            else
                echo "File not found or not readable" > "$response_file"
                echo "HTTP/1.1 404 Not Found" > "$headers_file"
                ABADDON_HTTP_STATUS_CODE="404"
                return 1
            fi
            ;;
        POST|PUT)
            if [[ -w "$(dirname "$file_path")" ]]; then
                echo "$data" > "$file_path"
                echo "File written successfully" > "$response_file"
                echo "HTTP/1.1 201 Created" > "$headers_file"
                ABADDON_HTTP_STATUS_CODE="201"
                return 0
            else
                echo "Cannot write to file" > "$response_file"
                echo "HTTP/1.1 403 Forbidden" > "$headers_file"
                ABADDON_HTTP_STATUS_CODE="403"
                return 1
            fi
            ;;
        DELETE)
            if [[ -f "$file_path" && -w "$(dirname "$file_path")" ]]; then
                rm -f "$file_path"
                echo "File deleted successfully" > "$response_file"
                echo "HTTP/1.1 204 No Content" > "$headers_file"
                ABADDON_HTTP_STATUS_CODE="204"
                return 0
            else
                echo "Cannot delete file" > "$response_file"
                echo "HTTP/1.1 404 Not Found" > "$headers_file"
                ABADDON_HTTP_STATUS_CODE="404"
                return 1
            fi
            ;;
        *)
            echo "Method not supported for file URLs" > "$response_file"
            echo "HTTP/1.1 405 Method Not Allowed" > "$headers_file"
            ABADDON_HTTP_STATUS_CODE="405"
            return 1
            ;;
    esac
}

# ============================================================================
# Validation and Utilities
# ============================================================================

# Validate URL format
validate_url() {
    local url="$1"
    
    # Support common URL schemes based on HTTP client capabilities
    local valid_schemes="^(https?|file)://"
    
    # Add FTP support if curl is available (most curl builds support FTP)
    if [[ "$ABADDON_HTTP_CLIENT" == "curl" ]] || command -v curl >/dev/null 2>&1; then
        valid_schemes="^(https?|file|ftps?)://"
    fi
    
    # Basic URL validation - require supported scheme
    if [[ ! "$url" =~ $valid_schemes ]]; then
        return 1
    fi
    
    # File URLs just need valid path
    if [[ "$url" =~ ^file:// ]]; then
        return 0
    fi
    
    # Network URLs need domain/host
    if [[ ! "$url" =~ ^[a-z]+://[^/]+ ]]; then
        return 1
    fi
    
    return 0
}

# ============================================================================
# State Management Functions
# ============================================================================

# Reset HTTP state
reset_http_state() {
    ABADDON_HTTP_RESPONSE_BODY=""
    ABADDON_HTTP_RESPONSE_HEADERS=""
    ABADDON_HTTP_STATUS_CODE=""
    ABADDON_HTTP_STATUS=""
    ABADDON_HTTP_ERROR_MESSAGE=""
    ABADDON_HTTP_LAST_URL=""
    ABADDON_HTTP_LAST_METHOD=""
    ABADDON_HTTP_EXECUTION_TIME=""
}

# Set HTTP error state
set_http_error() {
    local error_message="$1"
    ABADDON_HTTP_STATUS="$ABADDON_HTTP_ERROR"
    ABADDON_HTTP_ERROR_MESSAGE="$error_message"
    log_error "HTTP Error: $error_message"
}

# Set HTTP success state
set_http_success() {
    ABADDON_HTTP_STATUS="$ABADDON_HTTP_SUCCESS"
    ABADDON_HTTP_ERROR_MESSAGE=""
}

# ============================================================================
# State Accessor Functions
# ============================================================================

get_http_response() { echo "$ABADDON_HTTP_RESPONSE_BODY"; }
get_http_headers() { echo "$ABADDON_HTTP_RESPONSE_HEADERS"; }
get_http_status() { echo "$ABADDON_HTTP_STATUS"; }
get_http_status_code() { echo "$ABADDON_HTTP_STATUS_CODE"; }
get_http_error() { echo "$ABADDON_HTTP_ERROR_MESSAGE"; }
get_http_last_url() { echo "$ABADDON_HTTP_LAST_URL"; }
get_http_last_method() { echo "$ABADDON_HTTP_LAST_METHOD"; }
get_http_execution_time() { echo "$ABADDON_HTTP_EXECUTION_TIME"; }

# Check if last operation succeeded
http_succeeded() { [[ "$ABADDON_HTTP_STATUS" == "$ABADDON_HTTP_SUCCESS" ]]; }
http_failed() { [[ "$ABADDON_HTTP_STATUS" != "$ABADDON_HTTP_SUCCESS" ]]; }

# ============================================================================
# Statistics and Information
# ============================================================================

# Get HTTP statistics
get_http_stats() {
    echo "HTTP Client Statistics:"
    echo "  Client: ${ABADDON_HTTP_CLIENT:-not detected}"
    echo "  Total Requests: $ABADDON_HTTP_REQUESTS"
    echo "  Cache Hits: $ABADDON_HTTP_CACHE_HITS"
    echo "  Network Errors: $ABADDON_HTTP_NETWORK_ERRORS"
    
    if [[ $ABADDON_HTTP_REQUESTS -gt 0 ]]; then
        local cache_rate=$((ABADDON_HTTP_CACHE_HITS * 100 / ABADDON_HTTP_REQUESTS))
        local error_rate=$((ABADDON_HTTP_NETWORK_ERRORS * 100 / ABADDON_HTTP_REQUESTS))
        echo "  Cache Hit Rate: ${cache_rate}%"
        echo "  Error Rate: ${error_rate}%"
    fi
}

# Module validation
http_validate() {
    local errors=0
    
    # Check core functions exist
    for func in http_get http_post http_put http_delete http_parse_response; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    for var in ABADDON_HTTP_STATUS ABADDON_HTTP_RESPONSE_BODY ABADDON_HTTP_STATUS_CODE; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    # Check HTTP client availability
    if ! detect_http_client; then
        log_error "No HTTP client available"
        ((errors++))
    fi
    
    return $errors
}

# Module information
http_info() {
    echo "abaddon-http.sh - Generic HTTP Client"
    echo "Version: 1.0.0"
    echo "Client: ${ABADDON_HTTP_CLIENT:-not detected}"
    echo "Functions: http_get, http_post, http_put, http_delete, http_parse_response"
    echo "State: ABADDON_HTTP_STATUS, ABADDON_HTTP_RESPONSE_BODY, ABADDON_HTTP_STATUS_CODE"
    echo "Integration: cache.sh, validation.sh, kv.sh"
}

log_debug "abaddon-http.sh loaded successfully"