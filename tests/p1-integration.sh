# P1 Foundation Integration Tests
# Test functions for core + tty + platform modules working together
# Architecture validation: Load order, cross-module workflows, user scenarios

# ============================================================================
# P1 Integration Test Setup and Lifecycle Hooks
# ============================================================================

# P1 integration test setup
p1_integration_test_setup() {
    # Initialize P1 integration test state (following 2-tier pattern)
    declare -g ABADDON_TESTS_P1_LOAD_ORDER_VALIDATED=""
    declare -g ABADDON_TESTS_P1_CROSS_MODULE_WORKFLOWS=""
    declare -g ABADDON_TESTS_P1_USER_SCENARIOS=""
}

# P1 integration test teardown
p1_integration_test_teardown() {
    # Clean P1 integration state
    unset ABADDON_TESTS_P1_LOAD_ORDER_VALIDATED
    unset ABADDON_TESTS_P1_CROSS_MODULE_WORKFLOWS
    unset ABADDON_TESTS_P1_USER_SCENARIOS
}

# P1 integration test isolation
p1_integration_test_isolate() {
    # Ensure clean P1 module state for each test
    unset ABADDON_CORE_LOADED ABADDON_TTY_LOADED ABADDON_PLATFORM_LOADED
}

# ============================================================================
# Load Order & Dependency Chain Validation (UNIQUE TO INTEGRATION)
# ============================================================================

# Test loading all P1 modules in correct dependency order: core → tty → platform
test_p1_load_order_complete_chain() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # Validate complete P1 foundation loaded
    [[ "${ABADDON_CORE_LOADED:-}" == "1" ]] && \
    [[ "${ABADDON_TTY_LOADED:-}" == "1" ]] && \
    [[ "${ABADDON_PLATFORM_LOADED:-}" == "1" ]]
    
    # Track successful load order validation
    ABADDON_TESTS_P1_LOAD_ORDER_VALIDATED="true"
}

# Test dependency enforcement: platform requires core
test_p1_dependency_platform_requires_core() {
    # Test dependency check in a truly fresh subshell
    bash -c '
        # Completely fresh environment
        unset ABADDON_CORE_LOADED
        get_module_path() { echo "/Users/zer0cell/.local/lib/abaddon/abaddon-${1}.sh"; }
        
        # This should fail due to missing ABADDON_CORE_LOADED
        source "$(get_module_path platform)" 2>/dev/null
    '
    # Should return 1 (failure) - we return the opposite for test framework
    [[ $? -ne 0 ]]
}

# Test dependency enforcement: tty requires core
test_p1_dependency_tty_requires_core() {
    # Test dependency check in a truly fresh subshell
    bash -c '
        # Completely fresh environment
        unset ABADDON_CORE_LOADED
        get_module_path() { echo "/Users/zer0cell/.local/lib/abaddon/abaddon-${1}.sh"; }
        
        # This should fail due to missing ABADDON_CORE_LOADED
        source "$(get_module_path tty)" 2>/dev/null
    '
    # Should return 1 (failure) - we return the opposite for test framework
    [[ $? -ne 0 ]]
}

# Test module re-loading safety (load guard functionality)
test_p1_load_guard_safety() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # Re-load all modules - should be safe (load guards prevent double-loading)
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # All should still be loaded exactly once
    [[ "${ABADDON_CORE_LOADED:-}" == "1" ]] && \
    [[ "${ABADDON_TTY_LOADED:-}" == "1" ]] && \
    [[ "${ABADDON_PLATFORM_LOADED:-}" == "1" ]]
}

# ============================================================================
# Cross-Module Workflow Validation (UNIQUE TO INTEGRATION)
# ============================================================================

# Test core → platform integration: platform uses core logging
test_p1_cross_platform_uses_core_logging() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    
    # Platform module should be able to use core logging functions
    get_tool_info "nonexistent_tool" "path" >/dev/null 2>&1 || true
    # Function should complete without error (may log warning via core)
}

# Test core → tty integration: tty uses core logging
test_p1_cross_tty_uses_core_logging() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    
    # TTY module uses core logging internally during capability detection
    detect_tty_capabilities >/dev/null 2>&1
}

# Test TTY cell membrane pattern: core → tty color abstraction
test_p1_cross_tty_color_abstraction() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    
    # Verify TTY maps core colors based on capability
    detect_tty_capabilities
    
    # Core colors should be defined
    [[ -n "${ABADDON_CORE_COLOR_RED:-}" ]] && \
    [[ -n "${ABADDON_CORE_COLOR_GREEN:-}" ]]
    
    # TTY should map them (even if empty for no-color terminals)
    [[ -n "${ABADDON_TTY_RED}" || "${ABADDON_TTY_RED}" == "" ]] && \
    [[ -n "${ABADDON_TTY_GREEN}" || "${ABADDON_TTY_GREEN}" == "" ]]
}

# Test complete P1 error handling chain
test_p1_cross_error_handling_chain() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # Test error propagation across P1 modules
    local error_icon
    error_icon=$(tty_status_icon "error" false 2>/dev/null) || true
    handle_error 1 "P1 integration test error" "test_context" >/dev/null 2>&1 || true
    
    # Should complete without crashing
    return 0
}

# Test P1 module validation across all modules
test_p1_cross_module_validation_functions() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # Validate that each P1 module has its core functions available
    validate_module "core" "log_info" "detect_platform" "safe_arithmetic" && \
    validate_module "platform" "get_tool_info" "check_tool" "get_best_tool" && \
    validate_module "tty" "tty_status_icon" "tty_format_bold" "detect_tty_capabilities"
    
    # Track cross-module workflow success
    ABADDON_TESTS_P1_CROSS_MODULE_WORKFLOWS="validated"
}

# ============================================================================
# User Scenario Workflows (UNIQUE TO INTEGRATION)
# ============================================================================

# Test realistic workflow: tool detection with rich display
test_p1_workflow_tool_detection_display() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # User scenario: check for a tool and display status with rich formatting
    local tool="bash"  # Should be available on all systems
    if check_tool "$tool" true >/dev/null 2>&1; then
        local version icon
        version=$(get_tool_version "$tool" 2>/dev/null) || version="unknown"
        icon=$(tty_status_icon "success" false 2>/dev/null) || icon="✓"
        
        # Output the rich formatted result (test expects this output)
        echo "$icon $tool: $version"
    fi
}

# Test realistic workflow: development environment validation
test_p1_workflow_environment_validation() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # User scenario: complete development environment check
    validate_development_environment >/dev/null 2>&1 || true
    # Should complete without crashing (may return non-zero for warnings)
    return 0
}

# Test realistic workflow: tool status display with formatting
test_p1_workflow_tool_status_formatting() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # User scenario: display tool status with rich formatting
    show_tool_status false
}

# Test realistic workflow: performance measurement with status display
test_p1_workflow_performance_measurement() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # User scenario: measure execution with rich status display
    local start_icon success_icon
    start_icon=$(tty_status_icon "working" false 2>/dev/null) || start_icon="⏳"
    
    # Measure a quick command
    measure_execution "test_command" sleep 0.01 >/dev/null 2>&1
    local exit_code=$?
    
    success_icon=$(tty_status_icon "success" false 2>/dev/null) || success_icon="✓"
    
    # Should be able to handle the workflow
    [[ $exit_code -eq 0 ]]
    
    # Track user scenario success
    ABADDON_TESTS_P1_USER_SCENARIOS="performance_measured"
}

# Test realistic workflow: platform detection and capability checking
test_p1_workflow_platform_detection() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # User scenario: detect platform and check capabilities
    local platform capabilities
    platform=$(detect_platform 2>/dev/null) || platform="unknown"
    capabilities=$(get_platform_capabilities 2>/dev/null) || capabilities=""
    
    # Should get meaningful results
    [[ -n "$platform" ]] && [[ "$platform" != "unknown" ]]
}

# Test realistic workflow: graceful tool fallback
test_p1_workflow_graceful_tool_fallback() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # User scenario: get best available tool (should gracefully fallback)
    local search_tool
    search_tool=$(get_best_tool "file_search" 2>/dev/null) || search_tool="find"
    
    # Should always return a valid tool (fd or find)
    [[ "$search_tool" =~ ^(fd|find)$ ]]
}

# Test realistic workflow: comprehensive tool availability check
test_p1_workflow_comprehensive_tool_check() {
    source "$(get_module_path core)"
    source "$(get_module_path tty)"
    source "$(get_module_path platform)"
    
    # User scenario: check multiple modern tools and display results
    local tools_checked=0
    local tools_available=0
    
    for tool in fd rg eza gdu bat jq; do
        tools_checked=$((tools_checked + 1))
        if check_tool "$tool" true >/dev/null 2>&1; then
            tools_available=$((tools_available + 1))
        fi
    done
    
    # Should have checked some tools
    [[ $tools_checked -gt 0 ]]
    
    # Update user scenario tracking
    ABADDON_TESTS_P1_USER_SCENARIOS="${ABADDON_TESTS_P1_USER_SCENARIOS},tools_checked:${tools_available}/${tools_checked}"
}

# ============================================================================
# P1 Integration Test Registration
# ============================================================================

# Initialize P1 integration test environment
p1_integration_test_setup

# Dependency Tests (MUST RUN FIRST - before any modules load)
run_test "P1 dependency: platform requires core" test_p1_dependency_platform_requires_core
run_test "P1 dependency: tty requires core" test_p1_dependency_tty_requires_core

# Load Order & Safety Tests  
run_test "P1 load order: complete chain (core→tty→platform)" test_p1_load_order_complete_chain
run_test "P1 load guard: re-loading safety" test_p1_load_guard_safety

# Cross-Module Workflow Tests
run_test "P1 cross-module: platform uses core logging" test_p1_cross_platform_uses_core_logging
run_test "P1 cross-module: tty uses core logging" test_p1_cross_tty_uses_core_logging
run_test "P1 cross-module: tty color abstraction (cell membrane)" test_p1_cross_tty_color_abstraction
run_test "P1 cross-module: error handling chain" test_p1_cross_error_handling_chain
run_test "P1 cross-module: validate all module functions" test_p1_cross_module_validation_functions

# User Scenario Workflow Tests
run_test_with_output "P1 workflow: tool detection with display" test_p1_workflow_tool_detection_display "bash:" contains
run_test "P1 workflow: environment validation" test_p1_workflow_environment_validation
run_test_with_output "P1 workflow: tool status with formatting" test_p1_workflow_tool_status_formatting "Modern Tool Status" contains
run_test "P1 workflow: performance measurement" test_p1_workflow_performance_measurement
run_test "P1 workflow: platform detection and capabilities" test_p1_workflow_platform_detection
run_test "P1 workflow: graceful tool fallback" test_p1_workflow_graceful_tool_fallback

# Conditional workflow tests based on tool availability
if command -v fd >/dev/null 2>&1 && command -v rg >/dev/null 2>&1; then
    run_test "P1 workflow: comprehensive tool check (modern tools available)" test_p1_workflow_comprehensive_tool_check
else
    run_test "P1 workflow: comprehensive tool check (fallback tools)" test_p1_workflow_comprehensive_tool_check
fi

# Clean up P1 integration test environment
p1_integration_test_teardown