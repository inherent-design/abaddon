# P3 Integration Tests - Stateful Orchestration & Boundary Management
# Test functions for P3 state machine orchestration and P2→P3 coordination

# P3 Integration Test: State machine + P2 data coordination
test_p3_state_machine_p2_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    
    # Test state machine using P2 components for validation and data
    
    # Initialize state machine
    state_machine_init "uninitialized"
    
    # Use security module for file validation
    local test_config="/tmp/test_p3_config_$$"
    echo '{"app_state": "ready"}' > "$test_config"
    
    validate_file_exists "$test_config"
    local security_status="$(get_security_status)"
    
    # Use state machine to manage initialization flow
    if [[ "$security_status" == "success" ]]; then
        transition_to_state "initialized"
        local current_state="$(get_current_state)"
        
        # Cleanup
        rm -f "$test_config"
        
        [[ "$current_state" == "initialized" ]]
    else
        # Cleanup and fail
        rm -f "$test_config"
        return 1
    fi
}

# P3 Integration Test: State machine boundary enforcement
test_p3_state_machine_boundary_enforcement() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    
    # Test state machine enforcing boundaries for P2 operations
    state_machine_init "uninitialized"
    
    # Register a boundary enforcer for initialized state
    local enforcer_called=false
    test_boundary_enforcer() {
        enforcer_called=true
        return 0
    }
    
    register_state "secure_state" "State requiring security validation"
    register_boundary_enforcer "secure_state" "test_boundary_enforcer"
    register_transition "uninitialized" "secure_state"
    
    # Transition to secure state (should call enforcer)
    transition_to_state "secure_state"
    
    # Verify boundary enforcer was called
    require_state "secure_state" "test operation"
    
    [[ "$enforcer_called" == "true" ]] && [[ "$(get_current_state)" == "secure_state" ]]
}

# P3 Integration Test: State machine + KV workflow orchestration
test_p3_state_machine_kv_workflow() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    
    # Test state machine orchestrating KV operations
    state_machine_init "uninitialized"
    
    # Create test config for KV operations
    local test_config="/tmp/test_p3_kv_workflow_$$"
    cat > "$test_config" << 'EOF'
{
  "workflow": {
    "step1": "extract_data",
    "step2": "validate_data", 
    "step3": "process_data"
  }
}
EOF
    
    # Register workflow states
    register_state "extracting" "Data extraction phase"
    register_state "validating" "Data validation phase"
    register_state "processing" "Data processing phase"
    register_state "completed" "Workflow completed"
    
    # Register transitions
    register_transition "uninitialized" "extracting"
    register_transition "extracting" "validating"
    register_transition "validating" "processing"
    register_transition "processing" "completed"
    
    # Execute workflow with state transitions
    transition_to_state "extracting"
    get_config_value "workflow.step1" "$test_config" ""
    local step1_data="$(get_kv_value)"
    
    transition_to_state "validating"
    get_config_value "workflow.step2" "$test_config" ""
    local step2_data="$(get_kv_value)"
    
    transition_to_state "processing"
    get_config_value "workflow.step3" "$test_config" ""
    local step3_data="$(get_kv_value)"
    
    transition_to_state "completed"
    
    # Cleanup
    rm -f "$test_config"
    
    # Verify workflow state progression and data extraction
    [[ "$(get_current_state)" == "completed" ]] && \
    [[ "$(get_transition_count)" == "4" ]] && \
    [[ "$step1_data" == "extract_data" ]] && \
    [[ "$step2_data" == "validate_data" ]] && \
    [[ "$step3_data" == "process_data" ]]
}

# P3 Integration Test: Cross-layer P2→P3 state coordination 
test_p3_cross_layer_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    
    # Test that P3 state machine coordinates with P2 layer properly
    
    # P2: Cache some data
    cache_store "coordination_test" "P2_cached_value"
    
    # P3: Use state machine to orchestrate access
    state_machine_init "uninitialized"
    register_state "cache_ready" "Cache is accessible"
    register_transition "uninitialized" "cache_ready"
    
    # State-dependent cache access
    transition_to_state "cache_ready"
    require_state "cache_ready" "cache_access"
    
    if state_machine_succeeded; then
        local cached_value="$(cache_get "coordination_test")"
        
        # Verify P2 data persisted and P3 state coordination works
        [[ "$(get_current_state)" == "cache_ready" ]] && \
        [[ "$cached_value" == "P2_cached_value" ]]
    else
        return 1
    fi
}

# P3 Integration Test: Error propagation and state recovery
test_p3_error_propagation_recovery() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    
    # Test state machine handling P2 errors and recovery
    state_machine_init "uninitialized"
    
    # Register error and recovery states
    register_state "processing" "Normal processing state"
    register_state "error_state" "Error recovery state"
    register_state "recovered" "Recovered from error"
    
    register_transition "uninitialized" "processing"
    register_transition "processing" "error_state"
    register_transition "error_state" "recovered"
    register_transition "uninitialized" "error_state"
    
    # Simulate P2 error (invalid file access)
    validate_file_exists "/nonexistent/file/$$"
    local security_status="$(get_security_status)"
    
    if [[ "$security_status" == "error" ]]; then
        # State machine handles error
        transition_to_state "error_state"
        set_state_machine_error "P2 security validation failed"
        
        # Attempt recovery
        clear_security_state  # P2 recovery
        transition_to_state "recovered"
        set_state_machine_success
        
        # Verify error handling and recovery
        [[ "$(get_current_state)" == "recovered" ]] && \
        [[ "$(get_state_machine_status)" != "error" ]]
    else
        # Should have detected error
        return 1
    fi
}

# P3 Integration Test: Command + State Machine Orchestration
test_p3_command_state_orchestration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    
    # Test commands + state-machine coordination
    state_machine_init "uninitialized"
    commands_init "test-orchestration"
    
    # Register command that requires specific state
    test_state_command() {
        require_state "ready" "test_operation"
        echo "command executed in ready state"
    }
    
    register_command "test" "State-dependent command" "test_state_command"
    
    # Register states and transitions
    register_state "ready" "Ready for operations"
    register_transition "uninitialized" "ready"
    
    # Execute workflow: transition → command execution
    transition_to_state "ready"
    execute_command "test" >/dev/null 2>&1
    
    [[ "$(get_current_state)" == "ready" ]] && \
    [[ "$(get_commands_status)" == "success" ]]
}

# Register P3 integration tests
run_test "P3 integration: State machine + P2 data coordination" test_p3_state_machine_p2_coordination
run_test "P3 integration: State machine boundary enforcement" test_p3_state_machine_boundary_enforcement
run_test "P3 integration: State machine + KV workflow orchestration" test_p3_state_machine_kv_workflow
run_test "P3 integration: Cross-layer P2→P3 state coordination" test_p3_cross_layer_coordination
run_test "P3 integration: Error propagation and state recovery" test_p3_error_propagation_recovery
run_test "P3 integration: Command + State Machine orchestration" test_p3_command_state_orchestration