#!/usr/bin/env bash
# abaddon-command.sh - Command Registry System
# Version: 1.0.0
# Purpose: P3 orchestration primitives - command registry and execution

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_COMMAND_LOADED:-}" ]] && return 0
readonly ABADDON_COMMAND_LOADED=1

# Dependency checks - P3 Orchestration Primitive
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-command.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] || {
    echo "ERROR: abaddon-command.sh requires abaddon-platform.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_CACHE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-command.sh requires abaddon-cache.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_SECURITY_LOADED:-}" ]] || {
    echo "ERROR: abaddon-command.sh requires abaddon-security.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_DATATYPES_LOADED:-}" ]] || {
    echo "ERROR: abaddon-command.sh requires abaddon-datatypes.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_KV_LOADED:-}" ]] || {
    echo "ERROR: abaddon-command.sh requires abaddon-kv.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_STATE_MACHINE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-command.sh requires abaddon-state-machine.sh to be loaded first" >&2
    return 1
}

# State variables - NO stdout pollution
declare -g ABADDON_COMMAND_STATUS=""
declare -g ABADDON_COMMAND_ERROR=""
declare -g ABADDON_COMMAND_COMMAND=""
declare -g ABADDON_COMMAND_HANDLER=""
declare -g ABADDON_COMMAND_EXECUTION_TIME=""

# Command registry storage
declare -g ABADDON_COMMAND_REGISTRY_INITIALIZED="false"
declare -Ag ABADDON_COMMAND_HANDLERS
declare -Ag ABADDON_COMMAND_DESCRIPTIONS  
declare -Ag ABADDON_COMMAND_PRIORITIES
declare -Ag ABADDON_COMMAND_INITIALIZATION_REQUIRED
declare -Ag ABADDON_COMMAND_ALIASES

# Configuration
declare -g ABADDON_COMMAND_DEFAULT_PRIORITY=50
declare -g ABADDON_COMMAND_STRICT_VALIDATION="true"
declare -g ABADDON_COMMAND_ENFORCE_BOUNDARIES="true"
declare -g ABADDON_COMMAND_APPLICATION_CONTEXT=""

# Runtime state tracking
declare -g ABADDON_COMMAND_INITIALIZATION_PHASE="true"
declare -g ABADDON_COMMAND_EXECUTION_PHASE="false"

# Statistics
declare -g ABADDON_COMMAND_TOTAL_REGISTERED=0
declare -g ABADDON_COMMAND_TOTAL_EXECUTED=0
declare -g ABADDON_COMMAND_TOTAL_ERRORS=0

# ============================================================================
# Core Registry Management
# ============================================================================

# Initialize command registry for application context
commands_init() {
    local app_context="${1:-}"
    
    if [[ -z "$app_context" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="commands_init requires application context"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    log_debug "Initializing command registry for context: $app_context"
    
    ABADDON_COMMAND_APPLICATION_CONTEXT="$app_context"
    ABADDON_COMMAND_REGISTRY_INITIALIZED="true"
    ABADDON_COMMAND_INITIALIZATION_PHASE="true"
    ABADDON_COMMAND_EXECUTION_PHASE="false"
    
    # Clear any existing state
    reset_commands_state
    
    ABADDON_COMMAND_STATUS="initialized"
    log_info "Command registry initialized for application: $app_context"
    return 0
}

# Register a command with the system
register_command() {
    local command_name="$1"
    local description="$2" 
    local handler_function="$3"
    local priority="${4:-$ABADDON_COMMAND_DEFAULT_PRIORITY}"
    local requires_init="${5:-false}"
    
    # Clear previous state
    reset_commands_state
    
    # Input validation
    if [[ -z "$command_name" || -z "$description" || -z "$handler_function" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="register_command requires: command_name, description, handler_function"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Check registry initialization
    if [[ "$ABADDON_COMMAND_REGISTRY_INITIALIZED" != "true" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="Command registry not initialized. Call commands_init first"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Runtime boundary enforcement
    if [[ "$ABADDON_COMMAND_ENFORCE_BOUNDARIES" == "true" && "$ABADDON_COMMAND_EXECUTION_PHASE" == "true" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="Cannot register commands during execution phase"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Validate handler function exists
    if [[ "$ABADDON_COMMAND_STRICT_VALIDATION" == "true" ]]; then
        if ! declare -F "$handler_function" >/dev/null; then
            ABADDON_COMMAND_STATUS="error"
            ABADDON_COMMAND_ERROR="Handler function not found: $handler_function"
            log_error "$ABADDON_COMMAND_ERROR"
            return 1
        fi
    fi
    
    # Check for duplicates
    if [[ -n "${ABADDON_COMMAND_HANDLERS[$command_name]:-}" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="Command already registered: $command_name"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Validate priority
    if ! [[ "$priority" =~ ^[0-9]+$ ]] || [[ "$priority" -lt 0 ]] || [[ "$priority" -gt 100 ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="Priority must be between 0-100: $priority"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Register the command
    ABADDON_COMMAND_HANDLERS[$command_name]="$handler_function"
    ABADDON_COMMAND_DESCRIPTIONS[$command_name]="$description"
    ABADDON_COMMAND_PRIORITIES[$command_name]="$priority"
    ABADDON_COMMAND_INITIALIZATION_REQUIRED[$command_name]="$requires_init"
    
    ((ABADDON_COMMAND_TOTAL_REGISTERED++))
    
    ABADDON_COMMAND_STATUS="registered"
    ABADDON_COMMAND_COMMAND="$command_name"
    ABADDON_COMMAND_HANDLER="$handler_function"
    
    log_debug "Registered command: $command_name (handler: $handler_function, priority: $priority)"
    return 0
}

# Register command alias
register_command_alias() {
    local alias_name="$1"
    local target_command="$2"
    
    reset_commands_state
    
    if [[ -z "$alias_name" || -z "$target_command" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="register_command_alias requires: alias_name, target_command"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Check target exists
    if [[ -z "${ABADDON_COMMAND_HANDLERS[$target_command]:-}" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="Target command not found: $target_command"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Check for alias conflicts
    if [[ -n "${ABADDON_COMMAND_HANDLERS[$alias_name]:-}" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="Alias conflicts with existing command: $alias_name"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    ABADDON_COMMAND_ALIASES[$alias_name]="$target_command"
    ABADDON_COMMAND_STATUS="alias_registered"
    log_debug "Registered alias: $alias_name -> $target_command"
    return 0
}

# ============================================================================
# Command Execution
# ============================================================================

# Execute a command with validation and timing
execute_command() {
    local command_name="$1"
    shift
    local command_args=("$@")
    
    reset_commands_state
    
    if [[ -z "$command_name" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="execute_command requires command name"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Check registry initialization
    if [[ "$ABADDON_COMMAND_REGISTRY_INITIALIZED" != "true" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="Command registry not initialized"
        log_error "$ABADDON_COMMAND_ERROR"
        return 1
    fi
    
    # Transition to execution phase
    ABADDON_COMMAND_INITIALIZATION_PHASE="false"
    ABADDON_COMMAND_EXECUTION_PHASE="true"
    
    # Resolve aliases
    local resolved_command="$command_name"
    if [[ -n "${ABADDON_COMMAND_ALIASES[$command_name]:-}" ]]; then
        resolved_command="${ABADDON_COMMAND_ALIASES[$command_name]}"
        log_debug "Resolved alias: $command_name -> $resolved_command"
    fi
    
    # Check command exists
    local handler="${ABADDON_COMMAND_HANDLERS[$resolved_command]:-}"
    if [[ -z "$handler" ]]; then
        ABADDON_COMMAND_STATUS="not_found"
        ABADDON_COMMAND_ERROR="Command not found: $command_name"
        log_error "$ABADDON_COMMAND_ERROR"
        ((ABADDON_COMMAND_TOTAL_ERRORS++))
        return 1
    fi
    
    # Check initialization requirements
    local requires_init="${ABADDON_COMMAND_INITIALIZATION_REQUIRED[$resolved_command]:-false}"
    if [[ "$requires_init" == "true" && "$ABADDON_COMMAND_INITIALIZATION_PHASE" == "false" ]]; then
        log_warning "Command $resolved_command requires initialization context"
    fi
    
    # Execute with timing
    local start_time
    start_time=$(date +%s%N)
    
    ABADDON_COMMAND_COMMAND="$resolved_command"
    ABADDON_COMMAND_HANDLER="$handler"
    ABADDON_COMMAND_STATUS="executing"
    
    log_debug "Executing command: $resolved_command (handler: $handler)"
    
    # Execute the handler function
    local exit_code=0
    if "$handler" "${command_args[@]}"; then
        ABADDON_COMMAND_STATUS="success"
        ((ABADDON_COMMAND_TOTAL_EXECUTED++))
    else
        exit_code=$?
        ABADDON_COMMAND_STATUS="execution_error"
        ABADDON_COMMAND_ERROR="Command execution failed with exit code: $exit_code"
        log_error "$ABADDON_COMMAND_ERROR"
        ((ABADDON_COMMAND_TOTAL_ERRORS++))
    fi
    
    # Calculate execution time
    local end_time
    end_time=$(date +%s%N)
    local execution_time=$(( (end_time - start_time) / 1000000 ))
    ABADDON_COMMAND_EXECUTION_TIME="${execution_time}ms"
    
    log_debug "Command $resolved_command completed in $ABADDON_COMMAND_EXECUTION_TIME"
    
    return $exit_code
}

# Check if command exists
command_exists() {
    local command_name="$1"
    
    if [[ -z "$command_name" ]]; then
        return 1
    fi
    
    # Check direct command
    if [[ -n "${ABADDON_COMMAND_HANDLERS[$command_name]:-}" ]]; then
        return 0
    fi
    
    # Check aliases
    if [[ -n "${ABADDON_COMMAND_ALIASES[$command_name]:-}" ]]; then
        return 0
    fi
    
    return 1
}

# ============================================================================ 
# Registry Query Functions
# ============================================================================

# List all registered commands
list_commands() {
    if [[ "$ABADDON_COMMAND_REGISTRY_INITIALIZED" != "true" ]]; then
        log_error "Command registry not initialized"
        return 1
    fi
    
    local commands=()
    for cmd in "${!ABADDON_COMMAND_HANDLERS[@]}"; do
        commands+=("$cmd")
    done
    
    # Sort by priority and name
    IFS=$'\n' commands=($(sort <<<"${commands[*]}"))
    unset IFS
    
    printf '%s\n' "${commands[@]}"
}

# List commands with details
list_commands_detailed() {
    local format="${1:-table}"
    
    if [[ "$ABADDON_COMMAND_REGISTRY_INITIALIZED" != "true" ]]; then
        log_error "Command registry not initialized"
        return 1
    fi
    
    case "$format" in
        table)
            printf "%-15s %-10s %-50s %-20s\n" "COMMAND" "PRIORITY" "DESCRIPTION" "HANDLER"
            printf "%-15s %-10s %-50s %-20s\n" "-------" "--------" "-----------" "-------"
            
            for cmd in $(list_commands); do
                local priority="${ABADDON_COMMAND_PRIORITIES[$cmd]:-}"
                local description="${ABADDON_COMMAND_DESCRIPTIONS[$cmd]:-}"
                local handler="${ABADDON_COMMAND_HANDLERS[$cmd]:-}"
                
                printf "%-15s %-10s %-50s %-20s\n" "$cmd" "$priority" "${description:0:47}..." "$handler"
            done
            ;;
        json)
            echo "{"
            local first=true
            for cmd in $(list_commands); do
                [[ "$first" == "true" ]] && first=false || echo ","
                echo -n "  \"$cmd\": {"
                echo -n "\"priority\": ${ABADDON_COMMAND_PRIORITIES[$cmd]:-},"
                echo -n "\"description\": \"${ABADDON_COMMAND_DESCRIPTIONS[$cmd]:-}\","
                echo -n "\"handler\": \"${ABADDON_COMMAND_HANDLERS[$cmd]:-}\","
                echo -n "\"requires_init\": \"${ABADDON_COMMAND_INITIALIZATION_REQUIRED[$cmd]:-}\""
                echo -n "  }"
            done
            echo ""
            echo "}"
            ;;
        *)
            log_error "Unknown format: $format"
            return 1
            ;;
    esac
}

# Get command info
get_command_info() {
    local command_name="$1"
    local field="${2:-all}"
    
    reset_commands_state
    
    if [[ -z "$command_name" ]]; then
        ABADDON_COMMAND_STATUS="error"
        ABADDON_COMMAND_ERROR="get_command_info requires command name"
        return 1
    fi
    
    # Resolve aliases
    local resolved_command="$command_name"
    if [[ -n "${ABADDON_COMMAND_ALIASES[$command_name]:-}" ]]; then
        resolved_command="${ABADDON_COMMAND_ALIASES[$command_name]}"
    fi
    
    if [[ -z "${ABADDON_COMMAND_HANDLERS[$resolved_command]:-}" ]]; then
        ABADDON_COMMAND_STATUS="not_found"
        ABADDON_COMMAND_ERROR="Command not found: $command_name"
        return 1
    fi
    
    case "$field" in
        description)
            echo "${ABADDON_COMMAND_DESCRIPTIONS[$resolved_command]:-}"
            ;;
        handler)
            echo "${ABADDON_COMMAND_HANDLERS[$resolved_command]:-}"
            ;;
        priority)
            echo "${ABADDON_COMMAND_PRIORITIES[$resolved_command]:-}"
            ;;
        requires_init)
            echo "${ABADDON_COMMAND_INITIALIZATION_REQUIRED[$resolved_command]:-}"
            ;;
        all)
            echo "Command: $resolved_command"
            echo "Description: ${ABADDON_COMMAND_DESCRIPTIONS[$resolved_command]:-}"
            echo "Handler: ${ABADDON_COMMAND_HANDLERS[$resolved_command]:-}"
            echo "Priority: ${ABADDON_COMMAND_PRIORITIES[$resolved_command]:-}"
            echo "Requires Init: ${ABADDON_COMMAND_INITIALIZATION_REQUIRED[$resolved_command]:-}"
            ;;
        *)
            ABADDON_COMMAND_STATUS="error"
            ABADDON_COMMAND_ERROR="Unknown field: $field"
            return 1
            ;;
    esac
    
    ABADDON_COMMAND_STATUS="success"
    return 0
}

# ============================================================================
# State Management and Utilities
# ============================================================================

# Reset command state
reset_commands_state() {
    ABADDON_COMMAND_STATUS=""
    ABADDON_COMMAND_ERROR=""
    ABADDON_COMMAND_COMMAND=""
    ABADDON_COMMAND_HANDLER=""
    ABADDON_COMMAND_EXECUTION_TIME=""
}

# Set command error state
set_commands_error() {
    local error_message="$1"
    ABADDON_COMMAND_STATUS="error"
    ABADDON_COMMAND_ERROR="$error_message"
    log_error "Commands Error: $error_message"
}

# Set command success state
set_commands_success() {
    local value="${1:-}"
    ABADDON_COMMAND_STATUS="success"
    ABADDON_COMMAND_ERROR=""
    if [[ -n "$value" ]]; then
        ABADDON_COMMAND_COMMAND="$value"
    fi
    log_debug "Commands Success: operation completed"
}

# State accessor functions
get_commands_status() {
    echo "${ABADDON_COMMAND_STATUS:-}"
}

get_commands_error() {
    echo "${ABADDON_COMMAND_ERROR:-}"
}

get_commands_last_command() {
    echo "${ABADDON_COMMAND_COMMAND:-}"
}

get_commands_last_handler() {
    echo "${ABADDON_COMMAND_HANDLER:-}"
}

get_commands_execution_time() {
    echo "${ABADDON_COMMAND_EXECUTION_TIME:-}"
}

# Get registry statistics
get_commands_stats() {
    if [[ "$ABADDON_COMMAND_REGISTRY_INITIALIZED" != "true" ]]; then
        echo "Commands Registry: Not initialized"
        return 1
    fi
    
    local total_commands=0
    local total_aliases=0
    
    # Safe way to count array elements
    for key in "${!ABADDON_COMMAND_HANDLERS[@]}"; do
        ((total_commands++))
    done 2>/dev/null || total_commands=0
    
    for key in "${!ABADDON_COMMAND_ALIASES[@]}"; do
        ((total_aliases++))
    done 2>/dev/null || total_aliases=0
    
    echo "Commands Registry Statistics:"
    echo "  Application Context: ${ABADDON_COMMAND_APPLICATION_CONTEXT:-none}"
    echo "  Total Commands: $total_commands"
    echo "  Total Aliases: $total_aliases" 
    echo "  Total Registered: $ABADDON_COMMAND_TOTAL_REGISTERED"
    echo "  Total Executed: $ABADDON_COMMAND_TOTAL_EXECUTED"
    echo "  Total Errors: $ABADDON_COMMAND_TOTAL_ERRORS"
    echo "  Initialization Phase: $ABADDON_COMMAND_INITIALIZATION_PHASE"
    echo "  Execution Phase: $ABADDON_COMMAND_EXECUTION_PHASE"
    
    if [[ $ABADDON_COMMAND_TOTAL_EXECUTED -gt 0 ]]; then
        local success_rate=$(( (ABADDON_COMMAND_TOTAL_EXECUTED - ABADDON_COMMAND_TOTAL_ERRORS) * 100 / ABADDON_COMMAND_TOTAL_EXECUTED ))
        echo "  Success Rate: ${success_rate}%"
    fi
}

# ============================================================================
# Integration and Validation
# ============================================================================


# Validate commands registry
commands_validate() {
    local errors=0
    
    # Check core functions exist
    for func in commands_init register_command execute_command list_commands; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    for var in ABADDON_COMMAND_STATUS ABADDON_COMMAND_HANDLERS ABADDON_COMMAND_DESCRIPTIONS; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    
    return $errors
}

# Module information
commands_info() {
    echo "abaddon-command.sh - Command Registry System"
    echo "Version: 1.0.0"
    echo "Functions: commands_init, register_command, execute_command, list_commands"
    echo "State: ABADDON_COMMAND_STATUS, ABADDON_COMMAND_HANDLERS, ABADDON_COMMAND_DESCRIPTIONS"
    echo "Context: ${ABADDON_COMMAND_APPLICATION_CONTEXT:-none}"
    echo "Registry: ${ABADDON_COMMAND_REGISTRY_INITIALIZED:-false}"
}

log_debug "abaddon-command.sh loaded successfully"