#!/usr/bin/env bash
# Abaddon State Machine - Generic runtime boundary management (P3)
# Version: 1.0.0
# Purpose: Stateful orchestration bridge between functional P1-P2 and object-like P4

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_STATE_MACHINE_LOADED:-}" ]] && return 0
readonly ABADDON_STATE_MACHINE_LOADED=1

# Dependency checks
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-state-machine.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] || {
    echo "ERROR: abaddon-state-machine.sh requires abaddon-platform.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_SECURITY_LOADED:-}" ]] || {
    echo "ERROR: abaddon-state-machine.sh requires abaddon-security.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_DATATYPES_LOADED:-}" ]] || {
    echo "ERROR: abaddon-state-machine.sh requires abaddon-datatypes.sh to be loaded first" >&2
    return 1
}

# ============================================================================
# Configuration and State Variables
# ============================================================================

# Configuration - environment configurable
declare -g ABADDON_STATE_MACHINE_STRICT_MODE="${ABADDON_STATE_MACHINE_STRICT_MODE:-true}"
declare -g ABADDON_STATE_MACHINE_DEFAULT_STATE="${ABADDON_STATE_MACHINE_DEFAULT_STATE:-uninitialized}"

# State variables - NO stdout pollution
declare -g ABADDON_STATE_MACHINE_CURRENT_STATE=""
declare -g ABADDON_STATE_MACHINE_PREVIOUS_STATE=""
declare -g ABADDON_STATE_MACHINE_TRANSITION_COUNT=0
declare -g ABADDON_STATE_MACHINE_ERROR_MESSAGE=""
declare -g ABADDON_STATE_MACHINE_STATUS=""
declare -g ABADDON_STATE_MACHINE_LAST_TRANSITION_TIME=""

# State machine result constants
readonly ABADDON_STATE_MACHINE_SUCCESS="success"
readonly ABADDON_STATE_MACHINE_ERROR="error"
readonly ABADDON_STATE_MACHINE_INVALID_TRANSITION="invalid_transition"
readonly ABADDON_STATE_MACHINE_BOUNDARY_VIOLATION="boundary_violation"

# State registries - associative arrays for state management
declare -A ABADDON_STATE_MACHINE_VALID_STATES=()
declare -A ABADDON_STATE_MACHINE_VALID_TRANSITIONS=()
declare -A ABADDON_STATE_MACHINE_STATE_VALIDATORS=()
declare -A ABADDON_STATE_MACHINE_BOUNDARY_ENFORCERS=()

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all Abaddon modules)
# ============================================================================

# Clear all state machine module state variables
clear_state_machine_state() {
    ABADDON_STATE_MACHINE_CURRENT_STATE=""
    ABADDON_STATE_MACHINE_PREVIOUS_STATE=""
    ABADDON_STATE_MACHINE_TRANSITION_COUNT=0
    ABADDON_STATE_MACHINE_ERROR_MESSAGE=""
    ABADDON_STATE_MACHINE_STATUS=""
    ABADDON_STATE_MACHINE_LAST_TRANSITION_TIME=""
    
    # Clear registries
    unset ABADDON_STATE_MACHINE_VALID_STATES 2>/dev/null || true
    unset ABADDON_STATE_MACHINE_VALID_TRANSITIONS 2>/dev/null || true
    unset ABADDON_STATE_MACHINE_STATE_VALIDATORS 2>/dev/null || true
    unset ABADDON_STATE_MACHINE_BOUNDARY_ENFORCERS 2>/dev/null || true
    
    declare -A ABADDON_STATE_MACHINE_VALID_STATES
    declare -A ABADDON_STATE_MACHINE_VALID_TRANSITIONS
    declare -A ABADDON_STATE_MACHINE_STATE_VALIDATORS
    declare -A ABADDON_STATE_MACHINE_BOUNDARY_ENFORCERS
    
    log_debug "State machine module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_state_machine_status() {
    if [[ "$ABADDON_STATE_MACHINE_STATUS" == "ready" ]]; then
        echo "ready"
    elif [[ "$ABADDON_STATE_MACHINE_STATUS" == "error" ]]; then
        echo "error"
    elif [[ -n "$ABADDON_STATE_MACHINE_CURRENT_STATE" ]]; then
        echo "ready"
    elif [[ -n "${ABADDON_CORE_LOADED:-}" && -n "${ABADDON_PLATFORM_LOADED:-}" && -n "${ABADDON_SECURITY_LOADED:-}" && -n "${ABADDON_DATATYPES_LOADED:-}" ]]; then
        echo "incomplete"
    else
        echo "unknown"
    fi
}

# Export state machine state for cross-module access
export_state_machine_state() {
    echo "ABADDON_STATE_MACHINE_STATUS='$ABADDON_STATE_MACHINE_STATUS'"
    echo "ABADDON_STATE_MACHINE_ERROR_MESSAGE='$ABADDON_STATE_MACHINE_ERROR_MESSAGE'"
    echo "ABADDON_STATE_MACHINE_CURRENT_STATE='$ABADDON_STATE_MACHINE_CURRENT_STATE'"
    echo "ABADDON_STATE_MACHINE_PREVIOUS_STATE='$ABADDON_STATE_MACHINE_PREVIOUS_STATE'"
    echo "ABADDON_STATE_MACHINE_TRANSITION_COUNT='$ABADDON_STATE_MACHINE_TRANSITION_COUNT'"
    echo "ABADDON_STATE_MACHINE_LAST_TRANSITION_TIME='$ABADDON_STATE_MACHINE_LAST_TRANSITION_TIME'"
    
    # Export registry contents
    local state
    for state in "${!ABADDON_STATE_MACHINE_VALID_STATES[@]}"; do
        echo "ABADDON_STATE_MACHINE_VALID_STATES['$state']='${ABADDON_STATE_MACHINE_VALID_STATES[$state]}'"
    done
}

# Validate state machine module state consistency
validate_state_machine_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "state_machine_init" "register_state" "register_transition" "transition_to_state"
        "require_state" "is_in_state" "clear_state_machine_state" "get_state_machine_status"
        "export_state_machine_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_STATE_MACHINE_STATUS" "ABADDON_STATE_MACHINE_ERROR_MESSAGE"
        "ABADDON_STATE_MACHINE_CURRENT_STATE" "ABADDON_STATE_MACHINE_TRANSITION_COUNT"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            validation_messages+=("Missing state variable: $var")
            ((errors++))
        fi
    done
    
    # Check dependencies are loaded
    local required_deps=(
        "ABADDON_CORE_LOADED" "ABADDON_PLATFORM_LOADED" "ABADDON_SECURITY_LOADED" "ABADDON_DATATYPES_LOADED"
    )
    
    for dep in "${required_deps[@]}"; do
        if [[ -z "${!dep:-}" ]]; then
            validation_messages+=("Required dependency not loaded: ${dep/_LOADED/}")
            ((errors++))
        fi
    done
    
    # Output validation results
    if [[ $errors -eq 0 ]]; then
        log_debug "State machine module validation: PASSED"
        return 0
    else
        log_error "State machine module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# ============================================================================
# Core State Machine Functions
# ============================================================================

# Initialize state machine with default state
state_machine_init() {
    local initial_state="${1:-$ABADDON_STATE_MACHINE_DEFAULT_STATE}"
    
    log_debug "Initializing state machine with initial state: $initial_state"
    
    # Register default states if none exist
    if [[ ${#ABADDON_STATE_MACHINE_VALID_STATES[@]} -eq 0 ]]; then
        register_state "uninitialized" "Default uninitialized state"
        register_state "initialized" "Default initialized state"
        register_state "error" "Error state"
        
        # Register basic transitions
        register_transition "uninitialized" "initialized"
        register_transition "uninitialized" "error"
        register_transition "initialized" "error"
    fi
    
    # Set initial state
    ABADDON_STATE_MACHINE_CURRENT_STATE="$initial_state"
    ABADDON_STATE_MACHINE_PREVIOUS_STATE=""
    ABADDON_STATE_MACHINE_TRANSITION_COUNT=0
    ABADDON_STATE_MACHINE_LAST_TRANSITION_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
    ABADDON_STATE_MACHINE_STATUS="ready"
    
    log_debug "State machine initialized (current state: $initial_state)"
    return 0
}

# Register a valid state with optional description
register_state() {
    local state_name="$1"
    local description="${2:-}"
    
    if [[ -z "$state_name" ]]; then
        log_error "State name is required for registration"
        return 1
    fi
    
    # Validate state name format using datatypes module
    if ! validate_identifier "$state_name" false; then
        log_error "Invalid state name format: $state_name ($(get_datatypes_error))"
        return 1
    fi
    
    ABADDON_STATE_MACHINE_VALID_STATES["$state_name"]="$description"
    log_debug "Registered state: $state_name ($description)"
    return 0
}

# Register a valid state transition
register_transition() {
    local from_state="$1"
    local to_state="$2"
    
    if [[ -z "$from_state" || -z "$to_state" ]]; then
        log_error "Both from_state and to_state are required for transition registration"
        return 1
    fi
    
    # Validate that states are registered
    if [[ -z "${ABADDON_STATE_MACHINE_VALID_STATES[$from_state]:-}" ]]; then
        log_error "Cannot register transition from unregistered state: $from_state"
        return 1
    fi
    
    if [[ -z "${ABADDON_STATE_MACHINE_VALID_STATES[$to_state]:-}" ]]; then
        log_error "Cannot register transition to unregistered state: $to_state"
        return 1
    fi
    
    local transition_key="${from_state}->${to_state}"
    ABADDON_STATE_MACHINE_VALID_TRANSITIONS["$transition_key"]="registered"
    log_debug "Registered transition: $from_state -> $to_state"
    return 0
}

# Register state validator function
register_state_validator() {
    local state="$1"
    local validator_function="$2"
    
    if [[ -z "$state" || -z "$validator_function" ]]; then
        log_error "State and validator function are required"
        return 1
    fi
    
    # Validate that state is registered
    if [[ -z "${ABADDON_STATE_MACHINE_VALID_STATES[$state]:-}" ]]; then
        log_error "Cannot register validator for unregistered state: $state"
        return 1
    fi
    
    # Validate that function exists
    if ! declare -F "$validator_function" >/dev/null 2>&1; then
        log_error "Validator function does not exist: $validator_function"
        return 1
    fi
    
    ABADDON_STATE_MACHINE_STATE_VALIDATORS["$state"]="$validator_function"
    log_debug "Registered state validator: $state -> $validator_function"
    return 0
}

# Register boundary enforcer function
register_boundary_enforcer() {
    local state="$1"
    local enforcer_function="$2"
    
    if [[ -z "$state" || -z "$enforcer_function" ]]; then
        log_error "State and enforcer function are required"
        return 1
    fi
    
    # Validate that state is registered
    if [[ -z "${ABADDON_STATE_MACHINE_VALID_STATES[$state]:-}" ]]; then
        log_error "Cannot register boundary enforcer for unregistered state: $state"
        return 1
    fi
    
    # Validate that function exists
    if ! declare -F "$enforcer_function" >/dev/null 2>&1; then
        log_error "Boundary enforcer function does not exist: $enforcer_function"
        return 1
    fi
    
    ABADDON_STATE_MACHINE_BOUNDARY_ENFORCERS["$state"]="$enforcer_function"
    log_debug "Registered boundary enforcer: $state -> $enforcer_function"
    return 0
}

# ============================================================================
# State Transition Functions
# ============================================================================

# Transition to a new state with validation
transition_to_state() {
    local new_state="$1"
    local force="${2:-false}"
    
    if [[ -z "$new_state" ]]; then
        set_state_machine_error "New state is required for transition"
        return 1
    fi
    
    # Check if state is registered
    if [[ -z "${ABADDON_STATE_MACHINE_VALID_STATES[$new_state]:-}" ]]; then
        set_state_machine_error "Cannot transition to unregistered state: $new_state"
        return 1
    fi
    
    # Check if already in target state
    if [[ "$ABADDON_STATE_MACHINE_CURRENT_STATE" == "$new_state" ]]; then
        log_debug "Already in state: $new_state"
        return 0
    fi
    
    # Validate transition (unless forced)
    if [[ "$force" != "true" && "$ABADDON_STATE_MACHINE_STRICT_MODE" == "true" ]]; then
        local transition_key="${ABADDON_STATE_MACHINE_CURRENT_STATE}->${new_state}"
        if [[ -z "${ABADDON_STATE_MACHINE_VALID_TRANSITIONS[$transition_key]:-}" ]]; then
            set_state_machine_error "Invalid transition: $ABADDON_STATE_MACHINE_CURRENT_STATE -> $new_state"
            return 1
        fi
    fi
    
    # Run state validator if registered
    local validator="${ABADDON_STATE_MACHINE_STATE_VALIDATORS[$new_state]:-}"
    if [[ -n "$validator" ]]; then
        if ! "$validator"; then
            set_state_machine_error "State validation failed for: $new_state"
            return 1
        fi
    fi
    
    # Perform transition
    ABADDON_STATE_MACHINE_PREVIOUS_STATE="$ABADDON_STATE_MACHINE_CURRENT_STATE"
    ABADDON_STATE_MACHINE_CURRENT_STATE="$new_state"
    ((ABADDON_STATE_MACHINE_TRANSITION_COUNT++))
    ABADDON_STATE_MACHINE_LAST_TRANSITION_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
    ABADDON_STATE_MACHINE_STATUS="$ABADDON_STATE_MACHINE_SUCCESS"
    
    log_debug "State transition: $ABADDON_STATE_MACHINE_PREVIOUS_STATE -> $new_state (count: $ABADDON_STATE_MACHINE_TRANSITION_COUNT)"
    return 0
}

# ============================================================================
# Boundary Enforcement Functions
# ============================================================================

# Require specific state for operation
require_state() {
    local required_state="$1"
    local operation_name="${2:-operation}"
    
    if [[ -z "$required_state" ]]; then
        set_state_machine_error "Required state must be specified"
        return 1
    fi
    
    if [[ "$ABADDON_STATE_MACHINE_CURRENT_STATE" != "$required_state" ]]; then
        set_state_machine_error "$operation_name requires state '$required_state' (current: $ABADDON_STATE_MACHINE_CURRENT_STATE)"
        return 1
    fi
    
    # Run boundary enforcer if registered
    local enforcer="${ABADDON_STATE_MACHINE_BOUNDARY_ENFORCERS[$required_state]:-}"
    if [[ -n "$enforcer" ]]; then
        if ! "$enforcer"; then
            set_state_machine_error "Boundary enforcement failed for state: $required_state"
            return 1
        fi
    fi
    
    return 0
}

# Require one of multiple states
require_any_state() {
    local operation_name="$1"
    shift
    local required_states=("$@")
    
    if [[ ${#required_states[@]} -eq 0 ]]; then
        set_state_machine_error "At least one required state must be specified"
        return 1
    fi
    
    for state in "${required_states[@]}"; do
        if [[ "$ABADDON_STATE_MACHINE_CURRENT_STATE" == "$state" ]]; then
            # Run boundary enforcer if registered
            local enforcer="${ABADDON_STATE_MACHINE_BOUNDARY_ENFORCERS[$state]:-}"
            if [[ -n "$enforcer" ]]; then
                if ! "$enforcer"; then
                    set_state_machine_error "Boundary enforcement failed for state: $state"
                    return 1
                fi
            fi
            return 0
        fi
    done
    
    local states_list
    states_list=$(printf "'%s' " "${required_states[@]}")
    set_state_machine_error "$operation_name requires one of: $states_list (current: $ABADDON_STATE_MACHINE_CURRENT_STATE)"
    return 1
}

# Check if in specific state
is_in_state() {
    local state="$1"
    [[ "$ABADDON_STATE_MACHINE_CURRENT_STATE" == "$state" ]]
}

# Check if in any of multiple states
is_in_any_state() {
    local states=("$@")
    
    for state in "${states[@]}"; do
        if [[ "$ABADDON_STATE_MACHINE_CURRENT_STATE" == "$state" ]]; then
            return 0
        fi
    done
    return 1
}

# ============================================================================
# State Access Functions
# ============================================================================

get_current_state() { echo "$ABADDON_STATE_MACHINE_CURRENT_STATE"; }
get_previous_state() { echo "$ABADDON_STATE_MACHINE_PREVIOUS_STATE"; }
get_transition_count() { echo "$ABADDON_STATE_MACHINE_TRANSITION_COUNT"; }
get_state_machine_error() { echo "$ABADDON_STATE_MACHINE_ERROR_MESSAGE"; }
get_last_transition_time() { echo "$ABADDON_STATE_MACHINE_LAST_TRANSITION_TIME"; }

# List all registered states
list_states() {
    local states=()
    for state in "${!ABADDON_STATE_MACHINE_VALID_STATES[@]}"; do
        states+=("$state")
    done
    printf '%s\n' "${states[@]}" | sort
}

# List all registered transitions
list_transitions() {
    local transitions=()
    for transition in "${!ABADDON_STATE_MACHINE_VALID_TRANSITIONS[@]}"; do
        transitions+=("$transition")
    done
    printf '%s\n' "${transitions[@]}" | sort
}

# ============================================================================
# State Management Helper Functions
# ============================================================================

# Set state machine error state
set_state_machine_error() {
    local error_message="$1"
    ABADDON_STATE_MACHINE_STATUS="$ABADDON_STATE_MACHINE_ERROR"
    ABADDON_STATE_MACHINE_ERROR_MESSAGE="$error_message"
    log_error "State Machine Error: $error_message"
}

# Set state machine success state
set_state_machine_success() {
    ABADDON_STATE_MACHINE_STATUS="$ABADDON_STATE_MACHINE_SUCCESS"
    ABADDON_STATE_MACHINE_ERROR_MESSAGE=""
}

# Check if last operation succeeded
state_machine_succeeded() { [[ "$ABADDON_STATE_MACHINE_STATUS" == "$ABADDON_STATE_MACHINE_SUCCESS" ]]; }
state_machine_failed() { [[ "$ABADDON_STATE_MACHINE_STATUS" != "$ABADDON_STATE_MACHINE_SUCCESS" ]]; }

# ============================================================================
# Statistics and Information
# ============================================================================

# Get state machine statistics
get_state_machine_stats() {
    echo "State Machine Statistics:"
    echo "  Current State: ${ABADDON_STATE_MACHINE_CURRENT_STATE:-none}"
    echo "  Previous State: ${ABADDON_STATE_MACHINE_PREVIOUS_STATE:-none}"
    echo "  Transition Count: $ABADDON_STATE_MACHINE_TRANSITION_COUNT"
    echo "  Last Transition: ${ABADDON_STATE_MACHINE_LAST_TRANSITION_TIME:-never}"
    echo "  Registered States: ${#ABADDON_STATE_MACHINE_VALID_STATES[@]}"
    echo "  Registered Transitions: ${#ABADDON_STATE_MACHINE_VALID_TRANSITIONS[@]}"
    echo "  Strict Mode: $ABADDON_STATE_MACHINE_STRICT_MODE"
}

# Module validation
state_machine_validate() {
    local errors=0
    
    # Check core functions exist
    for func in state_machine_init register_state register_transition transition_to_state require_state; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    for var in ABADDON_STATE_MACHINE_CURRENT_STATE ABADDON_STATE_MACHINE_STATUS; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    return $errors
}

# Module information
state_machine_info() {
    echo "abaddon-state-machine.sh - Generic Runtime Boundary Management"
    echo "Version: 1.0.0"
    echo "Current State: ${ABADDON_STATE_MACHINE_CURRENT_STATE:-uninitialized}"
    echo "Functions: state_machine_init, register_state, transition_to_state, require_state"
    echo "Boundary Enforcement: require_state, require_any_state, boundary enforcers"
    echo "Integration: security.sh + datatypes.sh for state validation"
}

log_debug "abaddon-state-machine.sh loaded successfully"