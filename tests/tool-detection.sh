# Tool Detection module tests (v1.0.0 - Enhanced platform intelligence)
# Test functions for abaddon-tool-detection.sh

# Test module loading and dependencies
test_tool_detection_requires_core() {
    # Should fail without core loaded
    source "$(get_module_path tool-detection)"
}

test_tool_detection_requires_platform() {
    # Should fail without platform loaded
    source "$(get_module_path core)"
    source "$(get_module_path tool-detection)"
}

test_tool_detection_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    [[ "${ABADDON_TOOL_DETECTION_LOADED:-}" == "1" ]]
}

# Test package manager detection
test_tool_detection_detect_package_managers() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    local managers=($(detect_package_managers))
    # Should return array (possibly empty on minimal systems)
    [[ ${#managers[@]} -ge 0 ]]
}

test_tool_detection_rank_package_managers() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Test with some example managers
    local test_managers=("brew" "apt" "cargo")
    local ranked=($(rank_package_managers "${test_managers[@]}"))
    [[ ${#ranked[@]} -eq ${#test_managers[@]} ]]
}

# Test tool variant detection
test_tool_detection_detect_tool_variants() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    local variants=($(detect_tool_variants))
    # Should detect at least coreutils type
    [[ ${#variants[@]} -gt 0 ]]
}

test_tool_detection_get_preferred_tool_existing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Test with bash which should exist
    local preferred=$(get_preferred_tool "bash")
    [[ "$preferred" == "bash" ]] || [[ "$preferred" == "gbash" ]]
}

test_tool_detection_get_preferred_tool_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    get_preferred_tool "definitely_nonexistent_tool_12345"
}

# Test enhanced tool checking
test_tool_detection_check_tool_enhanced_bash() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Test with bash which should exist and work
    check_tool_enhanced "bash" true
}

test_tool_detection_check_tool_enhanced_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    check_tool_enhanced "definitely_nonexistent_tool_12345" true
}

test_tool_detection_get_tool_version_enhanced_bash() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    get_tool_version_enhanced "bash"
}

# Test tool capability checking
test_tool_detection_check_tool_capabilities() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Test with fd if available, otherwise skip gracefully
    if command -v fd >/dev/null 2>&1; then
        check_tool_capabilities "fd" "parallel_search"
    else
        return 1  # Expected failure - tool not available
    fi
}

test_tool_detection_check_tool_capabilities_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    check_tool_capabilities "nonexistent_tool" "some_capability"
}

# Test best tool selection with enhanced logic
test_tool_detection_get_best_tool_enhanced_file_search() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    get_best_tool_enhanced "file_search"
}

test_tool_detection_get_best_tool_enhanced_timeout() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    get_best_tool_enhanced "timeout_command"
}

test_tool_detection_get_best_tool_enhanced_unknown() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    get_best_tool_enhanced "unknown_task_12345"
}

# Test environment analysis
test_tool_detection_analyze_development_environment() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    local analysis=($(analyze_development_environment))
    # Should return some analysis data
    [[ ${#analysis[@]} -gt 0 ]]
}

# Test Flutter-doctor style reporting (non-interactive)
test_tool_detection_doctor_output() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Just test that it runs without error and produces output
    local output=$(tool_detection_doctor)
    [[ -n "$output" ]]
}

# Test modern tools status checking
test_tool_detection_check_modern_tools_status() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Should run without error
    check_modern_tools_status
}

# Test installation suggestions (safe - just output)
test_tool_detection_suggest_tool_installation_enhanced() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Test with fake missing tools
    suggest_tool_installation_enhanced "fake_tool_12345"
}

# Test state management functions
test_tool_detection_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Set some state
    ABADDON_TOOL_DETECTION_STATUS="error"
    ABADDON_TOOL_DETECTION_ERROR_MESSAGE="test error"
    # Reset and check
    clear_tool_detection_state
    [[ -z "${ABADDON_TOOL_DETECTION_STATUS}" ]] && [[ -z "${ABADDON_TOOL_DETECTION_ERROR_MESSAGE}" ]]
}

test_tool_detection_set_error_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    set_tool_detection_error "test error"
    [[ "${ABADDON_TOOL_DETECTION_STATUS}" == "error" ]] && [[ "${ABADDON_TOOL_DETECTION_ERROR_MESSAGE}" == "test error" ]]
}

test_tool_detection_set_success_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    set_tool_detection_success
    [[ "${ABADDON_TOOL_DETECTION_STATUS}" == "$ABADDON_TOOL_DETECTION_SUCCESS" ]] && [[ -z "${ABADDON_TOOL_DETECTION_ERROR_MESSAGE}" ]]
}

test_tool_detection_state_accessors() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    # Initialize some state
    detect_package_managers >/dev/null 2>&1
    [[ "$(get_tool_detection_status)" == "ready" ]]
}

test_tool_detection_success_failure_helpers() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    set_tool_detection_success
    tool_detection_succeeded && ! tool_detection_failed
}

test_tool_detection_module_validation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path tool-detection)"
    tool_detection_validate
}

# Register all tool detection tests
run_test "Tool detection module requires core module" test_tool_detection_requires_core false
run_test "Tool detection module requires platform module" test_tool_detection_requires_platform false
run_test "Tool detection module loads with dependencies" test_tool_detection_loads_with_dependencies

# Package manager detection tests
run_test "Detect package managers returns array" test_tool_detection_detect_package_managers
run_test "Rank package managers preserves count" test_tool_detection_rank_package_managers

# Tool variant detection tests
run_test "Detect tool variants finds coreutils type" test_tool_detection_detect_tool_variants
run_test "Get preferred tool existing (bash)" test_tool_detection_get_preferred_tool_existing
run_test "Get preferred tool nonexistent fails" test_tool_detection_get_preferred_tool_nonexistent false

# Enhanced tool checking tests
run_test "Check tool enhanced bash works" test_tool_detection_check_tool_enhanced_bash
run_test "Check tool enhanced nonexistent fails" test_tool_detection_check_tool_enhanced_nonexistent false
run_test_with_output "Get tool version enhanced bash" test_tool_detection_get_tool_version_enhanced_bash "bash" contains

# Tool capability tests (conditional)
if command -v fd >/dev/null 2>&1; then
    run_test "Check tool capabilities fd parallel_search" test_tool_detection_check_tool_capabilities
else
    skip_test "Check tool capabilities fd parallel_search" "fd not available"
fi
run_test "Check tool capabilities nonexistent fails" test_tool_detection_check_tool_capabilities_nonexistent false

# Best tool selection tests
run_test_with_output "Get best tool enhanced file_search" test_tool_detection_get_best_tool_enhanced_file_search "^(fd|find|gfind)$" regex
run_test_with_output "Get best tool enhanced timeout" test_tool_detection_get_best_tool_enhanced_timeout "^(timeout|gtimeout|none)$" regex
run_test "Get best tool enhanced unknown fails" test_tool_detection_get_best_tool_enhanced_unknown false

# Environment analysis tests
run_test "Analyze development environment returns data" test_tool_detection_analyze_development_environment

# Flutter-doctor style tests (output-based, safe)
run_test "Tool detection doctor produces output" test_tool_detection_doctor_output
run_test "Check modern tools status runs successfully" test_tool_detection_check_modern_tools_status
run_test "Suggest tool installation enhanced provides guidance" test_tool_detection_suggest_tool_installation_enhanced

# State management tests
run_test "Tool detection state reset clears all state variables" test_tool_detection_state_reset
run_test "Tool detection set error state stores error information" test_tool_detection_set_error_state
run_test "Tool detection set success state clears error information" test_tool_detection_set_success_state
run_test "Tool detection state accessors return correct values" test_tool_detection_state_accessors
run_test "Tool detection success/failure helpers work correctly" test_tool_detection_success_failure_helpers
run_test "Tool detection module validation passes for complete module" test_tool_detection_module_validation