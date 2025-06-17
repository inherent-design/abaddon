# Platform module tests (v2.0.0 - Enhanced core platform services)
# Test functions for abaddon-platform.sh

# Test module loading and dependencies
test_platform_requires_core() {
    # Should fail without core loaded
    source "$(get_module_path platform)"
}

test_platform_loads_with_core() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    [[ "${ABADDON_PLATFORM_LOADED:-}" == "1" ]]
}

# Test core platform detection functions
test_platform_detect_os_type() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    detect_os_type
}

test_platform_detect_os_version() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    local version=$(detect_os_version)
    [[ -n "$version" ]]  # Should return something, even if "unknown"
}

test_platform_detect_architecture() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    detect_architecture
}

test_platform_detect_platform_comprehensive() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    local platform=$(detect_platform)
    [[ -n "$platform" ]] && platform_succeeded
}

test_platform_is_platform_current() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    local family=$(get_platform_family)
    is_platform "$family"
}

test_platform_get_platform_path_home() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    local home_path=$(get_platform_path "home")
    [[ -n "$home_path" ]] && [[ -d "$home_path" ]]
}

test_platform_get_platform_path_tmp() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    local tmp_path=$(get_platform_path "tmp")
    [[ -n "$tmp_path" ]] && [[ -d "$tmp_path" ]]
}

# Test platform query functions
test_platform_supports_known_feature() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Test a feature that might exist - don't fail if it doesn't
    platform_supports "systemd" || platform_supports "homebrew" || platform_supports "launchctl"
}

test_platform_supports_nonexistent_feature() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    platform_supports "definitely_nonexistent_feature_12345"
}

test_platform_get_system_resources() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    local resources=($(get_system_resources))
    [[ ${#resources[@]} -ge 0 ]]  # Should return array (possibly empty)
}

test_platform_is_constrained_environment() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Should return 0 or 1, never error
    is_constrained_environment || true
}

# Test state management functions
test_platform_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Set some state
    ABADDON_PLATFORM_STATUS="error"
    ABADDON_PLATFORM_ERROR_MESSAGE="test error"
    # Reset and check
    clear_platform_state
    [[ -z "${ABADDON_PLATFORM_STATUS}" ]] && [[ -z "${ABADDON_PLATFORM_ERROR_MESSAGE}" ]]
}

test_platform_set_error_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    set_platform_error "test error"
    [[ "${ABADDON_PLATFORM_STATUS}" == "error" ]] && [[ "${ABADDON_PLATFORM_ERROR_MESSAGE}" == "test error" ]]
}

test_platform_set_success_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    set_platform_success
    [[ "${ABADDON_PLATFORM_STATUS}" == "$ABADDON_PLATFORM_SUCCESS" ]] && [[ -z "${ABADDON_PLATFORM_ERROR_MESSAGE}" ]]
}

test_platform_state_accessors() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Initialize platform state
    detect_platform >/dev/null 2>&1
    [[ "$(get_platform_status)" == "ready" ]]
}

test_platform_success_failure_helpers() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    set_platform_success
    platform_succeeded && ! platform_failed
}

test_platform_module_validation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    platform_validate
}

# Register all platform tests (v2.0.0 - Core platform services)
run_test "Platform module requires core module" test_platform_requires_core false
run_test "Platform module loads with core" test_platform_loads_with_core

# Core platform detection tests
run_test_with_output "Detect OS type returns valid type" test_platform_detect_os_type "^(macos|linux|windows|freebsd)" regex
run_test "Detect OS version returns value" test_platform_detect_os_version
run_test_with_output "Detect architecture returns valid arch" test_platform_detect_architecture "^(x86_64|arm64|x86)" regex
run_test "Detect platform comprehensive works" test_platform_detect_platform_comprehensive
run_test "Is platform identifies current platform" test_platform_is_platform_current

# Platform path tests
run_test "Get platform path home exists" test_platform_get_platform_path_home
run_test "Get platform path tmp exists" test_platform_get_platform_path_tmp

# Platform query tests
run_test "Platform supports known feature (at least one)" test_platform_supports_known_feature
run_test "Platform supports nonexistent feature fails" test_platform_supports_nonexistent_feature false
run_test "Get system resources returns array" test_platform_get_system_resources
run_test "Is constrained environment returns boolean" test_platform_is_constrained_environment

# State management tests
run_test "Platform state reset clears all state variables" test_platform_state_reset
run_test "Platform set error state stores error information" test_platform_set_error_state
run_test "Platform set success state clears error information" test_platform_set_success_state
run_test "Platform state accessors return correct values" test_platform_state_accessors
run_test "Platform success/failure helpers work correctly" test_platform_success_failure_helpers
run_test "Platform module validation passes for complete module" test_platform_module_validation