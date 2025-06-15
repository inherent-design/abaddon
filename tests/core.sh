# Core Module Tests
# Test functions for abaddon-core.sh

# ============================================================================
# Core Test Lifecycle Hooks
# ============================================================================

# Core test setup
core_test_setup() {
    declare -g ABADDON_TESTS_CORE_MODULE_LOADED=""
    declare -g ABADDON_TESTS_CORE_LOGGING_VALIDATED=""
    declare -g ABADDON_TESTS_CORE_PLATFORM_VALIDATED=""
    declare -g ABADDON_TESTS_CORE_STATE_VALIDATED=""
}

# Core test teardown
core_test_teardown() {
    unset ABADDON_TESTS_CORE_MODULE_LOADED
    unset ABADDON_TESTS_CORE_LOGGING_VALIDATED
    unset ABADDON_TESTS_CORE_PLATFORM_VALIDATED
    unset ABADDON_TESTS_CORE_STATE_VALIDATED
}

# Core test isolation
core_test_isolate() {
    unset ABADDON_CORE_LOADED
}

# ============================================================================
# Module Loading Tests
# ============================================================================

# Test module loading
test_core_module_loads() {
    source "$(get_module_path core)"
    [[ "${ABADDON_CORE_LOADED:-}" == "1" ]]
}

test_core_module_guards_double_load() {
    source "$(get_module_path core)"
    local first_load="$ABADDON_CORE_LOADED"
    source "$(get_module_path core)"
    local second_load="$ABADDON_CORE_LOADED"
    [[ "$first_load" == "$second_load" ]]
}

# Test logging functions
test_core_log_info_output() {
    source "$(get_module_path core)"
    log_info "test message" 2>&1
}

test_core_log_error_output() {
    source "$(get_module_path core)"
    log_error "test error" 2>&1
}

test_core_log_success_output() {
    source "$(get_module_path core)"
    log_success "test success" 2>&1
}

test_core_log_warn_output() {
    source "$(get_module_path core)"
    log_warn "test warning" 2>&1
}

# Test platform detection
test_core_detect_platform_returns_value() {
    source "$(get_module_path core)"
    detect_platform
}

test_core_platform_capabilities_returns_list() {
    source "$(get_module_path core)"
    get_platform_capabilities
}

# Test path operations
test_core_normalize_path_home() {
    source "$(get_module_path core)"
    normalize_path "~/test"
}

test_core_normalize_path_relative() {
    source "$(get_module_path core)"
    normalize_path "./test"
}

# Test arithmetic operations
test_core_safe_arithmetic_addition() {
    source "$(get_module_path core)"
    safe_arithmetic "2 + 2"
}

test_core_safe_arithmetic_multiplication() {
    source "$(get_module_path core)"
    safe_arithmetic "6 * 7"
}

test_core_safe_arithmetic_invalid_expression() {
    source "$(get_module_path core)"
    safe_arithmetic "invalid + expression"
}

# Test string manipulation
test_core_trim_whitespace_both_ends() {
    source "$(get_module_path core)"
    trim_whitespace "  hello world  "
}

test_core_trim_whitespace_empty_string() {
    source "$(get_module_path core)"
    trim_whitespace ""
}

# Test version comparison
test_core_version_compare_equal() {
    source "$(get_module_path core)"
    version_compare "1.0.0" "1.0.0"
}

test_core_version_compare_less() {
    source "$(get_module_path core)"
    version_compare "1.0.0" "2.0.0"
}

# Test error handling
test_core_handle_error_basic() {
    source "$(get_module_path core)"
    handle_error 1 "test error" "test_context"
}

# Test environment validation
test_core_require_env_var_exists() {
    source "$(get_module_path core)"
    export TEST_VAR="test_value"
    require_env_var "TEST_VAR"
}

test_core_require_env_var_missing() {
    source "$(get_module_path core)"
    unset TEST_VAR 2>/dev/null || true
    require_env_var "TEST_VAR"
}

# Test file operations
test_core_ensure_directory_create() {
    source "$(get_module_path core)"
    local TEST_TEMP_DIR="/tmp/abaddon_test_$$"
    ensure_directory "$TEST_TEMP_DIR/test_dir"
    # Cleanup
    rm -rf "$TEST_TEMP_DIR"
}

test_core_ensure_directory_existing() {
    source "$(get_module_path core)"
    ensure_directory "/tmp"
}

# Test module validation
test_validate_core_state_module_success() {
    source "$(get_module_path core)"
    # Test with actual functions that exist
    validate_module "core" "log_info" "detect_platform"
}

test_validate_core_state_module_missing_function() {
    source "$(get_module_path core)"
    validate_module "core" "nonexistent_function"
}

# Test performance measurement
test_core_measure_execution_success() {
    source "$(get_module_path core)"
    measure_execution "test_command" echo "hello"
}

test_core_measure_execution_failure() {
    source "$(get_module_path core)"
    measure_execution "test_command" false
}

# Test state management functions
test_core_state_reset() {
    source "$(get_module_path core)"
    # Set some state
    ABADDON_CORE_PLATFORM="test"
    ABADDON_CORE_STATUS="error"
    # Reset and check
    clear_core_state
    [[ -z "${ABADDON_CORE_PLATFORM}" ]] && [[ -z "${ABADDON_CORE_STATUS}" ]]
}

test_core_set_error_state() {
    source "$(get_module_path core)"
    set_core_error "test error"
    [[ "${ABADDON_CORE_STATUS}" == "error" ]] && [[ "${ABADDON_CORE_ERROR_MESSAGE}" == "test error" ]]
}

test_core_set_success_state() {
    source "$(get_module_path core)"
    set_core_success
    [[ "${ABADDON_CORE_STATUS}" == "success" ]] && [[ -z "${ABADDON_CORE_ERROR_MESSAGE}" ]]
}

test_core_state_accessors() {
    source "$(get_module_path core)"
    detect_platform >/dev/null
    [[ -n "$(get_core_platform)" ]] && [[ "$(get_core_status)" == "success" ]]
}

test_core_success_failure_helpers() {
    source "$(get_module_path core)"
    set_core_success
    core_succeeded && ! core_failed
}

test_core_module_validation() {
    source "$(get_module_path core)"
    validate_core_state
}

# ============================================================================
# Test Registration - Called by Test Runner
# ============================================================================

register_core_tests() {
    # Module loading tests
    run_test "Core module loads successfully" test_core_module_loads
    run_test "Core module guards against double loading" test_core_module_guards_double_load

    # Logging tests
    run_test_with_output "Log info includes message" test_core_log_info_output "test message" contains
    run_test_with_output "Log error includes message" test_core_log_error_output "test error" contains
    run_test_with_output "Log success includes message" test_core_log_success_output "test success" contains
    run_test_with_output "Log warn includes message" test_core_log_warn_output "test warning" contains

    # Platform detection tests
    run_test_with_output "Platform detection returns valid platform" test_core_detect_platform_returns_value "^(macos|linux_|windows|unknown)$" regex
    run_test "Platform capabilities returns capability list" test_core_platform_capabilities_returns_list

    # Path operation tests
    run_test_with_output "Normalize path expands tilde" test_core_normalize_path_home "$HOME/test" exact
    run_test "Normalize path handles relative paths" test_core_normalize_path_relative

    # Arithmetic tests
    run_test_with_output "Safe arithmetic: 2 + 2 = 4" test_core_safe_arithmetic_addition "4" exact
    run_test_with_output "Safe arithmetic: 6 * 7 = 42" test_core_safe_arithmetic_multiplication "42" exact
    run_test "Safe arithmetic handles invalid expressions" test_core_safe_arithmetic_invalid_expression false

    # String manipulation tests
    run_test_with_output "Trim whitespace from both ends" test_core_trim_whitespace_both_ends "hello world" exact
    run_test_with_output "Trim whitespace handles empty string" test_core_trim_whitespace_empty_string "" exact

    # Version comparison tests
    run_test_with_output "Version compare equal versions" test_core_version_compare_equal "eq|le" regex
    run_test_with_output "Version compare 1.0.0 < 2.0.0" test_core_version_compare_less "le|lt" regex

    # Error handling tests
    run_test "Handle error with context" test_core_handle_error_basic false

    # Environment validation tests
    run_test "Require env var when it exists" test_core_require_env_var_exists
    run_test "Require env var fails when missing" test_core_require_env_var_missing false

    # File operation tests
    run_test "Ensure directory creates new directory" test_core_ensure_directory_create
    run_test "Ensure directory handles existing directory" test_core_ensure_directory_existing

    # Module validation tests
    run_test "Validate module with existing functions" test_validate_core_state_module_success
    run_test "Validate module fails with missing function" test_validate_core_state_module_missing_function false

    # Performance measurement tests
    run_test "Measure execution tracks successful commands" test_core_measure_execution_success
    run_test "Measure execution handles command failure" test_core_measure_execution_failure false

    # State management tests
    run_test "State reset clears all state variables" test_core_state_reset
    run_test "Set error state stores error information" test_core_set_error_state
    run_test "Set success state clears error information" test_core_set_success_state
    run_test "State accessors return correct values" test_core_state_accessors
    run_test "Success/failure helpers work correctly" test_core_success_failure_helpers
    run_test "Module validation passes for complete module" test_core_module_validation
}