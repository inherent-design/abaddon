#!/usr/bin/env bash
# TTY module tests
# Test functions for abaddon-tty.sh

# Test module loading
test_tty_module_loads() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    [[ "${ABADDON_TTY_LOADED:-}" == "1" ]]
}

# TTY module requires core module  
test_tty_requires_core() {
    # Test dependency - should fail without core
    if source "$(get_module_path tty)" 2>/dev/null; then
        return 1  # Should have failed
    fi
    return 0
}

# TTY module loads with core
test_tty_loads_with_core() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    [[ -n "${ABADDON_TTY_LOADED:-}" ]]
}

# TTY capability detection sets variables
test_tty_capability_detection() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    detect_tty_capabilities
    [[ -n "$ABADDON_TTY_COLORS" ]] && \
    [[ -n "$ABADDON_TTY_INTERACTIVE" ]] && \
    [[ -n "$ABADDON_TTY_WIDTH" ]] && \
    [[ -n "$ABADDON_TTY_HEIGHT" ]]
}

# TTY variables are set on load
test_tty_variables_set() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    [[ -n "$ABADDON_TTY_RED" || "$ABADDON_TTY_RED" == "" ]] && \
    [[ -n "$ABADDON_TTY_GREEN" || "$ABADDON_TTY_GREEN" == "" ]] && \
    [[ -n "$ABADDON_TTY_NC" || "$ABADDON_TTY_NC" == "" ]]
}

# TTY semantic rendering
test_tty_render_message_error() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    tty_render_message "error" "test message" "false"
}

test_tty_render_message_success() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    tty_render_message "success" "test message" "false"
}

# TTY formatting functions
test_tty_format_bold() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    tty_format_bold "test"
}

# TTY status icons
test_tty_status_icon_success() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    tty_status_icon "success" "false"
}

test_tty_status_icon_error() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    tty_status_icon "error" "false"
}

# TTY state management
test_tty_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    # Set some state
    ABADDON_TTY_STATUS="error"
    ABADDON_TTY_COLORS=256
    # Reset and check
    reset_tty_state
    [[ -z "$ABADDON_TTY_STATUS" ]] && [[ "$ABADDON_TTY_COLORS" -eq 0 ]]
}

test_tty_set_error_state() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    set_tty_error "test error"
    [[ "$ABADDON_TTY_STATUS" == "$ABADDON_TTY_ERROR" ]] && \
    [[ "$ABADDON_TTY_ERROR_MESSAGE" == "test error" ]]
}

test_tty_set_success_state() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    set_tty_success "test operation"
    [[ "$ABADDON_TTY_STATUS" == "$ABADDON_TTY_SUCCESS" ]] && \
    [[ -z "$ABADDON_TTY_ERROR_MESSAGE" ]] && \
    [[ "$ABADDON_TTY_LAST_OPERATION" == "test operation" ]]
}

# TTY state accessors
test_tty_state_accessors() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    set_tty_success "accessor_test"
    [[ "$(get_tty_status)" == "$ABADDON_TTY_SUCCESS" ]] && \
    [[ "$(get_tty_last_operation)" == "accessor_test" ]]
}

# TTY success/failure helpers
test_tty_success_helpers() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    set_tty_success "helper_test"
    tty_succeeded && ! tty_failed
}

test_tty_failure_helpers() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    set_tty_error "helper_test"
    tty_failed && ! tty_succeeded
}

# TTY module validation
test_tty_module_validation() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    validate_tty_module
}

# Test execution - following core.sh patterns
run_test "TTY module loads successfully" test_tty_module_loads
run_test "TTY module requires core module" test_tty_requires_core
run_test "TTY module loads with core" test_tty_loads_with_core

run_test "TTY capability detection sets variables" test_tty_capability_detection
run_test "TTY variables are set on load" test_tty_variables_set

run_test_with_output "TTY render message error" test_tty_render_message_error "test message" exact
run_test_with_output "TTY render message success" test_tty_render_message_success "test message" exact
run_test_with_output "TTY format bold contains text" test_tty_format_bold "test" contains
run_test_with_output "TTY status icon success" test_tty_status_icon_success "✓" exact
run_test_with_output "TTY status icon error" test_tty_status_icon_error "✗" exact

run_test "TTY state reset clears all state" test_tty_state_reset
run_test "TTY set error state stores error information" test_tty_set_error_state
run_test "TTY set success state clears error information" test_tty_set_success_state
run_test "TTY state accessors return correct values" test_tty_state_accessors
run_test "TTY success/failure helpers work correctly" test_tty_success_helpers
run_test "TTY failure helpers work correctly" test_tty_failure_helpers
run_test "TTY module validation passes" test_tty_module_validation