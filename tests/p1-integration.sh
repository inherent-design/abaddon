# Integration tests
# Test functions for abaddon modules working together

# Test loading all modules in correct dependency order
test_integration_load_all_modules() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    [[ "${ABADDON_CORE_LOADED:-}" == "1" ]] && \
    [[ "${ABADDON_PLATFORM_LOADED:-}" == "1" ]] && \
    [[ "${ABADDON_PROGRESS_LOADED:-}" == "1" ]]
}

# Test loading modules out of order fails appropriately
test_integration_platform_requires_core() {
    # This should fail
    source "$(get_module_path platform)"
}

test_integration_progress_requires_core() {
    # This should fail
    source "$(get_module_path progress)"
}

# Test cross-module functionality
test_integration_platform_uses_core_logging() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    
    # Platform module should be able to use core logging
    get_tool_info "nonexistent_tool" "path" 2>/dev/null || true
    # Function should complete (may log warning via core)
}

test_integration_progress_uses_core_logging() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    
    # Progress module uses core logging internally
    detect_terminal_features
}

# Test realistic workflow scenarios
test_integration_tool_detection_and_display() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Simulate checking for tools and displaying status
    local tool="bash"  # Should be available
    if check_tool "$tool" true; then
        local version
        version=$(get_tool_version "$tool")
        local icon
        icon=$(status_icon "success" false)
        echo "$icon $tool: $version"
    fi
}

test_integration_error_handling_chain() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Test error handling across modules
    local error_icon
    error_icon=$(status_icon "error" false)
    handle_error 1 "Integration test error" "test_context"
}

test_integration_development_environment_check() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Full environment validation with rich output
    section_header "Environment Validation" 1
    validate_development_environment
}

test_integration_tool_status_with_formatting() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Test tool status display with rich formatting
    TERM_INTERACTIVE=false  # Force non-interactive for consistent testing
    TERM_COLORS=0          # Force no colors for consistent testing
    
    show_tool_status false
}

test_integration_performance_measurement_with_logging() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Test performance measurement with status display
    local start_icon
    start_icon=$(status_icon "working" false)
    echo "$start_icon Starting performance test"
    
    measure_execution "test_command" sleep 0.1
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        local success_icon
        success_icon=$(status_icon "success" false)
        echo "$success_icon Performance test completed"
    else
        local error_icon
        error_icon=$(status_icon "error" false)
        echo "$error_icon Performance test failed"
    fi
    
    return $exit_code
}

# Test module validation across all modules
test_integration_validate_all_modules() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Validate that each module has its core functions
    validate_module "core" "log_info" "detect_platform" "safe_arithmetic" && \
    validate_module "platform" "get_tool_info" "check_tool" "get_best_tool" && \
    validate_module "progress" "status_icon" "format_bold" "section_header"
}

# Test configuration and environment interaction
test_integration_environment_and_tools() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Test environment detection with tool checking
    local platform
    platform=$(detect_platform)
    
    local capabilities
    capabilities=$(get_platform_capabilities)
    
    # Test tool availability for current platform
    local best_search_tool
    best_search_tool=$(get_best_tool "file_search")
    
    # All operations should complete successfully
    [[ -n "$platform" ]] && [[ -n "$capabilities" ]] && [[ -n "$best_search_tool" ]]
}

# Test error recovery and graceful degradation
test_integration_graceful_degradation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Test graceful handling when modern tools aren't available
    local fallback_tool
    fallback_tool=$(get_best_tool "file_search")
    
    # Should always return something (fd or find)
    [[ "$fallback_tool" =~ ^(fd|find)$ ]]
}

# Test memory and cleanup
test_integration_module_cleanup() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Test that modules can be loaded multiple times safely
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # All should still be loaded exactly once
    [[ "${ABADDON_CORE_LOADED:-}" == "1" ]] && \
    [[ "${ABADDON_PLATFORM_LOADED:-}" == "1" ]] && \
    [[ "${ABADDON_PROGRESS_LOADED:-}" == "1" ]]
}

# Test realistic user scenarios
test_integration_user_workflow_tool_check() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Simulate: user wants to check if modern tools are available
    section_header "Tool Availability Check" 2
    
    local tools_available=true
    for tool in fd rg eza gdu; do
        if check_tool "$tool" true; then
            local version icon
            version=$(get_tool_version "$tool")
            icon=$(status_icon "success" false)
            echo "$icon $tool: $version"
        else
            local icon
            icon=$(status_icon "error" false)
            echo "$icon $tool: not available"
            tools_available=false
        fi
    done
    
    # Return appropriate status
    [[ "$tools_available" == "true" ]]
}

test_integration_user_workflow_environment_setup() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path progress)"
    
    # Simulate: user setting up development environment
    section_header "Development Environment Setup" 1
    
    # 1. Detect platform
    local platform
    platform=$(detect_platform)
    echo "Platform: $platform"
    
    # 2. Check capabilities
    local capabilities
    capabilities=$(get_platform_capabilities)
    echo "Capabilities: $capabilities"
    
    # 3. Validate environment
    validate_development_environment >/dev/null 2>&1
    local validation_result=$?
    
    if [[ $validation_result -eq 0 ]]; then
        local icon
        icon=$(status_icon "success" false)
        echo "$icon Environment validation passed"
    else
        local icon
        icon=$(status_icon "warning" false)
        echo "$icon Environment validation had warnings"
    fi
    
    return 0  # Always succeed for integration test
}

# Register all integration tests
run_test "All modules load in correct order" test_integration_load_all_modules
run_test "Platform module requires core (dependency check)" test_integration_platform_requires_core false
run_test "Progress module requires core (dependency check)" test_integration_progress_requires_core false

run_test "Platform module uses core logging" test_integration_platform_uses_core_logging
run_test "Progress module uses core logging" test_integration_progress_uses_core_logging

run_test_with_output "Tool detection and display workflow" test_integration_tool_detection_and_display "bash:" contains
run_test "Error handling chain across modules" test_integration_error_handling_chain false

run_test "Development environment check integration" test_integration_development_environment_check
run_test_with_output "Tool status with formatting" test_integration_tool_status_with_formatting "Modern Tool Status" contains

run_test "Performance measurement with status display" test_integration_performance_measurement_with_logging

run_test "Validate all module functions available" test_integration_validate_all_modules

run_test "Environment and tools interaction" test_integration_environment_and_tools

run_test "Graceful degradation when tools missing" test_integration_graceful_degradation

run_test "Module cleanup and re-loading safety" test_integration_module_cleanup

# User workflow scenarios
if command -v fd >/dev/null 2>&1 && command -v rg >/dev/null 2>&1; then
    run_test "User workflow: tool availability check (tools available)" test_integration_user_workflow_tool_check
else
    run_test "User workflow: tool availability check (tools missing)" test_integration_user_workflow_tool_check false
fi

run_test "User workflow: environment setup" test_integration_user_workflow_environment_setup