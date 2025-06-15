#!/usr/bin/env bash
# Abaddon Cache - Performance optimization and execution primitives
# Version: 1.0.0
# Purpose: Caching layer for expensive operations and execution optimization

set -u # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_CACHE_LOADED:-}" ]] && return 0
readonly ABADDON_CACHE_LOADED=1

# Dependency check
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-cache.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

# Cache configuration
declare -g ABADDON_CACHE_DIR="${ABADDON_CACHE_DIR:-$HOME/.cache/abaddon}"
declare -g ABADDON_CACHE_TTL="${ABADDON_CACHE_TTL:-3600}"          # 1 hour default TTL
declare -g ABADDON_CACHE_MAX_SIZE="${ABADDON_CACHE_MAX_SIZE:-100}" # Max cache entries
declare -g ABADDON_CACHE_ENABLED="${ABADDON_CACHE_ENABLED:-true}"

# Cache state tracking
declare -A ABADDON_CACHE_MEMORY_STORE
declare -A ABADDON_CACHE_TIMESTAMPS
declare -g ABADDON_CACHE_HIT_COUNT=0
declare -g ABADDON_CACHE_MISS_COUNT=0
declare -g ABADDON_CACHE_OPERATIONS=0

# Performance tracking
declare -g ABADDON_CACHE_PERF_LOG_ENABLED="${ABADDON_CACHE_PERF_LOG_ENABLED:-false}"
declare -g ABADDON_CACHE_PERF_LOG_FILE="${ABADDON_CACHE_DIR}/performance.log"

# Cache module state variables (following framework pattern)
declare -g ABADDON_CACHE_STATUS=""
declare -g ABADDON_CACHE_ERROR_MESSAGE=""

# Cache module constants
readonly ABADDON_CACHE_SUCCESS="success"
readonly ABADDON_CACHE_ERROR="error"

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all Abaddon modules)
# ============================================================================

# Clear all cache module state variables
clear_cache_state() {
    ABADDON_CACHE_STATUS=""
    ABADDON_CACHE_ERROR_MESSAGE=""
    ABADDON_CACHE_HIT_COUNT=0
    ABADDON_CACHE_MISS_COUNT=0
    ABADDON_CACHE_OPERATIONS=0
    
    # Clear memory store
    ABADDON_CACHE_MEMORY_STORE=()
    ABADDON_CACHE_TIMESTAMPS=()
    
    log_debug "Cache module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_cache_status() {
    if [[ "$ABADDON_CACHE_STATUS" == "$ABADDON_CACHE_SUCCESS" ]]; then
        echo "ready"
    elif [[ "$ABADDON_CACHE_STATUS" == "$ABADDON_CACHE_ERROR" ]]; then
        echo "error"
    elif [[ "$ABADDON_CACHE_ENABLED" == "true" && -d "$ABADDON_CACHE_DIR" ]]; then
        echo "ready"
    elif [[ "$ABADDON_CACHE_ENABLED" == "false" ]]; then
        echo "ready"  # Disabled cache is still ready (just no-op)
    else
        echo "incomplete"
    fi
}

# Export cache state for cross-module access
export_cache_state() {
    echo "ABADDON_CACHE_STATUS='$ABADDON_CACHE_STATUS'"
    echo "ABADDON_CACHE_ERROR_MESSAGE='$ABADDON_CACHE_ERROR_MESSAGE'"
    echo "ABADDON_CACHE_ENABLED='$ABADDON_CACHE_ENABLED'"
    echo "ABADDON_CACHE_HIT_COUNT='$ABADDON_CACHE_HIT_COUNT'"
    echo "ABADDON_CACHE_MISS_COUNT='$ABADDON_CACHE_MISS_COUNT'"
    echo "ABADDON_CACHE_OPERATIONS='$ABADDON_CACHE_OPERATIONS'"
}

# Validate cache module state consistency
validate_cache_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "init_cache" "cache_key" "is_cache_valid" "cache_store" "cache_get"
        "clear_cache_state" "get_cache_status" "export_cache_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_CACHE_STATUS" "ABADDON_CACHE_ERROR_MESSAGE" "ABADDON_CACHE_ENABLED"
        "ABADDON_CACHE_HIT_COUNT" "ABADDON_CACHE_MISS_COUNT" "ABADDON_CACHE_OPERATIONS"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            validation_messages+=("Missing state variable: $var")
            ((errors++))
        fi
    done
    
    # Check core dependency is loaded
    if [[ -z "${ABADDON_CORE_LOADED:-}" ]]; then
        validation_messages+=("Required dependency not loaded: abaddon-core.sh")
        ((errors++))
    fi
    
    # Check cache directory if enabled
    if [[ "$ABADDON_CACHE_ENABLED" == "true" && ! -d "$ABADDON_CACHE_DIR" ]]; then
        validation_messages+=("Cache enabled but directory missing: $ABADDON_CACHE_DIR")
        ((errors++))
    fi
    
    # Output validation results
    if [[ $errors -eq 0 ]]; then
        log_debug "Cache module validation: PASSED"
        return 0
    else
        log_error "Cache module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# Set cache error state
set_cache_error() {
    local error_message="$1"
    ABADDON_CACHE_STATUS="$ABADDON_CACHE_ERROR"
    ABADDON_CACHE_ERROR_MESSAGE="$error_message"
    log_error "Cache error: $error_message"
}

# Set cache success state
set_cache_success() {
    ABADDON_CACHE_STATUS="$ABADDON_CACHE_SUCCESS"
    ABADDON_CACHE_ERROR_MESSAGE=""
}

# ============================================================================
# Cache Initialization
# ============================================================================

# Initialize cache system
init_cache() {
    clear_cache_state
    log_debug "Initializing cache system"

    # Create cache directory if it doesn't exist
    if [[ ! -d "$ABADDON_CACHE_DIR" ]]; then
        if ! mkdir -p "$ABADDON_CACHE_DIR" 2>/dev/null; then
            log_warn "Cannot create cache directory: $ABADDON_CACHE_DIR"
            ABADDON_CACHE_ENABLED="false"
            set_cache_error "Cannot create cache directory: $ABADDON_CACHE_DIR"
            return 1
        fi
        log_debug "Created cache directory: $ABADDON_CACHE_DIR"
    fi

    # Initialize performance logging
    if [[ "$ABADDON_CACHE_PERF_LOG_ENABLED" == "true" ]]; then
        echo "# Abaddon Cache Performance Log - $(date)" >>"$ABADDON_CACHE_PERF_LOG_FILE"
    fi

    set_cache_success
    log_debug "Cache system initialized (enabled: $ABADDON_CACHE_ENABLED)"
    return 0
}

# ============================================================================
# Cache State Management
# ============================================================================

# Reset cache state (tracking variables)
reset_cache_state() {
    ABADDON_CACHE_HIT_COUNT=0
    ABADDON_CACHE_MISS_COUNT=0
    ABADDON_CACHE_OPERATIONS=0
    log_debug "Cache state reset"
}

# Set cache error state with logging
set_cache_error() {
    local error_message="$1"
    log_error "Cache Error: $error_message"
    # Cache doesn't maintain persistent error state like other modules
    # Errors are logged and handled immediately
}

# Set cache success state
set_cache_success() {
    local operation="${1:-cache_operation}"
    log_debug "Cache Success: $operation completed"
    # Cache success is tracked through hit/miss counters
    # No persistent success state needed
}

# ============================================================================
# Core Cache Operations
# ============================================================================

# Generate cache key from input
generate_cache_key() {
    local operation="$1"
    shift
    local params="$*"

    # Create deterministic key from operation and parameters
    local key_input="${operation}:${params}"

    # Sanitize operation name for key prefix
    local safe_operation=$(echo "$operation" | tr '/' '_' | tr ' ' '-')

    # Use hash if available, otherwise use simple encoding
    if command -v shasum >/dev/null 2>&1; then
        echo "${safe_operation}_$(echo "$key_input" | shasum -a 256 | cut -d' ' -f1 | head -c 16)"
    else
        # Fallback: simple character replacement
        echo "${safe_operation}_$(echo "$key_input" | tr '/' '_' | tr ' ' '-' | head -c 32)"
    fi
}

# Check if cache entry is valid (not expired)
is_cache_valid() {
    local cache_key="$1"
    local current_time=$(date +%s)

    # Check if we have timestamp for this key
    if [[ -z "${ABADDON_CACHE_TIMESTAMPS[$cache_key]:-}" ]]; then
        return 1
    fi

    local cache_time="${ABADDON_CACHE_TIMESTAMPS[$cache_key]}"
    local age=$((current_time - cache_time))

    # Check if cache entry is within TTL
    if ((age <= ABADDON_CACHE_TTL)); then
        return 0
    else
        log_debug "Cache entry expired: $cache_key (age: ${age}s, TTL: ${ABADDON_CACHE_TTL}s)"
        return 1
    fi
}

# Store value in cache (both memory and disk)
cache_store() {
    local cache_key="$1"
    local value="$2"

    if [[ "$ABADDON_CACHE_ENABLED" != "true" ]]; then
        return 0
    fi

    # Store in memory cache
    ABADDON_CACHE_MEMORY_STORE["$cache_key"]="$value"
    ABADDON_CACHE_TIMESTAMPS["$cache_key"]=$(date +%s)

    # Store on disk for persistence
    local cache_file="$ABADDON_CACHE_DIR/$cache_key"
    if ! echo "$value" >"$cache_file" 2>/dev/null; then
        log_debug "Failed to write cache file: $cache_file"
    fi

    # Enforce cache size limits
    cleanup_cache_if_needed

    log_debug "Cached value for key: $cache_key"
}

# Retrieve value from cache
cache_get() {
    local cache_key="$1"

    if [[ "$ABADDON_CACHE_ENABLED" != "true" ]]; then
        return 1
    fi

    ABADDON_CACHE_OPERATIONS=$((ABADDON_CACHE_OPERATIONS + 1))

    # Check memory cache first
    if [[ -n "${ABADDON_CACHE_MEMORY_STORE[$cache_key]:-}" ]] && is_cache_valid "$cache_key"; then
        echo "${ABADDON_CACHE_MEMORY_STORE[$cache_key]}"
        ABADDON_CACHE_HIT_COUNT=$((ABADDON_CACHE_HIT_COUNT + 1))
        log_debug "Cache hit (memory): $cache_key"
        return 0
    fi

    # Check disk cache
    local cache_file="$ABADDON_CACHE_DIR/$cache_key"
    if [[ -f "$cache_file" ]] && is_cache_valid "$cache_key"; then
        local cached_value
        if cached_value=$(cat "$cache_file" 2>/dev/null); then
            # Restore to memory cache
            ABADDON_CACHE_MEMORY_STORE["$cache_key"]="$cached_value"
            echo "$cached_value"
            ABADDON_CACHE_HIT_COUNT=$((ABADDON_CACHE_HIT_COUNT + 1))
            log_debug "Cache hit (disk): $cache_key"
            return 0
        fi
    fi

    # Cache miss
    ABADDON_CACHE_MISS_COUNT=$((ABADDON_CACHE_MISS_COUNT + 1))
    log_debug "Cache miss: $cache_key"
    return 1
}

# Remove cache entry
cache_invalidate() {
    local cache_key="$1"

    # Remove from memory
    unset ABADDON_CACHE_MEMORY_STORE["$cache_key"]
    unset ABADDON_CACHE_TIMESTAMPS["$cache_key"]

    # Remove from disk
    local cache_file="$ABADDON_CACHE_DIR/$cache_key"
    rm -f "$cache_file" 2>/dev/null

    log_debug "Cache invalidated: $cache_key"
}

# Clear all cache entries
cache_clear() {
    log_debug "Clearing all cache entries"

    # Clear memory cache
    ABADDON_CACHE_MEMORY_STORE=()
    ABADDON_CACHE_TIMESTAMPS=()

    # Clear disk cache
    if [[ -d "$ABADDON_CACHE_DIR" ]]; then
        find "$ABADDON_CACHE_DIR" -name "*" -type f -not -name "performance.log" -delete 2>/dev/null
    fi

    # Reset statistics
    ABADDON_CACHE_HIT_COUNT=0
    ABADDON_CACHE_MISS_COUNT=0
    ABADDON_CACHE_OPERATIONS=0

    log_debug "Cache cleared"
}

# ============================================================================
# Cache Maintenance
# ============================================================================

# Cleanup cache if it exceeds size limits
cleanup_cache_if_needed() {
    local current_size=${#ABADDON_CACHE_MEMORY_STORE[@]}

    if ((current_size > ABADDON_CACHE_MAX_SIZE)); then
        log_debug "Cache size limit exceeded ($current_size > $ABADDON_CACHE_MAX_SIZE), cleaning up"

        # Remove oldest entries (simple LRU approximation)
        local removed_count=0
        local excess=$((current_size - ABADDON_CACHE_MAX_SIZE))
        local breathing_room=$((ABADDON_CACHE_MAX_SIZE / 4)) # 25% of max size for breathing room
        local target_remove=$((excess + breathing_room))

        for cache_key in "${!ABADDON_CACHE_TIMESTAMPS[@]}"; do
            if ((removed_count >= target_remove)); then
                break
            fi

            cache_invalidate "$cache_key"
            removed_count=$((removed_count + 1))
        done

        log_debug "Removed $removed_count cache entries"
    fi
}

# Clean up expired cache entries
cleanup_expired_cache() {
    log_debug "Cleaning up expired cache entries"

    local current_time=$(date +%s)
    local expired_count=0

    for cache_key in "${!ABADDON_CACHE_TIMESTAMPS[@]}"; do
        local cache_time="${ABADDON_CACHE_TIMESTAMPS[$cache_key]}"
        local age=$((current_time - cache_time))

        if ((age > ABADDON_CACHE_TTL)); then
            cache_invalidate "$cache_key"
            expired_count=$((expired_count + 1))
        fi
    done

    log_debug "Cleaned up $expired_count expired cache entries"
}

# ============================================================================
# Cached Execution Primitives
# ============================================================================

# Execute command with caching
cached_execute() {
    local operation="$1"
    shift
    local command="$*"

    if [[ "$ABADDON_CACHE_ENABLED" != "true" ]]; then
        # No caching, execute directly
        eval "$command"
        return $?
    fi

    local cache_key
    cache_key=$(generate_cache_key "$operation" "$command")

    # Try to get from cache first
    local cached_result
    if cached_result=$(cache_get "$cache_key"); then
        echo "$cached_result"
        return 0
    fi

    # Execute command and cache result
    local start_time=$(date +%s%N)
    local result
    local exit_code

    if result=$(eval "$command" 2>&1); then
        exit_code=0
        cache_store "$cache_key" "$result"
        echo "$result"
    else
        exit_code=$?
        log_debug "Command failed, not caching: $command"
    fi

    # Log performance if enabled
    if [[ "$ABADDON_CACHE_PERF_LOG_ENABLED" == "true" ]]; then
        local duration=$(($(date +%s%N) - start_time))
        echo "$(date '+%Y-%m-%d %H:%M:%S'):$operation:$duration:$exit_code:$cache_key" >>"$ABADDON_CACHE_PERF_LOG_FILE"
    fi

    return $exit_code
}

# Execute file parsing with caching
cached_file_parse() {
    local file_path="$1"
    local parser_command="$2"
    local query="$3"

    # Generate cache key based on file path, modification time, and query
    local file_mtime=""
    if [[ -f "$file_path" ]]; then
        if command -v stat >/dev/null 2>&1; then
            # Try to get file modification time for cache invalidation
            file_mtime=$(stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path" 2>/dev/null || echo "0")
        fi
    fi

    local cache_key
    cache_key=$(generate_cache_key "file_parse" "$file_path:$file_mtime:$parser_command:$query")

    # Try cache first
    if cache_get "$cache_key" >/dev/null 2>&1; then
        # Cache hit - get the value without subshell
        cache_get "$cache_key"
        return 0
    fi

    # Execute parsing command
    local result
    local exit_code

    if result=$(eval "$parser_command \"$file_path\"" 2>&1); then
        exit_code=0
        cache_store "$cache_key" "$result"
        echo "$result"
    else
        exit_code=$?
        log_debug "File parsing failed, not caching: $file_path"
    fi

    return $exit_code
}

# ============================================================================
# Performance Measurement
# ============================================================================

# Measure execution time of a function
measure_execution() {
    local operation_name="$1"
    shift
    local function_to_run="$*"

    local start_time=$(date +%s%N)
    local exit_code

    # Execute the function
    if eval "$function_to_run"; then
        exit_code=0
    else
        exit_code=$?
    fi

    local end_time=$(date +%s%N)
    local duration=$((end_time - start_time))
    local duration_ms=$((duration / 1000000))

    # Log performance data
    log_debug "Operation '$operation_name' took ${duration_ms}ms (exit: $exit_code)"

    if [[ "$ABADDON_CACHE_PERF_LOG_ENABLED" == "true" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'):measure:$operation_name:$duration:$exit_code" >>"$ABADDON_CACHE_PERF_LOG_FILE"
    fi

    return $exit_code
}

# Batch multiple operations for performance
batch_operations() {
    local operation_name="$1"
    shift
    local operations=("$@")

    log_debug "Batching ${#operations[@]} operations for: $operation_name"

    local start_time=$(date +%s%N)
    local success_count=0
    local total_count=${#operations[@]}

    for operation in "${operations[@]}"; do
        if eval "$operation" >/dev/null 2>&1; then
            success_count=$((success_count + 1))
        fi
    done

    local end_time=$(date +%s%N)
    local duration=$((end_time - start_time))
    local duration_ms=$((duration / 1000000))

    log_debug "Batch '$operation_name': $success_count/$total_count succeeded in ${duration_ms}ms"

    if [[ "$ABADDON_CACHE_PERF_LOG_ENABLED" == "true" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'):batch:$operation_name:$duration:$success_count/$total_count" >>"$ABADDON_CACHE_PERF_LOG_FILE"
    fi

    return $((total_count - success_count)) # Return failure count
}

# ============================================================================
# Cache Statistics and Information
# ============================================================================

# Get cache statistics
get_cache_stats() {
    local hit_rate=0
    if ((ABADDON_CACHE_OPERATIONS > 0)); then
        hit_rate=$((ABADDON_CACHE_HIT_COUNT * 100 / ABADDON_CACHE_OPERATIONS))
    fi

    echo "Cache Statistics:"
    echo "  Enabled: $ABADDON_CACHE_ENABLED"
    echo "  Operations: $ABADDON_CACHE_OPERATIONS"
    echo "  Hits: $ABADDON_CACHE_HIT_COUNT"
    echo "  Misses: $ABADDON_CACHE_MISS_COUNT"
    echo "  Hit Rate: ${hit_rate}%"
    local memory_count=0
    if [[ -v ABADDON_CACHE_MEMORY_STORE ]]; then
        set +u
        memory_count=${#ABADDON_CACHE_MEMORY_STORE[@]}
        set -u
    fi
    echo "  Memory Entries: $memory_count"
    echo "  TTL: ${ABADDON_CACHE_TTL}s"
    echo "  Max Size: $ABADDON_CACHE_MAX_SIZE"
    echo "  Cache Dir: $ABADDON_CACHE_DIR"
}

# Check cache system health
check_cache_health() {
    local health_status="healthy"
    local issues=()

    # Check cache directory
    if [[ ! -d "$ABADDON_CACHE_DIR" ]]; then
        health_status="unhealthy"
        issues+=("Cache directory missing: $ABADDON_CACHE_DIR")
    elif [[ ! -w "$ABADDON_CACHE_DIR" ]]; then
        health_status="unhealthy"
        issues+=("Cache directory not writable: $ABADDON_CACHE_DIR")
    fi

    # Check cache size
    local current_size=0
    if [[ -v ABADDON_CACHE_MEMORY_STORE ]]; then
        set +u
        current_size=${#ABADDON_CACHE_MEMORY_STORE[@]}
        set -u
    fi
    if ((current_size > ABADDON_CACHE_MAX_SIZE)); then
        health_status="warning"
        issues+=("Cache size exceeds limit: $current_size > $ABADDON_CACHE_MAX_SIZE")
    fi

    # Check hit rate
    local hit_rate=0
    if ((ABADDON_CACHE_OPERATIONS > 10)); then # Only check if we have meaningful data
        hit_rate=$((ABADDON_CACHE_HIT_COUNT * 100 / ABADDON_CACHE_OPERATIONS))
        if ((hit_rate < 20)); then
            health_status="warning"
            issues+=("Low cache hit rate: ${hit_rate}%")
        fi
    fi

    echo "Cache Health: $health_status"
    if [[ ${#issues[@]} -gt 0 ]]; then
        for issue in "${issues[@]}"; do
            echo "  Issue: $issue"
        done
    fi

    [[ "$health_status" == "healthy" ]]
}

# ============================================================================
# Module Validation and Information
# ============================================================================

# Validate cache module functionality
cache_validate() {
    local errors=0

    # Check required functions exist
    local required_functions=(
        "init_cache" "cache_store" "cache_get" "cache_clear"
        "reset_cache_state" "set_cache_error" "set_cache_success"
    )

    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done

    # Check state variables exist
    local required_vars=(
        "ABADDON_CACHE_HIT_COUNT" "ABADDON_CACHE_MISS_COUNT" "ABADDON_CACHE_OPERATIONS"
        "ABADDON_CACHE_DIR" "ABADDON_CACHE_TTL" "ABADDON_CACHE_ENABLED"
    )

    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing cache variable: $var"
            ((errors++))
        fi
    done

    # Check cache directory
    if [[ ! -d "$ABADDON_CACHE_DIR" ]]; then
        log_error "Cache directory not found: $ABADDON_CACHE_DIR"
        ((errors++))
    fi

    return $errors
}

# Module information
cache_info() {
    echo "Abaddon Cache - Performance optimization and execution primitives"
    echo "Version: 1.0.0"
    echo "Dependencies: core.sh"
    echo "Features: Memory + disk caching, TTL management, performance tracking"
    echo "Main Functions:"
    echo "  cache_store(key, value)"
    echo "  cache_get(key)"
    echo "  cached_execute(operation, command...)"
    echo "  cache_clear()"
}

# Initialize cache on module load
init_cache

log_debug "Abaddon cache module loaded"
