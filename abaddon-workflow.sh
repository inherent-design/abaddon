#!/usr/bin/env bash
# abaddon-workflow.sh - Williams-Style Dependency Resolution & Workflow Orchestration
# Version: 1.0.0
# Purpose: P3 orchestration primitives - workflow dependency resolution and execution

set -u  # Catch undefined variables (linting-like behavior)

# Load guard
[[ -n "${ABADDON_WORKFLOW_LOADED:-}" ]] && return 0
readonly ABADDON_WORKFLOW_LOADED=1

# Dependency checks - P3 Orchestration Primitive
[[ -n "${ABADDON_CORE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-workflow.sh requires abaddon-core.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_PLATFORM_LOADED:-}" ]] || {
    echo "ERROR: abaddon-workflow.sh requires abaddon-platform.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_CACHE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-workflow.sh requires abaddon-cache.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_SECURITY_LOADED:-}" ]] || {
    echo "ERROR: abaddon-workflow.sh requires abaddon-security.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_DATATYPES_LOADED:-}" ]] || {
    echo "ERROR: abaddon-workflow.sh requires abaddon-datatypes.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_KV_LOADED:-}" ]] || {
    echo "ERROR: abaddon-workflow.sh requires abaddon-kv.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_STATE_MACHINE_LOADED:-}" ]] || {
    echo "ERROR: abaddon-workflow.sh requires abaddon-state-machine.sh to be loaded first" >&2
    return 1
}

[[ -n "${ABADDON_COMMAND_LOADED:-}" ]] || {
    echo "ERROR: abaddon-workflow.sh requires abaddon-command.sh to be loaded first" >&2
    return 1
}

# ============================================================================
# Configuration and State Variables
# ============================================================================

# Configuration - environment configurable
declare -g ABADDON_WORKFLOW_MAX_DEPTH="${ABADDON_WORKFLOW_MAX_DEPTH:-20}"
declare -g ABADDON_WORKFLOW_STRICT_VALIDATION="${ABADDON_WORKFLOW_STRICT_VALIDATION:-true}"
declare -g ABADDON_WORKFLOW_ENABLE_PARALLEL="${ABADDON_WORKFLOW_ENABLE_PARALLEL:-false}"
declare -g ABADDON_WORKFLOW_DEFAULT_PRIORITY="${ABADDON_WORKFLOW_DEFAULT_PRIORITY:-50}"

# State variables - NO stdout pollution
declare -g ABADDON_WORKFLOW_STATUS=""
declare -g ABADDON_WORKFLOW_ERROR=""
declare -g ABADDON_WORKFLOW_CURRENT_WORKFLOW=""
declare -g ABADDON_WORKFLOW_CURRENT_STEP=""
declare -g ABADDON_WORKFLOW_EXECUTION_TIME=""
declare -g ABADDON_WORKFLOW_STEPS_EXECUTED=""

# Workflow registry storage
declare -g ABADDON_WORKFLOW_REGISTRY_INITIALIZED="false"
declare -Ag ABADDON_WORKFLOW_STEPS           # workflow:step -> function
declare -Ag ABADDON_WORKFLOW_DEPENDENCIES    # workflow:step -> space-separated deps
declare -Ag ABADDON_WORKFLOW_DESCRIPTIONS    # workflow:step -> description
declare -Ag ABADDON_WORKFLOW_COMMAND_MAPPING # command -> workflow (for command integration)

# Williams-style dependency resolution state
declare -Ag ABADDON_WORKFLOW_DEPENDENCY_GRAPH    # Internal graph representation
declare -Ag ABADDON_WORKFLOW_EXECUTION_ORDER     # workflow -> resolved execution order
declare -Ag ABADDON_WORKFLOW_STEP_STATUS         # workflow:step -> status

# Runtime state tracking
declare -g ABADDON_WORKFLOW_INITIALIZATION_PHASE="true"
declare -g ABADDON_WORKFLOW_EXECUTION_PHASE="false"

# Statistics
declare -g ABADDON_WORKFLOW_TOTAL_WORKFLOWS=0
declare -g ABADDON_WORKFLOW_TOTAL_STEPS=0
declare -g ABADDON_WORKFLOW_TOTAL_EXECUTED=0
declare -g ABADDON_WORKFLOW_TOTAL_ERRORS=0

# Williams-style resolution constants
readonly ABADDON_WORKFLOW_STEP_PENDING="pending"
readonly ABADDON_WORKFLOW_STEP_EXECUTING="executing"
readonly ABADDON_WORKFLOW_STEP_COMPLETED="completed"
readonly ABADDON_WORKFLOW_STEP_FAILED="failed"
readonly ABADDON_WORKFLOW_STEP_BLOCKED="blocked"

# ============================================================================
# MODULE CONTRACT INTERFACE (MANDATORY for all abaddon modules)
# ============================================================================

# Clear all workflow module state variables
clear_workflow_state() {
    ABADDON_WORKFLOW_STATUS=""
    ABADDON_WORKFLOW_ERROR=""
    ABADDON_WORKFLOW_CURRENT_WORKFLOW=""
    ABADDON_WORKFLOW_CURRENT_STEP=""
    ABADDON_WORKFLOW_EXECUTION_TIME=""
    ABADDON_WORKFLOW_STEPS_EXECUTED=""
    
    # Clear registries
    unset ABADDON_WORKFLOW_STEPS 2>/dev/null || true
    unset ABADDON_WORKFLOW_DEPENDENCIES 2>/dev/null || true
    unset ABADDON_WORKFLOW_DESCRIPTIONS 2>/dev/null || true
    unset ABADDON_WORKFLOW_COMMAND_MAPPING 2>/dev/null || true
    unset ABADDON_WORKFLOW_DEPENDENCY_GRAPH 2>/dev/null || true
    unset ABADDON_WORKFLOW_EXECUTION_ORDER 2>/dev/null || true
    unset ABADDON_WORKFLOW_STEP_STATUS 2>/dev/null || true
    
    declare -Ag ABADDON_WORKFLOW_STEPS
    declare -Ag ABADDON_WORKFLOW_DEPENDENCIES
    declare -Ag ABADDON_WORKFLOW_DESCRIPTIONS
    declare -Ag ABADDON_WORKFLOW_COMMAND_MAPPING
    declare -Ag ABADDON_WORKFLOW_DEPENDENCY_GRAPH
    declare -Ag ABADDON_WORKFLOW_EXECUTION_ORDER
    declare -Ag ABADDON_WORKFLOW_STEP_STATUS
    
    ABADDON_WORKFLOW_REGISTRY_INITIALIZED="false"
    ABADDON_WORKFLOW_INITIALIZATION_PHASE="true"
    ABADDON_WORKFLOW_EXECUTION_PHASE="false"
    
    log_debug "Workflow module state cleared"
}

# Return module status: "ready|error|incomplete|unknown"
get_workflow_status() {
    if [[ "$ABADDON_WORKFLOW_STATUS" == "ready" ]]; then
        echo "ready"
    elif [[ "$ABADDON_WORKFLOW_STATUS" == "error" ]]; then
        echo "error"
    elif [[ "$ABADDON_WORKFLOW_REGISTRY_INITIALIZED" == "true" ]]; then
        echo "ready"
    elif [[ -n "${ABADDON_CORE_LOADED:-}" && -n "${ABADDON_STATE_MACHINE_LOADED:-}" && -n "${ABADDON_COMMAND_LOADED:-}" ]]; then
        echo "incomplete"
    else
        echo "unknown"
    fi
}

# Export workflow state for cross-module access
export_workflow_state() {
    echo "ABADDON_WORKFLOW_STATUS='$ABADDON_WORKFLOW_STATUS'"
    echo "ABADDON_WORKFLOW_ERROR='$ABADDON_WORKFLOW_ERROR'"
    echo "ABADDON_WORKFLOW_CURRENT_WORKFLOW='$ABADDON_WORKFLOW_CURRENT_WORKFLOW'"
    echo "ABADDON_WORKFLOW_CURRENT_STEP='$ABADDON_WORKFLOW_CURRENT_STEP'"
    echo "ABADDON_WORKFLOW_STEPS_EXECUTED='$ABADDON_WORKFLOW_STEPS_EXECUTED'"
    echo "ABADDON_WORKFLOW_REGISTRY_INITIALIZED='$ABADDON_WORKFLOW_REGISTRY_INITIALIZED'"
    
    # Export step count
    local total_steps=0
    for key in "${!ABADDON_WORKFLOW_STEPS[@]}"; do
        ((total_steps++))
    done 2>/dev/null || total_steps=0
    echo "ABADDON_WORKFLOW_TOTAL_STEPS='$total_steps'"
}

# Validate workflow module state consistency  
validate_workflow_state() {
    local errors=0
    local validation_messages=()
    
    # Check required functions exist
    local required_functions=(
        "workflow_init" "workflow_register_step" "workflow_execute" "build_dependency_graph"
        "register_workflow_command" "clear_workflow_state" "get_workflow_status"
        "export_workflow_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            validation_messages+=("Missing function: $func")
            ((errors++))
        fi
    done
    
    # Check state variables exist
    local required_vars=(
        "ABADDON_WORKFLOW_STATUS" "ABADDON_WORKFLOW_ERROR"
        "ABADDON_WORKFLOW_CURRENT_WORKFLOW" "ABADDON_WORKFLOW_STEPS"
    )
    
    for var in "${required_vars[@]}"; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            validation_messages+=("Missing state variable: $var")
            ((errors++))
        fi
    done
    
    # Check dependencies are loaded
    local required_deps=(
        "ABADDON_CORE_LOADED" "ABADDON_STATE_MACHINE_LOADED" "ABADDON_COMMAND_LOADED"
    )
    
    for dep in "${required_deps[@]}"; do
        if [[ -z "${!dep:-}" ]]; then
            validation_messages+=("Required dependency not loaded: ${dep/_LOADED/}")
            ((errors++))
        fi
    done
    
    # Output validation results
    if [[ $errors -eq 0 ]]; then
        log_debug "Workflow module validation: PASSED"
        return 0
    else
        log_error "Workflow module validation: FAILED ($errors errors)"
        for msg in "${validation_messages[@]}"; do
            log_error "  - $msg"
        done
        return 1
    fi
}

# ============================================================================
# Core Workflow Management
# ============================================================================

# Initialize workflow system
workflow_init() {
    local app_context="${1:-workflow-system}"
    
    log_debug "Initializing workflow system for context: $app_context"
    
    # Clear previous state
    clear_workflow_state
    
    ABADDON_WORKFLOW_REGISTRY_INITIALIZED="true"
    ABADDON_WORKFLOW_INITIALIZATION_PHASE="true"
    ABADDON_WORKFLOW_EXECUTION_PHASE="false"
    ABADDON_WORKFLOW_STATUS="ready"
    
    log_info "Workflow system initialized for context: $app_context"
    return 0
}

# Register a workflow step with dependencies
workflow_register_step() {
    local workflow="$1"
    local step_name="$2"
    local step_function="$3"
    local dependencies="${4:-}"  # Space-separated list
    local description="${5:-}"
    
    # Note: Don't reset state here as it clears status from other operations
    
    # Input validation
    if [[ -z "$workflow" || -z "$step_name" || -z "$step_function" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="workflow_register_step requires: workflow, step_name, step_function"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Check registry initialization
    if [[ "$ABADDON_WORKFLOW_REGISTRY_INITIALIZED" != "true" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="Workflow registry not initialized. Call workflow_init first"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Runtime boundary enforcement
    if [[ "$ABADDON_WORKFLOW_EXECUTION_PHASE" == "true" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="Cannot register steps during execution phase"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Validate step function exists
    if [[ "$ABADDON_WORKFLOW_STRICT_VALIDATION" == "true" ]]; then
        if ! declare -F "$step_function" >/dev/null; then
            ABADDON_WORKFLOW_STATUS="error"
            ABADDON_WORKFLOW_ERROR="Step function not found: $step_function"
            log_error "$ABADDON_WORKFLOW_ERROR"
            return 1
        fi
    fi
    
    # Validate workflow and step names using datatypes
    if ! validate_identifier "$workflow" false || ! validate_identifier "$step_name" false; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="Invalid workflow or step name format"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Check for duplicates
    local step_key="${workflow}:${step_name}"
    if [[ -n "${ABADDON_WORKFLOW_STEPS[$step_key]:-}" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="Step already registered: $step_key"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    
    # Register the step
    ABADDON_WORKFLOW_STEPS[$step_key]="$step_function"
    ABADDON_WORKFLOW_DEPENDENCIES[$step_key]="$dependencies"
    ABADDON_WORKFLOW_DESCRIPTIONS[$step_key]="$description"
    ABADDON_WORKFLOW_STEP_STATUS[$step_key]="$ABADDON_WORKFLOW_STEP_PENDING"
    
    ((ABADDON_WORKFLOW_TOTAL_STEPS++))
    
    ABADDON_WORKFLOW_STATUS="step_registered"
    ABADDON_WORKFLOW_CURRENT_WORKFLOW="$workflow"
    ABADDON_WORKFLOW_CURRENT_STEP="$step_name"
    
    log_debug "Registered workflow step: $step_key (function: $step_function, deps: $dependencies)"
    return 0
}

# ============================================================================
# Williams-Style Dependency Resolution
# ============================================================================

# Build dependency graph for workflow using Williams-style block partitioning
build_dependency_graph() {
    local workflow="$1"
    local visited_steps=()
    local resolved_order=()
    local temp_marks=()
    
    if [[ -z "$workflow" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="build_dependency_graph requires workflow name"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    log_debug "Building dependency graph for workflow: $workflow"
    
    # Clear execution order cache
    unset "ABADDON_WORKFLOW_EXECUTION_ORDER[$workflow]"
    
    # Find all steps for this workflow
    local workflow_steps=()
    for step_key in "${!ABADDON_WORKFLOW_STEPS[@]}"; do
        if [[ "$step_key" =~ ^${workflow}: ]]; then
            local step_name="${step_key#*:}"
            workflow_steps+=("$step_name")
        fi
    done
    
    if [[ ${#workflow_steps[@]} -eq 0 ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="No steps found for workflow: $workflow"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Williams-style topological sort with cycle detection
    # Use global arrays to avoid nameref issues
    declare -g _WORKFLOW_VISITED_STEPS=()
    declare -g _WORKFLOW_TEMP_MARKS=()
    declare -g _WORKFLOW_RESOLVED_ORDER=()
    
    for step in "${workflow_steps[@]}"; do
        if ! array_contains "$step" "${_WORKFLOW_VISITED_STEPS[@]}"; then
            if ! _workflow_visit_step "$workflow" "$step"; then
                ABADDON_WORKFLOW_STATUS="error"
                ABADDON_WORKFLOW_ERROR="Dependency cycle detected in workflow: $workflow"
                log_error "$ABADDON_WORKFLOW_ERROR"
                return 1
            fi
        fi
    done
    
    # Copy resolved order to local array
    resolved_order=("${_WORKFLOW_RESOLVED_ORDER[@]}")
    
    # Cache the resolved order
    local order_string
    order_string=$(printf '%s ' "${resolved_order[@]}")
    ABADDON_WORKFLOW_EXECUTION_ORDER[$workflow]="${order_string% }"
    
    ABADDON_WORKFLOW_STATUS="graph_built"
    ABADDON_WORKFLOW_CURRENT_WORKFLOW="$workflow"
    
    log_debug "Dependency graph built for $workflow: ${ABADDON_WORKFLOW_EXECUTION_ORDER[$workflow]}"
    # Don't echo - caller can get order from ABADDON_WORKFLOW_EXECUTION_ORDER[$workflow]
    return 0
}

# Recursive step visitor for dependency resolution (Williams-style DFS)
_workflow_visit_step() {
    local workflow="$1"
    local step="$2"
    
    local step_key="${workflow}:${step}"
    
    # Check for temporary mark (cycle detection)
    if array_contains "$step" "${_WORKFLOW_TEMP_MARKS[@]}"; then
        return 1  # Cycle detected
    fi
    
    # Already visited
    if array_contains "$step" "${_WORKFLOW_VISITED_STEPS[@]}"; then
        return 0
    fi
    
    # Add temporary mark
    _WORKFLOW_TEMP_MARKS+=("$step")
    
    # Visit dependencies first
    local dependencies="${ABADDON_WORKFLOW_DEPENDENCIES[$step_key]:-}"
    if [[ -n "$dependencies" ]]; then
        for dep in $dependencies; do
            local dep_key="${workflow}:${dep}"
            
            # Validate dependency exists
            if [[ -z "${ABADDON_WORKFLOW_STEPS[$dep_key]:-}" ]]; then
                log_error "Dependency not found: $dep for step $step in workflow $workflow"
                return 1
            fi
            
            if ! _workflow_visit_step "$workflow" "$dep"; then
                return 1
            fi
        done
    fi
    
    # Remove temporary mark
    local new_temp=()
    for item in "${_WORKFLOW_TEMP_MARKS[@]}"; do
        [[ "$item" != "$step" ]] && new_temp+=("$item")
    done
    _WORKFLOW_TEMP_MARKS=("${new_temp[@]}")
    
    # Add to visited and order
    _WORKFLOW_VISITED_STEPS+=("$step")
    _WORKFLOW_RESOLVED_ORDER+=("$step")
    
    return 0
}

# ============================================================================
# Workflow Execution
# ============================================================================

# Execute workflow with dependency resolution
workflow_execute() {
    local workflow="$1"
    shift
    local workflow_args=("$@")
    
    
    if [[ -z "$workflow" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="workflow_execute requires workflow name"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Check registry initialization
    if [[ "$ABADDON_WORKFLOW_REGISTRY_INITIALIZED" != "true" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="Workflow registry not initialized"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Transition to execution phase
    ABADDON_WORKFLOW_INITIALIZATION_PHASE="false"
    ABADDON_WORKFLOW_EXECUTION_PHASE="true"
    
    log_info "Executing workflow: $workflow"
    
    # Build dependency graph and get execution order
    if ! build_dependency_graph "$workflow"; then
        return 1
    fi
    
    local execution_order="${ABADDON_WORKFLOW_EXECUTION_ORDER[$workflow]}"
    if [[ -z "$execution_order" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="No execution order resolved for workflow: $workflow"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Execute steps in resolved order
    local start_time
    start_time=$(date +%s%N)
    local steps_executed=0
    local failed_steps=0
    
    ABADDON_WORKFLOW_CURRENT_WORKFLOW="$workflow"
    ABADDON_WORKFLOW_STATUS="executing"
    
    for step in $execution_order; do
        local step_key="${workflow}:${step}"
        local step_function="${ABADDON_WORKFLOW_STEPS[$step_key]}"
        
        ABADDON_WORKFLOW_CURRENT_STEP="$step"
        ABADDON_WORKFLOW_STEP_STATUS[$step_key]="$ABADDON_WORKFLOW_STEP_EXECUTING"
        
        log_debug "Executing workflow step: $step_key (function: $step_function)"
        
        # Execute step
        local step_exit_code=0
        if "$step_function" "${workflow_args[@]}"; then
            ABADDON_WORKFLOW_STEP_STATUS[$step_key]="$ABADDON_WORKFLOW_STEP_COMPLETED"
            ((steps_executed++))
            log_debug "Step completed: $step"
        else
            step_exit_code=$?
            ABADDON_WORKFLOW_STEP_STATUS[$step_key]="$ABADDON_WORKFLOW_STEP_FAILED"
            ((failed_steps++))
            ((ABADDON_WORKFLOW_TOTAL_ERRORS++))
            
            log_error "Step failed: $step (exit code: $step_exit_code)"
            ABADDON_WORKFLOW_ERROR="Step $step failed with exit code: $step_exit_code"
            
            # Stop execution on failure
            ABADDON_WORKFLOW_STATUS="step_failed"
            break
        fi
    done
    
    # Calculate execution time
    local end_time
    end_time=$(date +%s%N)
    local execution_time=$(( (end_time - start_time) / 1000000 ))
    ABADDON_WORKFLOW_EXECUTION_TIME="${execution_time}ms"
    ABADDON_WORKFLOW_STEPS_EXECUTED="$steps_executed"
    
    # Set final status
    if [[ $failed_steps -eq 0 ]]; then
        ABADDON_WORKFLOW_STATUS="success"
        ((ABADDON_WORKFLOW_TOTAL_EXECUTED++))
        log_info "Workflow $workflow completed successfully in $ABADDON_WORKFLOW_EXECUTION_TIME ($steps_executed steps)"
        return 0
    else
        ABADDON_WORKFLOW_STATUS="failed"
        log_error "Workflow $workflow failed (executed: $steps_executed, failed: $failed_steps)"
        return 1
    fi
}

# Execute a single step (for testing/debugging)
execute_step() {
    local step_key="$1"
    shift
    local step_args=("$@")
    
    reset_workflow_state
    
    if [[ -z "$step_key" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="execute_step requires step_key (workflow:step)"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    local step_function="${ABADDON_WORKFLOW_STEPS[$step_key]:-}"
    if [[ -z "$step_function" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="Step not found: $step_key"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    ABADDON_WORKFLOW_CURRENT_STEP="$step_key"
    ABADDON_WORKFLOW_STATUS="executing"
    ABADDON_WORKFLOW_STEP_STATUS[$step_key]="$ABADDON_WORKFLOW_STEP_EXECUTING"
    
    log_debug "Executing single step: $step_key"
    
    # Execute step
    local start_time
    start_time=$(date +%s%N)
    
    local exit_code=0
    if "$step_function" "${step_args[@]}"; then
        ABADDON_WORKFLOW_STEP_STATUS[$step_key]="$ABADDON_WORKFLOW_STEP_COMPLETED"
        ABADDON_WORKFLOW_STATUS="success"
    else
        exit_code=$?
        ABADDON_WORKFLOW_STEP_STATUS[$step_key]="$ABADDON_WORKFLOW_STEP_FAILED"
        ABADDON_WORKFLOW_STATUS="step_failed"
        ABADDON_WORKFLOW_ERROR="Step failed with exit code: $exit_code"
    fi
    
    # Calculate execution time
    local end_time
    end_time=$(date +%s%N)
    local execution_time=$(( (end_time - start_time) / 1000000 ))
    ABADDON_WORKFLOW_EXECUTION_TIME="${execution_time}ms"
    
    return $exit_code
}

# ============================================================================
# Command Pattern Integration
# ============================================================================

# Register workflow command (integrates with command module)
register_workflow_command() {
    local command_name="$1"
    local workflow_name="$2"
    local description="$3"
    local priority="${4:-$ABADDON_WORKFLOW_DEFAULT_PRIORITY}"
    
    reset_workflow_state
    
    if [[ -z "$command_name" || -z "$workflow_name" || -z "$description" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="register_workflow_command requires: command_name, workflow_name, description"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Check if workflow has steps
    local has_steps=false
    for step_key in "${!ABADDON_WORKFLOW_STEPS[@]}"; do
        if [[ "$step_key" =~ ^${workflow_name}: ]]; then
            has_steps=true
            break
        fi
    done
    
    if [[ "$has_steps" != "true" ]]; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="Workflow has no registered steps: $workflow_name"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Create wrapper function
    local wrapper_function="_workflow_command_${command_name}_wrapper"
    
    # Define the wrapper function dynamically
    eval "$wrapper_function() { workflow_execute \"$workflow_name\" \"\$@\"; }"
    
    # Register with command system
    if ! register_command "$command_name" "$description" "$wrapper_function" "$priority"; then
        ABADDON_WORKFLOW_STATUS="error"
        ABADDON_WORKFLOW_ERROR="Failed to register workflow command: $command_name"
        log_error "$ABADDON_WORKFLOW_ERROR"
        return 1
    fi
    
    # Track command-to-workflow mapping
    ABADDON_WORKFLOW_COMMAND_MAPPING[$command_name]="$workflow_name"
    
    ABADDON_WORKFLOW_STATUS="command_registered"
    ABADDON_WORKFLOW_CURRENT_WORKFLOW="$workflow_name"
    
    log_debug "Registered workflow command: $command_name -> $workflow_name"
    return 0
}

# ============================================================================
# State Management and Utilities
# ============================================================================

# Reset workflow state
reset_workflow_state() {
    ABADDON_WORKFLOW_STATUS=""
    ABADDON_WORKFLOW_ERROR=""
    ABADDON_WORKFLOW_CURRENT_WORKFLOW=""
    ABADDON_WORKFLOW_CURRENT_STEP=""
    ABADDON_WORKFLOW_EXECUTION_TIME=""
    ABADDON_WORKFLOW_STEPS_EXECUTED=""
}

# Set workflow error state
set_workflow_error() {
    local error_message="$1"
    ABADDON_WORKFLOW_STATUS="error"
    ABADDON_WORKFLOW_ERROR="$error_message"
    log_error "Workflow Error: $error_message"
}

# Set workflow success state
set_workflow_success() {
    local workflow="${1:-}"
    ABADDON_WORKFLOW_STATUS="success"
    ABADDON_WORKFLOW_ERROR=""
    if [[ -n "$workflow" ]]; then
        ABADDON_WORKFLOW_CURRENT_WORKFLOW="$workflow"
    fi
}

# State accessor functions
get_workflow_error() { echo "${ABADDON_WORKFLOW_ERROR:-}"; }
get_workflow_current_workflow() { echo "${ABADDON_WORKFLOW_CURRENT_WORKFLOW:-}"; }
get_workflow_current_step() { echo "${ABADDON_WORKFLOW_CURRENT_STEP:-}"; }
get_workflow_execution_time() { echo "${ABADDON_WORKFLOW_EXECUTION_TIME:-}"; }
get_workflow_steps_executed() { echo "${ABADDON_WORKFLOW_STEPS_EXECUTED:-}"; }

# Check if workflow operation succeeded
workflow_succeeded() { [[ "$ABADDON_WORKFLOW_STATUS" == "success" ]]; }
workflow_failed() { [[ "$ABADDON_WORKFLOW_STATUS" == "error" || "$ABADDON_WORKFLOW_STATUS" == "failed" || "$ABADDON_WORKFLOW_STATUS" == "step_failed" ]]; }

# ============================================================================
# Query and Information Functions
# ============================================================================

# List all workflows
list_workflows() {
    local workflows=()
    local seen_workflows=()
    
    for step_key in "${!ABADDON_WORKFLOW_STEPS[@]}"; do
        local workflow="${step_key%:*}"
        if ! array_contains "$workflow" "${seen_workflows[@]}"; then
            workflows+=("$workflow")
            seen_workflows+=("$workflow")
        fi
    done
    
    # Sort workflows
    IFS=$'\n' workflows=($(sort <<<"${workflows[*]}"))
    unset IFS
    
    printf '%s\n' "${workflows[@]}"
}

# List steps for a workflow
list_workflow_steps() {
    local workflow="$1"
    local format="${2:-name}"  # name|detailed
    
    if [[ -z "$workflow" ]]; then
        log_error "list_workflow_steps requires workflow name"
        return 1
    fi
    
    local steps=()
    for step_key in "${!ABADDON_WORKFLOW_STEPS[@]}"; do
        if [[ "$step_key" =~ ^${workflow}: ]]; then
            local step_name="${step_key#*:}"
            steps+=("$step_name")
        fi
    done
    
    if [[ ${#steps[@]} -eq 0 ]]; then
        log_warning "No steps found for workflow: $workflow"
        return 1
    fi
    
    # Sort steps
    IFS=$'\n' steps=($(sort <<<"${steps[*]}"))
    unset IFS
    
    case "$format" in
        name)
            printf '%s\n' "${steps[@]}"
            ;;
        detailed)
            printf "%-20s %-15s %-40s %-20s\n" "STEP" "STATUS" "DESCRIPTION" "DEPENDENCIES"
            printf "%-20s %-15s %-40s %-20s\n" "----" "------" "-----------" "------------"
            
            for step in "${steps[@]}"; do
                local step_key="${workflow}:${step}"
                local status="${ABADDON_WORKFLOW_STEP_STATUS[$step_key]:-pending}"
                local description="${ABADDON_WORKFLOW_DESCRIPTIONS[$step_key]:-}"
                local dependencies="${ABADDON_WORKFLOW_DEPENDENCIES[$step_key]:-none}"
                
                printf "%-20s %-15s %-40s %-20s\n" "$step" "$status" "${description:0:37}..." "$dependencies"
            done
            ;;
        *)
            log_error "Unknown format: $format"
            return 1
            ;;
    esac
}

# Get workflow statistics
get_workflow_stats() {
    if [[ "$ABADDON_WORKFLOW_REGISTRY_INITIALIZED" != "true" ]]; then
        echo "Workflow Registry: Not initialized"
        return 1
    fi
    
    local total_workflows=0
    local total_steps=0
    local total_commands=0
    
    # Count workflows
    for workflow in $(list_workflows); do
        ((total_workflows++))
    done 2>/dev/null || total_workflows=0
    
    # Count steps
    for key in "${!ABADDON_WORKFLOW_STEPS[@]}"; do
        ((total_steps++))
    done 2>/dev/null || total_steps=0
    
    # Count workflow commands
    for key in "${!ABADDON_WORKFLOW_COMMAND_MAPPING[@]}"; do
        ((total_commands++))
    done 2>/dev/null || total_commands=0
    
    echo "Workflow Registry Statistics:"
    echo "  Total Workflows: $total_workflows"
    echo "  Total Steps: $total_steps"
    echo "  Total Workflow Commands: $total_commands"
    echo "  Total Executed: $ABADDON_WORKFLOW_TOTAL_EXECUTED"
    echo "  Total Errors: $ABADDON_WORKFLOW_TOTAL_ERRORS"
    echo "  Initialization Phase: $ABADDON_WORKFLOW_INITIALIZATION_PHASE"
    echo "  Execution Phase: $ABADDON_WORKFLOW_EXECUTION_PHASE"
    echo "  Max Dependency Depth: $ABADDON_WORKFLOW_MAX_DEPTH"
    echo "  Parallel Execution: $ABADDON_WORKFLOW_ENABLE_PARALLEL"
    
    if [[ $ABADDON_WORKFLOW_TOTAL_EXECUTED -gt 0 ]]; then
        local success_rate=$(( (ABADDON_WORKFLOW_TOTAL_EXECUTED - ABADDON_WORKFLOW_TOTAL_ERRORS) * 100 / ABADDON_WORKFLOW_TOTAL_EXECUTED ))
        echo "  Success Rate: ${success_rate}%"
    fi
}

# Get execution order for workflow (cached)
get_workflow_execution_order() {
    local workflow="$1"
    
    if [[ -z "$workflow" ]]; then
        log_error "get_workflow_execution_order requires workflow name"
        return 1
    fi
    
    local cached_order="${ABADDON_WORKFLOW_EXECUTION_ORDER[$workflow]:-}"
    if [[ -n "$cached_order" ]]; then
        echo "$cached_order"
        return 0
    fi
    
    # Build and cache if not found
    build_dependency_graph "$workflow"
    echo "${ABADDON_WORKFLOW_EXECUTION_ORDER[$workflow]}"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Helper function to check if array contains value
array_contains() {
    local needle="$1"
    shift
    local haystack=("$@")
    
    for item in "${haystack[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Validate workflow system
workflow_validate() {
    local errors=0
    
    # Check core functions exist
    for func in workflow_init workflow_register_step workflow_execute build_dependency_graph register_workflow_command; do
        if ! declare -F "$func" >/dev/null; then
            log_error "Missing function: $func"
            ((errors++))
        fi
    done
    
    # Check state variables exist
    for var in ABADDON_WORKFLOW_STATUS ABADDON_WORKFLOW_STEPS ABADDON_WORKFLOW_DEPENDENCIES; do
        if ! declare -p "$var" >/dev/null 2>&1; then
            log_error "Missing state variable: $var"
            ((errors++))
        fi
    done
    
    return $errors
}

# Module information
workflow_info() {
    echo "abaddon-workflow.sh - Williams-Style Dependency Resolution & Workflow Orchestration"
    echo "Version: 1.0.0"
    echo "Functions: workflow_init, workflow_register_step, workflow_execute, register_workflow_command"
    echo "Features: Williams-style dependency resolution, command pattern integration"
    echo "Registry: ${ABADDON_WORKFLOW_REGISTRY_INITIALIZED:-false}"
    echo "Integration: state-machine.sh + command.sh for orchestration"
}

log_debug "abaddon-workflow.sh loaded successfully"