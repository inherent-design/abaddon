#!/usr/bin/env bash
# abaddon-object.sh - Stateful Proto-Object System
# Version: 1.0.0
# Purpose: P2 data management - schema-based object lifecycle with versioning

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_OBJECT_LOADED:-}" ]] && return 0
readonly ABADDON_OBJECT_LOADED=1

# Dependency checks - P2 Data Management
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-object.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] || {
    echo "ERROR: abaddon-object.sh requires abaddon-platform.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_CACHE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-object.sh requires abaddon-cache.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_SECURITY_LOADED:-}" ]] || {
    echo "ERROR: abaddon-object.sh requires abaddon-security.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_DATATYPES_LOADED:-}" ]] || {
    echo "ERROR: abaddon-object.sh requires abaddon-datatypes.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_KV_LOADED:-}" ]] || {
    echo "ERROR: abaddon-object.sh requires abaddon-kv.sh to be loaded first" >&2
    return 1
}

# ============================================================================
# Configuration and State Variables
# ============================================================================

# Configuration - environment configurable
declare -g ABADDON_OBJECT_MAX_HISTORY="${ABADDON_OBJECT_MAX_HISTORY:-100}"
declare -g ABADDON_OBJECT_AUTO_CHECKPOINT="${ABADDON_OBJECT_AUTO_CHECKPOINT:-true}"
declare -g ABADDON_OBJECT_STRICT_VALIDATION="${ABADDON_OBJECT_STRICT_VALIDATION:-true}"

# State variables - NO stdout pollution
declare -g ABADDON_OBJECT_STATUS=""
declare -g ABADDON_OBJECT_ERROR=""
declare -g ABADDON_OBJECT_CURRENT_OBJECT=""
declare -g ABADDON_OBJECT_LAST_OPERATION=""
declare -g ABADDON_OBJECT_OPERATION_TIME=""

# Object system registries
declare -g ABADDON_OBJECT_SYSTEM_INITIALIZED="false"
declare -Ag ABADDON_OBJECT_REGISTRY=()           # object_id -> manifest_time
declare -Ag ABADDON_OBJECT_SCHEMAS=()            # object_id -> schema_list
declare -Ag ABADDON_OBJECT_VERSIONS=()           # object_id -> current_version
declare -Ag ABADDON_OBJECT_STATES=()             # object_id:state_type -> state_value

# Schema definitions registry
declare -Ag ABADDON_SCHEMA_STATEFUL=()
declare -Ag ABADDON_SCHEMA_EXECUTABLE=()
declare -Ag ABADDON_SCHEMA_WORKFLOW=()
declare -Ag ABADDON_SCHEMA_STATE_MACHINE=()

# History and checkpoint storage
declare -Ag ABADDON_OBJECT_HISTORY=()            # object_id:sequence -> history_entry
declare -Ag ABADDON_OBJECT_HISTORY_COUNTERS=()   # object_id -> next_sequence_number
declare -Ag ABADDON_OBJECT_CHECKPOINTS=()        # object_id:checkpoint_name -> version

# Object lifecycle constants
readonly ABADDON_OBJECT_STATE_UNMANIFESTED="unmanifested"
readonly ABADDON_OBJECT_STATE_MANIFESTED="manifested"
readonly ABADDON_OBJECT_STATE_CHECKPOINTED="checkpointed"
readonly ABADDON_OBJECT_STATE_ARCHIVED="archived"
readonly ABADDON_OBJECT_STATE_DESTROYED="destroyed"

# Object modification states
readonly ABADDON_OBJECT_MODIFICATION_STABLE="stable"
readonly ABADDON_OBJECT_MODIFICATION_MODIFYING="modifying"
readonly ABADDON_OBJECT_MODIFICATION_MODIFIED="modified"
readonly ABADDON_OBJECT_MODIFICATION_VALIDATING="validating"
readonly ABADDON_OBJECT_MODIFICATION_VALIDATED="validated"
readonly ABADDON_OBJECT_MODIFICATION_ERROR="error"
readonly ABADDON_OBJECT_MODIFICATION_INVALID="invalid"

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all abaddon modules)
# ============================================================================

# Clear all object module state variables
clear_object_state() {
    ABADDON_OBJECT_STATUS=""
    ABADDON_OBJECT_ERROR=""
    ABADDON_OBJECT_CURRENT_OBJECT=""
    ABADDON_OBJECT_LAST_OPERATION=""
    ABADDON_OBJECT_OPERATION_TIME=""
    
    # Clear registries
    unset ABADDON_OBJECT_REGISTRY 2>/dev/null || true
    unset ABADDON_OBJECT_SCHEMAS 2>/dev/null || true
    unset ABADDON_OBJECT_VERSIONS 2>/dev/null || true
    unset ABADDON_OBJECT_STATES 2>/dev/null || true
    unset ABADDON_OBJECT_HISTORY 2>/dev/null || true
    unset ABADDON_OBJECT_CHECKPOINTS 2>/dev/null || true
    
    declare -Ag ABADDON_OBJECT_REGISTRY
    declare -Ag ABADDON_OBJECT_SCHEMAS
    declare -Ag ABADDON_OBJECT_VERSIONS
    declare -Ag ABADDON_OBJECT_STATES
    declare -Ag ABADDON_OBJECT_HISTORY
    declare -Ag ABADDON_OBJECT_CHECKPOINTS
    
    ABADDON_OBJECT_SYSTEM_INITIALIZED="false"
    
    log_debug "Object module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_object_status() {
    if [[ "$ABADDON_OBJECT_STATUS" == "ready" ]]; then
        echo "ready"
    elif [[ "$ABADDON_OBJECT_STATUS" == "error" ]]; then
        echo "error"
    elif [[ "$ABADDON_OBJECT_SYSTEM_INITIALIZED" == "true" ]]; then
        echo "ready"
    elif [[ -n "${ABADDON_KV_LOADED:-}" && -n "${ABADDON_DATATYPES_LOADED:-}" ]]; then
        echo "incomplete"
    else
        echo "unknown"
    fi
}

# Export object state for cross-module access
export_object_state() {
    echo "ABADDON_OBJECT_STATUS='$ABADDON_OBJECT_STATUS'"
    echo "ABADDON_OBJECT_ERROR='$ABADDON_OBJECT_ERROR'"
    echo "ABADDON_OBJECT_CURRENT_OBJECT='$ABADDON_OBJECT_CURRENT_OBJECT'"
    echo "ABADDON_OBJECT_LAST_OPERATION='$ABADDON_OBJECT_LAST_OPERATION'"
    echo "ABADDON_OBJECT_SYSTEM_INITIALIZED='$ABADDON_OBJECT_SYSTEM_INITIALIZED'"
    
    # Export object count
    local total_objects=0
    for key in "${!ABADDON_OBJECT_REGISTRY[@]}"; do
        ((total_objects++))
    done 2>/dev/null || total_objects=0
    echo "ABADDON_OBJECT_TOTAL_OBJECTS='$total_objects'"
}

# Validate object module state consistency
validate_object_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "object_system_init" "create_object" "destroy_object" "object_checkpoint"
        "object_rollback" "object_set_state" "object_get_state" "register_schema"
        "clear_object_state" "get_object_status" "export_object_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_OBJECT_STATUS" "ABADDON_OBJECT_REGISTRY"
        "ABADDON_OBJECT_SCHEMAS" "ABADDON_OBJECT_VERSIONS"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            validation_messages+=("Missing state variable: $var")
            ((errors++))
        fi
    done
    
    # Check dependencies are loaded
    local required_deps=(
        "ABADDON_CORE_LOADED" "ABADDON_PLATFORM_LOADED" "ABADDON_CACHE_LOADED"
        "ABADDON_SECURITY_LOADED" "ABADDON_DATATYPES_LOADED" "ABADDON_KV_LOADED"
    )
    
    for dep in "${required_deps[@]}"; do
        if [[ -z "${!dep:-}" ]]; then
            validation_messages+=("Required dependency not loaded: ${dep/_LOADED/}")
            ((errors++))
        fi
    done
    
    # Output validation results
    if [[ $errors -eq 0 ]]; then
        log_debug "Object module validation: PASSED"
        return 0
    else
        log_error "Object module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# ============================================================================
# Schema Registry System
# ============================================================================

# Initialize object system with default schemas
object_system_init() {
    local context="${1:-object-system}"
    
    log_debug "Initializing object system for context: $context"
    
    # Clear previous state
    clear_object_state
    
    # Register default schemas
    register_default_schemas
    
    ABADDON_OBJECT_SYSTEM_INITIALIZED="true"
    ABADDON_OBJECT_STATUS="ready"
    
    log_info "Object system initialized for context: $context"
    return 0
}

# Register default behavioral schemas
register_default_schemas() {
    # Stateful schema - basic state management
    ABADDON_SCHEMA_STATEFUL[init]="object_stateful_init"
    ABADDON_SCHEMA_STATEFUL[checkpoint]="object_stateful_checkpoint"
    ABADDON_SCHEMA_STATEFUL[rollback]="object_stateful_rollback"
    ABADDON_SCHEMA_STATEFUL[version]="object_stateful_version"
    ABADDON_SCHEMA_STATEFUL[history]="object_stateful_history"
    
    # Executable schema - execution capabilities
    ABADDON_SCHEMA_EXECUTABLE[execute]="object_executable_execute"
    ABADDON_SCHEMA_EXECUTABLE[validate]="object_executable_validate"
    ABADDON_SCHEMA_EXECUTABLE[retry]="object_executable_retry"
    ABADDON_SCHEMA_EXECUTABLE[status]="object_executable_status"
    
    # Workflow schema - workflow-specific behaviors
    ABADDON_SCHEMA_WORKFLOW[register_step]="object_workflow_register_step"
    ABADDON_SCHEMA_WORKFLOW[build_graph]="object_workflow_build_graph"
    ABADDON_SCHEMA_WORKFLOW[execute_workflow]="object_workflow_execute"
    ABADDON_SCHEMA_WORKFLOW[track_dependencies]="object_workflow_track_dependencies"
    
    # State machine schema - boundary enforcement
    ABADDON_SCHEMA_STATE_MACHINE[require_state]="object_state_machine_require_state"
    ABADDON_SCHEMA_STATE_MACHINE[transition_to]="object_state_machine_transition_to"
    ABADDON_SCHEMA_STATE_MACHINE[enforce_boundary]="object_state_machine_enforce_boundary"
    
    log_debug "Default schemas registered"
}

# Register custom schema
register_schema() {
    local schema_name="$1"
    local behavior_name="$2"
    local implementation_function="$3"
    
    if [[ -z "$schema_name" || -z "$behavior_name" || -z "$implementation_function" ]]; then
        set_object_error "register_schema requires: schema_name, behavior_name, implementation_function"
        return 1
    fi
    
    # Validate schema and behavior names
    if ! validate_identifier "$schema_name" false || ! validate_identifier "$behavior_name" false; then
        set_object_error "Invalid schema or behavior name format"
        return 1
    fi
    
    # Validate function exists in strict mode
    if [[ "$ABADDON_OBJECT_STRICT_VALIDATION" == "true" ]]; then
        if ! declare -F "$implementation_function" >/dev/null; then
            set_object_error "Implementation function not found: $implementation_function"
            return 1
        fi
    fi
    
    # Register schema behavior - using nameref to avoid eval
    local -n schema_ref="ABADDON_SCHEMA_${schema_name^^}"
    schema_ref["$behavior_name"]="$implementation_function"
    
    log_debug "Registered schema behavior: $schema_name.$behavior_name -> $implementation_function"
    return 0
}

# ============================================================================
# Object Lifecycle Management
# ============================================================================

# Create object with schema composition
create_object() {
    local object_id="$1"
    shift
    local schemas=("$@")
    
    if [[ -z "$object_id" ]]; then
        set_object_error "create_object requires object_id"
        return 1
    fi
    
    # Validate object ID
    if ! validate_identifier "$object_id" false; then
        set_object_error "Invalid object_id format: $object_id"
        return 1
    fi
    
    # Check system initialization
    if [[ "$ABADDON_OBJECT_SYSTEM_INITIALIZED" != "true" ]]; then
        set_object_error "Object system not initialized. Call object_system_init first"
        return 1
    fi
    
    # Check for duplicates
    if [[ -n "${ABADDON_OBJECT_REGISTRY[$object_id]:-}" ]]; then
        set_object_error "Object already exists: $object_id"
        return 1
    fi
    
    log_debug "Creating object: $object_id with schemas: ${schemas[*]}"
    
    # Initialize object metadata
    local manifest_time
    manifest_time=$(date +%s)
    ABADDON_OBJECT_REGISTRY[$object_id]="$manifest_time"
    ABADDON_OBJECT_SCHEMAS[$object_id]="${schemas[*]}"
    ABADDON_OBJECT_VERSIONS[$object_id]=1
    
    # Set initial states
    object_set_state "$object_id" "existence" "$ABADDON_OBJECT_STATE_MANIFESTED"
    object_set_state "$object_id" "modification" "$ABADDON_OBJECT_MODIFICATION_STABLE"
    
    # Assemble behaviors from schemas
    for schema in "${schemas[@]}"; do
        if ! assemble_schema_behaviors "$object_id" "$schema"; then
            destroy_object "$object_id"  # Cleanup on failure
            return 1
        fi
    done
    
    # Record creation in history
    object_record_history "$object_id" "created" "schemas: ${schemas[*]}"
    
    # Auto-checkpoint if enabled
    if [[ "$ABADDON_OBJECT_AUTO_CHECKPOINT" == "true" ]]; then
        object_checkpoint "$object_id" "initial"
    fi
    
    ABADDON_OBJECT_STATUS="object_created"
    ABADDON_OBJECT_CURRENT_OBJECT="$object_id"
    ABADDON_OBJECT_LAST_OPERATION="create"
    
    log_debug "Object created successfully: $object_id"
    return 0
}

# Assemble behaviors from a schema into object methods
assemble_schema_behaviors() {
    local object_id="$1"
    local schema_name="$2"
    
    local schema_var="ABADDON_SCHEMA_${schema_name^^}"
    
    # Check if schema exists
    if ! declare -p "$schema_var" >/dev/null 2>&1; then
        set_object_error "Schema not found: $schema_name"
        return 1
    fi
    
    # Get schema behaviors
    local -n schema_ref="$schema_var"
    
    # Create object methods for each behavior
    for behavior in "${!schema_ref[@]}"; do
        local implementation="${schema_ref[$behavior]}"
        local method_name="object_${object_id}_${behavior}"
        
        # Create dynamic method
        eval "$method_name() { $implementation $object_id \"\$@\"; }"
        
        log_debug "Assembled method: $method_name -> $implementation"
    done
    
    return 0
}

# Destroy object and cleanup all resources
destroy_object() {
    local object_id="$1"
    
    if [[ -z "$object_id" ]]; then
        set_object_error "destroy_object requires object_id"
        return 1
    fi
    
    # Check object exists
    if [[ -z "${ABADDON_OBJECT_REGISTRY[$object_id]:-}" ]]; then
        set_object_error "Object not found: $object_id"
        return 1
    fi
    
    log_debug "Destroying object: $object_id"
    
    # Record destruction in history before cleanup
    object_record_history "$object_id" "destroyed" "cleanup initiated"
    
    # Set destroyed state
    object_set_state "$object_id" "existence" "$ABADDON_OBJECT_STATE_DESTROYED"
    
    # Remove dynamic methods
    local schemas="${ABADDON_OBJECT_SCHEMAS[$object_id]}"
    for schema in $schemas; do
        cleanup_schema_behaviors "$object_id" "$schema"
    done
    
    # Cleanup object data
    unset "ABADDON_OBJECT_REGISTRY[$object_id]"
    unset "ABADDON_OBJECT_SCHEMAS[$object_id]"
    unset "ABADDON_OBJECT_VERSIONS[$object_id]"
    
    # Cleanup state data
    for key in "${!ABADDON_OBJECT_STATES[@]}"; do
        if [[ "$key" =~ ^${object_id}: ]]; then
            unset "ABADDON_OBJECT_STATES[$key]"
        fi
    done
    
    # Cleanup history and checkpoints
    for key in "${!ABADDON_OBJECT_HISTORY[@]}"; do
        if [[ "$key" =~ ^${object_id}: ]]; then
            unset "ABADDON_OBJECT_HISTORY[$key]"
        fi
    done
    
    for key in "${!ABADDON_OBJECT_CHECKPOINTS[@]}"; do
        if [[ "$key" =~ ^${object_id}: ]]; then
            unset "ABADDON_OBJECT_CHECKPOINTS[$key]"
        fi
    done
    
    ABADDON_OBJECT_STATUS="object_destroyed"
    ABADDON_OBJECT_LAST_OPERATION="destroy"
    
    log_debug "Object destroyed: $object_id"
    return 0
}

# Cleanup schema behaviors for object
cleanup_schema_behaviors() {
    local object_id="$1"
    local schema_name="$2"
    
    local schema_var="ABADDON_SCHEMA_${schema_name^^}"
    
    if declare -p "$schema_var" >/dev/null 2>&1; then
        local -n schema_ref="$schema_var"
        
        for behavior in "${!schema_ref[@]}"; do
            local method_name="object_${object_id}_${behavior}"
            unset -f "$method_name" 2>/dev/null || true
        done
    fi
}

# ============================================================================
# State Management System
# ============================================================================

# Set object state for specific state type
object_set_state() {
    local object_id="$1"
    local state_type="$2"
    local state_value="$3"
    
    if [[ -z "$object_id" || -z "$state_type" || -z "$state_value" ]]; then
        set_object_error "object_set_state requires: object_id, state_type, state_value"
        return 1
    fi
    
    # Check object exists
    if [[ -z "${ABADDON_OBJECT_REGISTRY[$object_id]:-}" ]]; then
        set_object_error "Object not found: $object_id"
        return 1
    fi
    
    local state_key="${object_id}:${state_type}"
    local previous_value="${ABADDON_OBJECT_STATES[$state_key]:-}"
    
    ABADDON_OBJECT_STATES[$state_key]="$state_value"
    
    # Record state change in history
    object_record_history "$object_id" "state_change" "$state_type: $previous_value -> $state_value"
    
    log_debug "Object $object_id state updated: $state_type = $state_value"
    return 0
}

# Get object state for specific state type
object_get_state() {
    local object_id="$1"
    local state_type="$2"
    
    if [[ -z "$object_id" || -z "$state_type" ]]; then
        set_object_error "object_get_state requires: object_id, state_type"
        return 1
    fi
    
    local state_key="${object_id}:${state_type}"
    echo "${ABADDON_OBJECT_STATES[$state_key]:-}"
}

# Check if object exists
object_exists() {
    local object_id="$1"
    [[ -n "${ABADDON_OBJECT_REGISTRY[$object_id]:-}" ]]
}

# Check if object is in specific state
object_is_in_state() {
    local object_id="$1"
    local state_type="$2"
    local expected_state="$3"
    
    local current_state
    current_state=$(object_get_state "$object_id" "$state_type")
    [[ "$current_state" == "$expected_state" ]]
}

# ============================================================================
# Versioning and History System
# ============================================================================

# Record operation in object history
object_record_history() {
    local object_id="$1"
    local operation="$2"
    local details="$3"
    
    local current_version="${ABADDON_OBJECT_VERSIONS[$object_id]:-1}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local history_key="${object_id}:${current_version}"
    
    ABADDON_OBJECT_HISTORY[$history_key]="$timestamp|$operation|$details"
    
    # Prune old history if needed
    prune_object_history "$object_id"
}

# Prune old history entries to stay within limits
prune_object_history() {
    local object_id="$1"
    
    if [[ "$ABADDON_OBJECT_MAX_HISTORY" -le 0 ]]; then
        return 0  # No limit
    fi
    
    # Count history entries for this object
    local count=0
    for key in "${!ABADDON_OBJECT_HISTORY[@]}"; do
        if [[ "$key" =~ ^${object_id}: ]]; then
            ((count++))
        fi
    done
    
    # Remove oldest entries if over limit
    if [[ $count -gt $ABADDON_OBJECT_MAX_HISTORY ]]; then
        local entries_to_remove=$((count - ABADDON_OBJECT_MAX_HISTORY))
        local removed=0
        
        # Remove oldest entries (lowest version numbers)
        for version in $(seq 1 100); do
            local key="${object_id}:${version}"
            if [[ -n "${ABADDON_OBJECT_HISTORY[$key]:-}" ]]; then
                unset "ABADDON_OBJECT_HISTORY[$key]"
                ((removed++))
                if [[ $removed -ge $entries_to_remove ]]; then
                    break
                fi
            fi
        done
    fi
}

# Create checkpoint of current object state
object_checkpoint() {
    local object_id="$1"
    local checkpoint_name="$2"
    
    if [[ -z "$object_id" || -z "$checkpoint_name" ]]; then
        set_object_error "object_checkpoint requires: object_id, checkpoint_name"
        return 1
    fi
    
    # Check object exists
    if [[ -z "${ABADDON_OBJECT_REGISTRY[$object_id]:-}" ]]; then
        set_object_error "Object not found: $object_id"
        return 1
    fi
    
    local current_version="${ABADDON_OBJECT_VERSIONS[$object_id]}"
    local checkpoint_key="${object_id}:${checkpoint_name}"
    
    ABADDON_OBJECT_CHECKPOINTS[$checkpoint_key]="$current_version"
    
    # Update object state
    object_set_state "$object_id" "existence" "$ABADDON_OBJECT_STATE_CHECKPOINTED"
    
    # Record checkpoint in history
    object_record_history "$object_id" "checkpoint" "$checkpoint_name at v$current_version"
    
    log_debug "Checkpoint created: $object_id.$checkpoint_name at version $current_version"
    return 0
}

# Rollback object to checkpoint or version
object_rollback() {
    local object_id="$1"
    local target="$2"
    
    if [[ -z "$object_id" || -z "$target" ]]; then
        set_object_error "object_rollback requires: object_id, target"
        return 1
    fi
    
    # Check object exists
    if [[ -z "${ABADDON_OBJECT_REGISTRY[$object_id]:-}" ]]; then
        set_object_error "Object not found: $object_id"
        return 1
    fi
    
    local target_version=""
    
    # Determine target version
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        # Direct version number
        target_version="$target"
    else
        # Checkpoint name
        local checkpoint_key="${object_id}:${target}"
        target_version="${ABADDON_OBJECT_CHECKPOINTS[$checkpoint_key]:-}"
        
        if [[ -z "$target_version" ]]; then
            set_object_error "Checkpoint not found: $target"
            return 1
        fi
    fi
    
    # TODO: Implement actual state rollback logic
    # For now, just update version and record the rollback
    ABADDON_OBJECT_VERSIONS[$object_id]="$target_version"
    
    # Record rollback in history
    object_record_history "$object_id" "rollback" "to $target (v$target_version)"
    
    log_debug "Object rolled back: $object_id to $target (version $target_version)"
    return 0
}

# ============================================================================
# Default Schema Implementations
# ============================================================================

# Stateful schema implementations
object_stateful_init() {
    local object_id="$1"
    shift
    local init_args=("$@")
    
    log_debug "Stateful init for object: $object_id"
    object_set_state "$object_id" "modification" "$ABADDON_OBJECT_MODIFICATION_STABLE"
    return 0
}

object_stateful_checkpoint() {
    local object_id="$1"
    local checkpoint_name="${2:-auto_$(date +%s)}"
    
    object_checkpoint "$object_id" "$checkpoint_name"
}

object_stateful_rollback() {
    local object_id="$1"
    local target="$2"
    
    object_rollback "$object_id" "$target"
}

object_stateful_version() {
    local object_id="$1"
    echo "${ABADDON_OBJECT_VERSIONS[$object_id]:-}"
}

object_stateful_history() {
    local object_id="$1"
    local limit="${2:-10}"
    
    local count=0
    for key in "${!ABADDON_OBJECT_HISTORY[@]}"; do
        if [[ "$key" =~ ^${object_id}: ]]; then
            echo "${ABADDON_OBJECT_HISTORY[$key]}"
            ((count++))
            if [[ $count -ge $limit ]]; then
                break
            fi
        fi
    done
}

# Executable schema implementations
object_executable_execute() {
    local object_id="$1"
    shift
    local exec_args=("$@")
    
    log_debug "Executing object: $object_id"
    object_set_state "$object_id" "execution" "executing"
    
    # TODO: Implement execution logic
    # For now, just mark as completed
    object_set_state "$object_id" "execution" "completed"
    return 0
}

object_executable_validate() {
    local object_id="$1"
    
    log_debug "Validating object: $object_id"
    object_set_state "$object_id" "modification" "$ABADDON_OBJECT_MODIFICATION_VALIDATING"
    
    # TODO: Implement validation logic
    object_set_state "$object_id" "modification" "$ABADDON_OBJECT_MODIFICATION_VALIDATED"
    return 0
}

object_executable_retry() {
    local object_id="$1"
    local max_retries="${2:-3}"
    
    log_debug "Retry logic for object: $object_id (max: $max_retries)"
    # TODO: Implement retry logic
    return 0
}

object_executable_status() {
    local object_id="$1"
    
    local execution_state
    execution_state=$(object_get_state "$object_id" "execution")
    echo "${execution_state:-ready}"
}

# ============================================================================
# State Management Utilities
# ============================================================================

# Set object error state
set_object_error() {
    local error_message="$1"
    ABADDON_OBJECT_STATUS="error"
    ABADDON_OBJECT_ERROR="$error_message"
    log_error "Object Error: $error_message"
}

# Set object success state
set_object_success() {
    local operation="${1:-}"
    ABADDON_OBJECT_STATUS="success"
    ABADDON_OBJECT_ERROR=""
    if [[ -n "$operation" ]]; then
        ABADDON_OBJECT_LAST_OPERATION="$operation"
    fi
}

# State accessor functions
get_object_error() { echo "${ABADDON_OBJECT_ERROR:-}"; }
get_object_current_object() { echo "${ABADDON_OBJECT_CURRENT_OBJECT:-}"; }
get_object_last_operation() { echo "${ABADDON_OBJECT_LAST_OPERATION:-}"; }

# Check if operation succeeded
object_succeeded() { [[ "$ABADDON_OBJECT_STATUS" == "success" || "$ABADDON_OBJECT_STATUS" == "object_created" ]]; }
object_failed() { [[ "$ABADDON_OBJECT_STATUS" == "error" ]]; }

# ============================================================================
# Query and Information Functions
# ============================================================================

# List all objects
list_objects() {
    local format="${1:-name}"
    
    case "$format" in
        name)
            for object_id in "${!ABADDON_OBJECT_REGISTRY[@]}"; do
                echo "$object_id"
            done | sort
            ;;
        detailed)
            printf "%-20s %-10s %-30s %-15s\\n" "OBJECT" "VERSION" "SCHEMAS" "EXISTENCE"
            printf "%-20s %-10s %-30s %-15s\\n" "------" "-------" "-------" "---------"
            
            for object_id in "${!ABADDON_OBJECT_REGISTRY[@]}"; do
                local version="${ABADDON_OBJECT_VERSIONS[$object_id]:-}"
                local schemas="${ABADDON_OBJECT_SCHEMAS[$object_id]:-}"
                local existence_state
                existence_state=$(object_get_state "$object_id" "existence")
                
                printf "%-20s %-10s %-30s %-15s\\n" "$object_id" "$version" "${schemas:0:27}..." "$existence_state"
            done
            ;;
        *)
            set_object_error "Unknown format: $format"
            return 1
            ;;
    esac
}

# Get object statistics
get_object_stats() {
    if [[ "$ABADDON_OBJECT_SYSTEM_INITIALIZED" != "true" ]]; then
        echo "Object System: Not initialized"
        return 1
    fi
    
    local total_objects=0
    local total_history=0
    local total_checkpoints=0
    
    # Count objects
    for key in "${!ABADDON_OBJECT_REGISTRY[@]}"; do
        ((total_objects++))
    done 2>/dev/null || total_objects=0
    
    # Count history entries
    for key in "${!ABADDON_OBJECT_HISTORY[@]}"; do
        ((total_history++))
    done 2>/dev/null || total_history=0
    
    # Count checkpoints
    for key in "${!ABADDON_OBJECT_CHECKPOINTS[@]}"; do
        ((total_checkpoints++))
    done 2>/dev/null || total_checkpoints=0
    
    echo "Object System Statistics:"
    echo "  Total Objects: $total_objects"
    echo "  Total History Entries: $total_history"
    echo "  Total Checkpoints: $total_checkpoints"
    echo "  Max History Per Object: $ABADDON_OBJECT_MAX_HISTORY"
    echo "  Auto Checkpoint: $ABADDON_OBJECT_AUTO_CHECKPOINT"
    echo "  Strict Validation: $ABADDON_OBJECT_STRICT_VALIDATION"
}

# ============================================================================
# Module Validation and Information
# ============================================================================

# Validate object system
object_validate() {
    local errors=0
    
    # Check core functions exist
    for func in object_system_init create_object destroy_object object_checkpoint object_rollback; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    for var in ABADDON_OBJECT_STATUS ABADDON_OBJECT_REGISTRY ABADDON_OBJECT_SCHEMAS; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    return $errors
}

# Module information
object_info() {
    echo "abaddon-object.sh - Stateful Proto-Object System"
    echo "Version: 1.0.0"
    echo "Functions: object_system_init, create_object, destroy_object, object_checkpoint"
    echo "Features: Schema composition, versioning, history, rollback"
    echo "Schemas: stateful, executable, workflow, state_machine"
    echo "System: ${ABADDON_OBJECT_SYSTEM_INITIALIZED:-false}"
}

log_debug "abaddon-object.sh loaded successfully"