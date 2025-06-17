# Workflow Tests - Williams-Style Dependency Resolution & Orchestration
# Test functions for workflow registration, dependency resolution, and execution

# Test workflow initialization
test_workflow_init() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Test workflow initialization
    workflow_init "test-context"
    
    [[ "$(get_workflow_status)" == "ready" ]]
}

# Test workflow step registration
test_workflow_register_step() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize workflow system
    workflow_init "test-register"
    
    # Define test step function
    test_step_function() {
        echo "test step executed"
        return 0
    }
    
    # Register step
    workflow_register_step "test_workflow" "step1" "test_step_function" "" "Test step description"
    
    [[ "$ABADDON_WORKFLOW_STATUS" == "step_registered" ]] && \
    [[ "$ABADDON_WORKFLOW_CURRENT_WORKFLOW" == "test_workflow" ]] && \
    [[ "$ABADDON_WORKFLOW_CURRENT_STEP" == "step1" ]]
}

# Test workflow step registration with dependencies
test_workflow_register_step_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize workflow system
    workflow_init "test-deps"
    
    # Define test step functions
    test_step_a() { echo "step a"; return 0; }
    test_step_b() { echo "step b"; return 0; }
    test_step_c() { echo "step c"; return 0; }
    
    # Register steps with dependencies
    workflow_register_step "test_workflow" "step_a" "test_step_a"
    workflow_register_step "test_workflow" "step_b" "test_step_b" "step_a"
    workflow_register_step "test_workflow" "step_c" "test_step_c" "step_a step_b"
    
    [[ "$ABADDON_WORKFLOW_STATUS" == "step_registered" ]]
}

# Test dependency graph building
test_workflow_dependency_graph() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize workflow system
    workflow_init "test-graph"
    
    # Define test step functions
    test_step_a() { echo "step a"; return 0; }
    test_step_b() { echo "step b"; return 0; }
    test_step_c() { echo "step c"; return 0; }
    
    # Register steps: c depends on b, b depends on a
    workflow_register_step "test_workflow" "step_a" "test_step_a"
    workflow_register_step "test_workflow" "step_b" "test_step_b" "step_a"
    workflow_register_step "test_workflow" "step_c" "test_step_c" "step_b"
    
    # Build dependency graph
    build_dependency_graph "test_workflow"
    local execution_order="${ABADDON_WORKFLOW_EXECUTION_ORDER[test_workflow]}"
    
    # Should be: step_a step_b step_c
    [[ "$execution_order" == "step_a step_b step_c" ]] && \
    [[ "$ABADDON_WORKFLOW_STATUS" == "graph_built" ]]
}

# Test workflow execution
test_workflow_execute() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize workflow system
    workflow_init "test-execute"
    
    # Track execution order
    declare -g TEST_EXECUTION_ORDER=""
    
    # Define test step functions that track execution
    test_step_1() {
        TEST_EXECUTION_ORDER="${TEST_EXECUTION_ORDER}1"
        return 0
    }
    
    test_step_2() {
        TEST_EXECUTION_ORDER="${TEST_EXECUTION_ORDER}2"
        return 0
    }
    
    test_step_3() {
        TEST_EXECUTION_ORDER="${TEST_EXECUTION_ORDER}3"
        return 0
    }
    
    # Register steps with dependencies: 3 depends on 2, 2 depends on 1
    workflow_register_step "test_workflow" "step_1" "test_step_1"
    workflow_register_step "test_workflow" "step_2" "test_step_2" "step_1"
    workflow_register_step "test_workflow" "step_3" "test_step_3" "step_2"
    
    # Execute workflow
    workflow_execute "test_workflow"
    
    # Verify execution succeeded and order was correct
    [[ "$ABADDON_WORKFLOW_STATUS" == "success" ]] && \
    [[ "$TEST_EXECUTION_ORDER" == "123" ]] && \
    [[ "$(get_workflow_steps_executed)" == "3" ]]
}

# Test workflow execution with complex dependencies
test_workflow_complex_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize workflow system
    workflow_init "test-complex"
    
    # Track execution order
    declare -g TEST_COMPLEX_ORDER=""
    
    # Define test step functions
    step_a() { TEST_COMPLEX_ORDER="${TEST_COMPLEX_ORDER}A"; return 0; }
    step_b() { TEST_COMPLEX_ORDER="${TEST_COMPLEX_ORDER}B"; return 0; }
    step_c() { TEST_COMPLEX_ORDER="${TEST_COMPLEX_ORDER}C"; return 0; }
    step_d() { TEST_COMPLEX_ORDER="${TEST_COMPLEX_ORDER}D"; return 0; }
    step_e() { TEST_COMPLEX_ORDER="${TEST_COMPLEX_ORDER}E"; return 0; }
    
    # Register complex dependency graph:
    # A (no deps)
    # B depends on A
    # C depends on A
    # D depends on B, C
    # E depends on D
    workflow_register_step "complex_workflow" "a" "step_a"
    workflow_register_step "complex_workflow" "b" "step_b" "a"
    workflow_register_step "complex_workflow" "c" "step_c" "a"
    workflow_register_step "complex_workflow" "d" "step_d" "b c"
    workflow_register_step "complex_workflow" "e" "step_e" "d"
    
    # Execute workflow
    workflow_execute "complex_workflow"
    
    # Verify execution succeeded and dependencies were respected
    # A must come first, E must come last, D must come after B and C
    [[ "$ABADDON_WORKFLOW_STATUS" == "success" ]] && \
    [[ "$TEST_COMPLEX_ORDER" =~ ^A ]] && \
    [[ "$TEST_COMPLEX_ORDER" =~ E$ ]] && \
    [[ "$TEST_COMPLEX_ORDER" =~ A.*B.*D ]] && \
    [[ "$TEST_COMPLEX_ORDER" =~ A.*C.*D ]]
}

# Test workflow command registration
test_workflow_command_registration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize both systems
    workflow_init "test-commands"
    commands_init "test-app"
    
    # Define test step function
    test_command_step() {
        echo "workflow command executed"
        return 0
    }
    
    # Register workflow step
    workflow_register_step "command_workflow" "execute" "test_command_step"
    
    # Register workflow command
    register_workflow_command "test-cmd" "command_workflow" "Test workflow command"
    
    # Verify command was registered
    [[ "$ABADDON_WORKFLOW_STATUS" == "command_registered" ]] && \
    command_exists "test-cmd"
}

# Test workflow error handling
test_workflow_error_handling() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize workflow system
    workflow_init "test-errors"
    
    # Define failing step function
    failing_step() {
        echo "step failed"
        return 1
    }
    
    # Register failing step
    workflow_register_step "error_workflow" "fail" "failing_step"
    
    # Execute workflow (should fail)
    if workflow_execute "error_workflow"; then
        return 1  # Should have failed
    fi
    
    # Verify failure was handled correctly
    [[ "$ABADDON_WORKFLOW_STATUS" == "failed" || "$ABADDON_WORKFLOW_STATUS" == "step_failed" ]]
}

# Test cycle detection
test_workflow_cycle_detection() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize workflow system
    workflow_init "test-cycles"
    
    # Define test step functions
    cycle_step_a() { echo "step a"; return 0; }
    cycle_step_b() { echo "step b"; return 0; }
    cycle_step_c() { echo "step c"; return 0; }
    
    # Register steps with circular dependency: a->b->c->a
    workflow_register_step "cycle_workflow" "a" "cycle_step_a" "c"
    workflow_register_step "cycle_workflow" "b" "cycle_step_b" "a"
    workflow_register_step "cycle_workflow" "c" "cycle_step_c" "b"
    
    # Try to execute workflow (should fail due to cycle)
    if workflow_execute "cycle_workflow"; then
        return 1  # Should have failed due to cycle
    fi
    
    # Verify cycle was detected
    [[ "$ABADDON_WORKFLOW_STATUS" == "error" ]] && \
    [[ "$(get_workflow_error)" == *"cycle"* ]]
}

# Test workflow with state machine integration
test_workflow_state_machine_integration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Initialize systems
    workflow_init "test-integration"
    state_machine_init "uninitialized"
    
    # Register states
    register_state "processing" "Processing workflow"
    register_state "completed" "Workflow completed"
    register_transition "uninitialized" "processing"
    register_transition "processing" "completed"
    
    # Define state-aware step function
    state_aware_step() {
        transition_to_state "processing"
        echo "processing in state: $(get_current_state)"
        transition_to_state "completed"
        return 0
    }
    
    # Register workflow step
    workflow_register_step "state_workflow" "process" "state_aware_step"
    
    # Execute workflow
    workflow_execute "state_workflow"
    
    # Verify both workflow and state machine worked
    [[ "$ABADDON_WORKFLOW_STATUS" == "success" ]] && \
    [[ "$(get_current_state)" == "completed" ]]
}

# Test workflow validation
test_workflow_validation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path command)"
    source "$(get_module_path workflow)"
    
    # Test workflow module validation
    workflow_validate
}

# Register workflow tests
run_test "Workflow: initialization" test_workflow_init
run_test "Workflow: step registration" test_workflow_register_step
run_test "Workflow: step registration with dependencies" test_workflow_register_step_with_dependencies
run_test "Workflow: dependency graph building" test_workflow_dependency_graph
run_test "Workflow: workflow execution" test_workflow_execute
run_test "Workflow: complex dependencies" test_workflow_complex_dependencies
run_test "Workflow: command registration" test_workflow_command_registration
run_test "Workflow: error handling" test_workflow_error_handling
run_test "Workflow: cycle detection" test_workflow_cycle_detection
run_test "Workflow: state machine integration" test_workflow_state_machine_integration
run_test "Workflow: module validation" test_workflow_validation