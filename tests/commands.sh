# Commands module tests
# Test functions for abaddon-commands.sh - Command Registry System

# Test module loading and dependencies
test_commands_requires_dependencies() {
    # Should fail without required modules loaded
    source "$(get_module_path commands)"
}

test_commands_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    [[ "${ABADDON_COMMANDS_LOADED:-}" == "1" ]]
}

# Test registry initialization
test_commands_init_requires_context() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Should fail without context
    commands_init >/dev/null 2>&1
}

test_commands_init_with_context() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    commands_init "test-app" >/dev/null 2>&1
    [[ "${ABADDON_COMMANDS_REGISTRY_INITIALIZED:-}" == "true" ]] && \
    [[ "${ABADDON_COMMANDS_APPLICATION_CONTEXT:-}" == "test-app" ]]
}

# Test command registration
test_commands_register_requires_init() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Should fail without initialization
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
}

test_commands_register_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        echo "test executed"
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
    
    [[ "${ABADDON_COMMANDS_STATUS:-}" == "registered" ]] && \
    [[ "${ABADDON_COMMANDS_COMMAND:-}" == "test" ]]
}

test_commands_register_with_priority() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        echo "test executed"
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" 75 >/dev/null 2>&1
    
    [[ "${ABADDON_COMMANDS_PRIORITIES[test]:-}" == "75" ]]
}

test_commands_register_duplicate_fails() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        echo "test executed"
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
    register_command "test" "Duplicate command" "test_handler" >/dev/null 2>&1
}

test_commands_register_invalid_priority() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        echo "test executed"
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" 150 >/dev/null 2>&1
}

# Test command aliases
test_commands_register_alias() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        echo "test executed"
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
    register_command_alias "t" "test" >/dev/null 2>&1
    
    [[ "${ABADDON_COMMANDS_ALIASES[t]:-}" == "test" ]]
}

test_commands_register_alias_invalid_target() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    commands_init "test-app" >/dev/null 2>&1
    register_command_alias "t" "nonexistent" >/dev/null 2>&1
}

# Test command execution
test_commands_execute_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        return 0
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
    execute_command "test" >/dev/null 2>&1
    
    [[ "${ABADDON_COMMANDS_STATUS:-}" == "success" ]]
}

test_commands_execute_with_args() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler that checks arguments
    test_handler() {
        [[ "$1" == "arg1" ]] && [[ "$2" == "arg2" ]]
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
    execute_command "test" "arg1" "arg2" >/dev/null 2>&1
    
    [[ "${ABADDON_COMMANDS_STATUS:-}" == "success" ]]
}

test_commands_execute_alias() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        return 0
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
    register_command_alias "t" "test" >/dev/null 2>&1
    execute_command "t" >/dev/null 2>&1
    
    [[ "${ABADDON_COMMANDS_STATUS:-}" == "success" ]]
}

test_commands_execute_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    commands_init "test-app" >/dev/null 2>&1
    execute_command "nonexistent" >/dev/null 2>&1
}

test_commands_execute_handler_failure() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define failing test handler
    failing_handler() {
        return 42
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "fail" "Failing command" "failing_handler" >/dev/null 2>&1
    execute_command "fail" >/dev/null 2>&1
}

# Test command existence checks
test_commands_exists_true() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        return 0
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
    
    command_exists "test"
}

test_commands_exists_false() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    commands_init "test-app" >/dev/null 2>&1
    
    command_exists "nonexistent"
}

test_commands_exists_alias() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        return 0
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test command" "test_handler" >/dev/null 2>&1
    register_command_alias "t" "test" >/dev/null 2>&1
    
    command_exists "t"
}

# Test command listing
test_commands_list_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handlers
    handler1() { return 0; }
    handler2() { return 0; }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "cmd1" "First command" "handler1" >/dev/null 2>&1
    register_command "cmd2" "Second command" "handler2" >/dev/null 2>&1
    
    local output
    output=$(list_commands)
    [[ "$output" == *"cmd1"* ]] && [[ "$output" == *"cmd2"* ]]
}

test_commands_list_without_init() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    list_commands >/dev/null 2>&1
}

# Test command info
test_commands_get_info() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        return 0
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test description" "test_handler" 80 >/dev/null 2>&1
    
    local description
    description=$(get_command_info "test" "description")
    [[ "$description" == "Test description" ]]
}

test_commands_get_info_priority() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Define test handler
    test_handler() {
        return 0
    }
    
    commands_init "test-app" >/dev/null 2>&1
    register_command "test" "Test description" "test_handler" 80 >/dev/null 2>&1
    
    local priority
    priority=$(get_command_info "test" "priority")
    [[ "$priority" == "80" ]]
}

test_commands_get_info_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    commands_init "test-app" >/dev/null 2>&1
    get_command_info "nonexistent" >/dev/null 2>&1
}

# Test state management
test_commands_reset_state() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Set some state first
    ABADDON_COMMANDS_STATUS="test_status"
    ABADDON_COMMANDS_ERROR="test_error"
    ABADDON_COMMANDS_COMMAND="test_command"
    
    reset_commands_state
    
    [[ -z "${ABADDON_COMMANDS_STATUS:-}" ]] && \
    [[ -z "${ABADDON_COMMANDS_ERROR:-}" ]] && \
    [[ -z "${ABADDON_COMMANDS_COMMAND:-}" ]]
}

test_commands_state_accessors() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    ABADDON_COMMANDS_STATUS="success"
    ABADDON_COMMANDS_ERROR="test_error"
    ABADDON_COMMANDS_COMMAND="test_cmd"
    
    [[ "$(get_commands_status)" == "success" ]] && \
    [[ "$(get_commands_error)" == "test_error" ]] && \
    [[ "$(get_commands_last_command)" == "test_cmd" ]]
}

# Test statistics
test_commands_get_stats() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    commands_init "test-app" >/dev/null 2>&1
    
    # Output the stats directly for run_test_with_output to check
    get_commands_stats
}

test_commands_stats_without_init() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    get_commands_stats >/dev/null 2>&1
}

# Test module validation
test_commands_validate_module() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    commands_validate >/dev/null 2>&1
}

test_commands_info_output() {
    source "$(get_module_path core)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path commands)"
    
    # Output the info directly for run_test_with_output to check
    commands_info
}

# Register all commands tests
run_test "Commands module requires dependencies (dependency check)" test_commands_requires_dependencies false
run_test "Commands module loads with all dependencies" test_commands_loads_with_dependencies

run_test "Commands init requires context" test_commands_init_requires_context false
run_test "Commands init with context succeeds" test_commands_init_with_context

run_test "Register command requires initialization" test_commands_register_requires_init false
run_test "Register command basic functionality" test_commands_register_basic
run_test "Register command with custom priority" test_commands_register_with_priority
run_test "Register duplicate command fails" test_commands_register_duplicate_fails false
run_test "Register command with invalid priority fails" test_commands_register_invalid_priority false

run_test "Register command alias works" test_commands_register_alias
run_test "Register alias with invalid target fails" test_commands_register_alias_invalid_target false

run_test "Execute command basic functionality" test_commands_execute_basic
run_test "Execute command with arguments" test_commands_execute_with_args
run_test "Execute command via alias" test_commands_execute_alias
run_test "Execute nonexistent command fails" test_commands_execute_nonexistent false
run_test "Execute command with handler failure" test_commands_execute_handler_failure false

run_test "Command exists returns true for registered command" test_commands_exists_true
run_test "Command exists returns false for nonexistent command" test_commands_exists_false false
run_test "Command exists returns true for alias" test_commands_exists_alias

run_test "List commands basic functionality" test_commands_list_basic
run_test "List commands without init fails" test_commands_list_without_init false

run_test "Get command info description" test_commands_get_info
run_test "Get command info priority" test_commands_get_info_priority
run_test "Get command info for nonexistent command fails" test_commands_get_info_nonexistent false

run_test "Reset commands state clears all state" test_commands_reset_state
run_test "Commands state accessors work" test_commands_state_accessors

run_test_with_output "Commands stats output includes registry info" test_commands_get_stats "Commands Registry Statistics" contains
run_test "Commands stats without init fails" test_commands_stats_without_init false

run_test "Commands module validation passes" test_commands_validate_module
run_test_with_output "Commands info output includes module name" test_commands_info_output "Command Registry System" contains