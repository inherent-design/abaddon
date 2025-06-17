# State Machine module tests
# Test functions for abaddon-state-machine.sh - Generic runtime boundary management

# Test module loading and dependencies
test_state_machine_requires_dependencies() {
    # Should fail without required modules loaded
    source "$(get_module_path state-machine)"
}

test_state_machine_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    [[ "${ABADDON_STATE_MACHINE_LOADED:-}" == "1" ]]
}

# Test state machine state management
test_state_machine_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Set some state first
    ABADDON_STATE_MACHINE_CURRENT_STATE="test_state"
    ABADDON_STATE_MACHINE_TRANSITION_COUNT=5
    
    clear_state_machine_state
    
    [[ -z "${ABADDON_STATE_MACHINE_CURRENT_STATE:-}" ]] && \
    [[ "${ABADDON_STATE_MACHINE_TRANSITION_COUNT:-}" == "0" ]]
}

# Test basic initialization
test_state_machine_basic_init() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "initialized"
    
    [[ "$(get_current_state)" == "initialized" ]] && \
    [[ "$(get_state_machine_status)" == "ready" ]]
}

test_state_machine_default_init() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init
    
    [[ "$(get_current_state)" == "uninitialized" ]] && \
    [[ "$(get_state_machine_status)" == "ready" ]]
}

# Test state registration
test_state_machine_register_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    register_state "test_state" "Test state for testing"
    
    # Check if state was registered (in the associative array)
    [[ -n "${ABADDON_STATE_MACHINE_VALID_STATES[test_state]:-}" ]]
}

test_state_machine_register_state_invalid_name() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Should fail with invalid state name
    register_state "invalid-state-name!" "Invalid state"
}

test_state_machine_register_state_missing_name() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Should fail without state name
    register_state ""
}

# Test transition registration
test_state_machine_register_transition() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    register_state "state_a" "State A"
    register_state "state_b" "State B"
    register_transition "state_a" "state_b"
    
    # Check if transition was registered
    [[ -n "${ABADDON_STATE_MACHINE_VALID_TRANSITIONS[state_a->state_b]:-}" ]]
}

test_state_machine_register_transition_unregistered_states() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Should fail with unregistered states
    register_transition "nonexistent_a" "nonexistent_b"
}

# Test state transitions
test_state_machine_valid_transition() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "uninitialized"
    transition_to_state "initialized"
    
    [[ "$(get_current_state)" == "initialized" ]] && \
    [[ "$(get_previous_state)" == "uninitialized" ]] && \
    [[ "$(get_transition_count)" == "1" ]]
}

test_state_machine_invalid_transition() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Create states without transition between them
    register_state "isolated_a" "Isolated state A"
    register_state "isolated_b" "Isolated state B"
    
    state_machine_init "isolated_a"
    
    # Should fail - no transition registered
    transition_to_state "isolated_b"
}

test_state_machine_transition_to_same_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "initialized"
    transition_to_state "initialized"
    
    # Should succeed but not increment counter
    [[ "$(get_current_state)" == "initialized" ]] && \
    [[ "$(get_transition_count)" == "0" ]]
}

test_state_machine_forced_transition() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Create states without transition between them
    register_state "isolated_a" "Isolated state A"
    register_state "isolated_b" "Isolated state B"
    
    state_machine_init "isolated_a"
    
    # Should succeed with force=true
    transition_to_state "isolated_b" "true"
    
    [[ "$(get_current_state)" == "isolated_b" ]]
}

# Test boundary enforcement
test_state_machine_require_state_success() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "initialized"
    require_state "initialized" "test operation"
}

test_state_machine_require_state_failure() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "uninitialized"
    require_state "initialized" "test operation"
}

test_state_machine_require_any_state_success() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "initialized"
    require_any_state "test operation" "uninitialized" "initialized" "error"
}

test_state_machine_require_any_state_failure() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    register_state "other_state" "Other state"
    state_machine_init "other_state"
    require_any_state "test operation" "uninitialized" "initialized"
}

# Test state checking functions
test_state_machine_is_in_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "initialized"
    
    is_in_state "initialized" && ! is_in_state "uninitialized"
}

test_state_machine_is_in_any_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "initialized"
    
    is_in_any_state "uninitialized" "initialized" "error" && \
    ! is_in_any_state "error" "uninitialized"
}

# Test state accessor functions
test_state_machine_get_current_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "test_state"
    
    [[ "$(get_current_state)" == "test_state" ]]
}

test_state_machine_get_previous_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "uninitialized"
    transition_to_state "initialized"
    
    [[ "$(get_previous_state)" == "uninitialized" ]]
}

test_state_machine_get_transition_count() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "uninitialized"
    transition_to_state "initialized"
    transition_to_state "error"
    
    [[ "$(get_transition_count)" == "2" ]]
}

# Test validator registration and execution
test_state_machine_register_validator() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Create a test validator function
    test_validator() { return 0; }
    
    register_state "validated_state" "State with validator"
    register_state_validator "validated_state" "test_validator"
    
    # Check if validator was registered
    [[ "${ABADDON_STATE_MACHINE_STATE_VALIDATORS[validated_state]:-}" == "test_validator" ]]
}

test_state_machine_validator_execution() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Create a test validator that succeeds
    test_validator_success() { return 0; }
    
    # Initialize first, then register additional states and transitions
    state_machine_init "uninitialized"
    register_state "validated_state" "State with validator"
    register_state_validator "validated_state" "test_validator_success"
    register_transition "uninitialized" "validated_state"
    
    # Should succeed with passing validator
    transition_to_state "validated_state"
    
    [[ "$(get_current_state)" == "validated_state" ]]
}

test_state_machine_validator_failure() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Create a test validator that fails
    test_validator_failure() { return 1; }
    
    register_state "validated_state" "State with failing validator"
    register_state_validator "validated_state" "test_validator_failure"
    
    state_machine_init "uninitialized"
    register_transition "uninitialized" "validated_state"
    
    # Should fail with failing validator
    transition_to_state "validated_state"
}

# Test boundary enforcer registration and execution
test_state_machine_register_boundary_enforcer() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Create a test enforcer function
    test_enforcer() { return 0; }
    
    register_state "enforced_state" "State with boundary enforcer"
    register_boundary_enforcer "enforced_state" "test_enforcer"
    
    # Check if enforcer was registered
    [[ "${ABADDON_STATE_MACHINE_BOUNDARY_ENFORCERS[enforced_state]:-}" == "test_enforcer" ]]
}

test_state_machine_boundary_enforcer_execution() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Create a test enforcer that succeeds
    test_enforcer_success() { return 0; }
    
    register_state "enforced_state" "State with boundary enforcer"
    register_boundary_enforcer "enforced_state" "test_enforcer_success"
    
    state_machine_init "enforced_state"
    
    # Should succeed with passing enforcer
    require_state "enforced_state" "test operation"
}

test_state_machine_boundary_enforcer_failure() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Create a test enforcer that fails
    test_enforcer_failure() { return 1; }
    
    register_state "enforced_state" "State with failing boundary enforcer"
    register_boundary_enforcer "enforced_state" "test_enforcer_failure"
    
    state_machine_init "enforced_state"
    
    # Should fail with failing enforcer
    require_state "enforced_state" "test operation"
}

# Test list functions
test_state_machine_list_states() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init  # Creates default states
    register_state "custom_state" "Custom state"
    
    local states_output
    states_output=$(list_states)
    
    # Should contain default and custom states
    echo "$states_output" | grep -q "uninitialized" && \
    echo "$states_output" | grep -q "initialized" && \
    echo "$states_output" | grep -q "custom_state"
}

test_state_machine_list_transitions() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init  # Creates default transitions
    register_state "custom_a" "Custom state A"
    register_state "custom_b" "Custom state B"
    register_transition "custom_a" "custom_b"
    
    local transitions_output
    transitions_output=$(list_transitions)
    
    # Should contain default and custom transitions
    echo "$transitions_output" | grep -q "uninitialized->initialized" && \
    echo "$transitions_output" | grep -q "custom_a->custom_b"
}

# Test statistics and validation
test_state_machine_stats_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    declare -F get_state_machine_stats >/dev/null
}

test_state_machine_stats_output() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init "initialized"
    
    # Output the stats directly for run_test_with_output to check
    get_state_machine_stats
}

test_state_machine_validate_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    declare -F state_machine_validate >/dev/null
}

test_state_machine_validate_success() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init
    state_machine_validate
}

test_state_machine_info_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    declare -F state_machine_info >/dev/null
}

test_state_machine_info_output() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    state_machine_init
    
    # Output the info directly for run_test_with_output to check
    state_machine_info
}

# Test error handling
test_state_machine_set_error_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    set_state_machine_error "test error message"
    
    [[ "$(get_state_machine_status)" == "error" ]] && \
    [[ "$(get_state_machine_error)" == "test error message" ]]
}

test_state_machine_set_success_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    set_state_machine_error "test error"
    set_state_machine_success
    
    # Check internal status variable matches success constant
    [[ "$ABADDON_STATE_MACHINE_STATUS" == "success" ]] && \
    [[ -z "$(get_state_machine_error)" ]]
}

# Test success/failure check functions
test_state_machine_succeeded_function() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    set_state_machine_success
    state_machine_succeeded
}

test_state_machine_failed_function() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    set_state_machine_error "test error"
    state_machine_failed
}

# Test strict mode behavior
test_state_machine_strict_mode_enabled() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Default should be strict mode enabled
    [[ "$ABADDON_STATE_MACHINE_STRICT_MODE" == "true" ]]
}

test_state_machine_strict_mode_disabled() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path state-machine)"
    
    # Disable strict mode
    ABADDON_STATE_MACHINE_STRICT_MODE="false"
    
    # Create states without transition between them
    register_state "isolated_a" "Isolated state A"
    register_state "isolated_b" "Isolated state B"
    
    state_machine_init "isolated_a"
    
    # Should succeed in non-strict mode
    transition_to_state "isolated_b"
    
    [[ "$(get_current_state)" == "isolated_b" ]]
}

# Register all state machine tests
run_test "State machine module requires dependencies (dependency check)" test_state_machine_requires_dependencies false
run_test "State machine module loads with all dependencies" test_state_machine_loads_with_dependencies

run_test "State machine state reset clears all state" test_state_machine_state_reset
run_test "State machine basic initialization works" test_state_machine_basic_init
run_test "State machine default initialization" test_state_machine_default_init

run_test "State machine register state works" test_state_machine_register_state
run_test "State machine register state fails with invalid name" test_state_machine_register_state_invalid_name false
run_test "State machine register state fails without name" test_state_machine_register_state_missing_name false

run_test "State machine register transition works" test_state_machine_register_transition
run_test "State machine register transition fails with unregistered states" test_state_machine_register_transition_unregistered_states false

run_test "State machine valid transition works" test_state_machine_valid_transition
run_test "State machine invalid transition fails" test_state_machine_invalid_transition false
run_test "State machine transition to same state works" test_state_machine_transition_to_same_state
run_test "State machine forced transition bypasses validation" test_state_machine_forced_transition

run_test "State machine require state succeeds with correct state" test_state_machine_require_state_success
run_test "State machine require state fails with wrong state" test_state_machine_require_state_failure false
run_test "State machine require any state succeeds" test_state_machine_require_any_state_success
run_test "State machine require any state fails" test_state_machine_require_any_state_failure false

run_test "State machine is in state check works" test_state_machine_is_in_state
run_test "State machine is in any state check works" test_state_machine_is_in_any_state

run_test "State machine get current state works" test_state_machine_get_current_state
run_test "State machine get previous state works" test_state_machine_get_previous_state
run_test "State machine get transition count works" test_state_machine_get_transition_count

run_test "State machine register validator works" test_state_machine_register_validator
run_test "State machine validator execution succeeds" test_state_machine_validator_execution
run_test "State machine validator failure blocks transition" test_state_machine_validator_failure false

run_test "State machine register boundary enforcer works" test_state_machine_register_boundary_enforcer
run_test "State machine boundary enforcer execution succeeds" test_state_machine_boundary_enforcer_execution
run_test "State machine boundary enforcer failure blocks operation" test_state_machine_boundary_enforcer_failure false

run_test "State machine list states works" test_state_machine_list_states
run_test "State machine list transitions works" test_state_machine_list_transitions

run_test "State machine stats function exists" test_state_machine_stats_function_exists
run_test_with_output "State machine stats output includes statistics header" test_state_machine_stats_output "State Machine Statistics" contains

run_test "State machine validate function exists" test_state_machine_validate_function_exists
run_test "State machine module validation passes" test_state_machine_validate_success

run_test "State machine info function exists" test_state_machine_info_function_exists
run_test_with_output "State machine info output includes module name" test_state_machine_info_output "abaddon-state-machine.sh" contains

run_test "State machine set error state works" test_state_machine_set_error_state
run_test "State machine set success state works" test_state_machine_set_success_state

run_test "State machine succeeded returns true for success" test_state_machine_succeeded_function
run_test "State machine failed returns true for error" test_state_machine_failed_function

run_test "State machine strict mode enabled by default" test_state_machine_strict_mode_enabled
run_test "State machine strict mode disabled allows invalid transitions" test_state_machine_strict_mode_disabled