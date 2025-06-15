# Platform module tests
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

# Test tool information functions
test_platform_get_tool_info_fd_path() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_info "fd" "path"
}

test_platform_get_tool_info_fd_description() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_info "fd" "description"
}

test_platform_get_tool_info_fd_install() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_info "fd" "install"
}

test_platform_get_tool_info_fd_capabilities() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_info "fd" "capabilities"
}

test_platform_get_tool_info_fd_all() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_info "fd" "all"
}

test_platform_get_tool_info_unknown_tool() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_info "nonexistent_tool" "path"
}

test_platform_get_tool_info_invalid_type() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_info "fd" "invalid_type"
}

# Test tool checking functions
test_platform_check_tool_existing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Test with bash which should exist
    check_tool "bash" true
}

test_platform_check_tool_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    check_tool "definitely_nonexistent_tool_12345" true
}

# Test tool version functions
test_platform_get_tool_version_bash() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_version "bash"
}

test_platform_get_tool_version_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_tool_version "definitely_nonexistent_tool_12345" || return 0
}

# Test tool capability functions
test_platform_has_capability_fd_parallel() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Only test if fd is available
    if command -v fd >/dev/null 2>&1; then
        has_capability "fd" "parallel_search"
    else
        return 1  # Tool not available
    fi
}

test_platform_has_capability_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    has_capability "nonexistent_tool" "some_capability"
}

# Test best tool selection
test_platform_get_best_tool_file_search() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_best_tool "file_search"
}

test_platform_get_best_tool_text_search() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_best_tool "text_search"
}

test_platform_get_best_tool_file_listing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_best_tool "file_listing"
}

test_platform_get_best_tool_disk_usage() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_best_tool "disk_usage"
}

test_platform_get_best_tool_file_preview() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_best_tool "file_preview"
}

test_platform_get_best_tool_json_processing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_best_tool "json_processing"
}

test_platform_get_best_tool_unknown() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    get_best_tool "unknown_task"
}

# Test tool promotion (without requiring all tools)
test_platform_check_tool_availability_available_only() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Test with only available tools
    local available_tools=()
    for tool in fd rg eza gdu; do
        if command -v "$tool" >/dev/null 2>&1; then
            available_tools+=("$tool")
        fi
    done
    
    if [[ ${#available_tools[@]} -gt 0 ]]; then
        check_tool_availability "${available_tools[@]}"
    else
        return 1  # No tools available
    fi
}

test_platform_check_tool_availability_bash_only() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Test with bash which should exist
    check_tool_availability bash
}

# Test environment validation
test_platform_validate_development_environment() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    validate_development_environment
}

# Test installation script generation
test_platform_generate_install_script() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    TEST_TEMP_DIR=1  # Enable temp directory
    local script_path="$TEST_TEMP_DIR/test_install.sh"
    generate_install_script "$script_path"
    [[ -f "$script_path" ]] && [[ -x "$script_path" ]]
}

# Test tool status display
test_platform_show_tool_status_brief() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    show_tool_status false
}

test_platform_show_tool_status_detailed() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    show_tool_status true
}

# Register all platform tests
run_test "Platform module requires core module" test_platform_requires_core false
run_test "Platform module loads with core" test_platform_loads_with_core

run_test_with_output "Get tool info fd path" test_platform_get_tool_info_fd_path "/opt/homebrew/bin/fd" exact
run_test_with_output "Get tool info fd description" test_platform_get_tool_info_fd_description "Fast file finding" exact
run_test_with_output "Get tool info fd install" test_platform_get_tool_info_fd_install "distro packages or brew" exact
run_test_with_output "Get tool info fd capabilities" test_platform_get_tool_info_fd_capabilities "parallel_search,type_filtering,ignore_patterns,json_output" exact
run_test_with_output "Get tool info fd all contains path" test_platform_get_tool_info_fd_all "Path:" contains
run_test "Get tool info unknown tool fails" test_platform_get_tool_info_unknown_tool false
run_test "Get tool info invalid type fails" test_platform_get_tool_info_invalid_type false

run_test "Check tool existing (bash)" test_platform_check_tool_existing
run_test "Check tool nonexistent fails" test_platform_check_tool_nonexistent false

run_test_with_output "Get tool version bash contains version" test_platform_get_tool_version_bash "bash" contains
run_test_with_output "Get tool version nonexistent" test_platform_get_tool_version_nonexistent "not_available" exact

# Only test fd capabilities if fd is available
if command -v fd >/dev/null 2>&1; then
    run_test "Has capability fd parallel_search" test_platform_has_capability_fd_parallel
else
    skip_test "Has capability fd parallel_search" "fd not available"
fi
run_test "Has capability nonexistent tool fails" test_platform_has_capability_nonexistent false

run_test_with_output "Best tool file_search" test_platform_get_best_tool_file_search "^(fd|find)$" regex
run_test_with_output "Best tool text_search" test_platform_get_best_tool_text_search "^(rg|grep)$" regex
run_test_with_output "Best tool file_listing" test_platform_get_best_tool_file_listing "^(eza|ls)$" regex
run_test_with_output "Best tool disk_usage" test_platform_get_best_tool_disk_usage "^(gdu|gdu-go|ncdu|du)$" regex
run_test_with_output "Best tool file_preview" test_platform_get_best_tool_file_preview "^(bat|cat)$" regex
run_test_with_output "Best tool json_processing" test_platform_get_best_tool_json_processing "^(jq|none)$" regex
run_test "Best tool unknown task fails" test_platform_get_best_tool_unknown false

# Tool availability tests (graceful)
if command -v fd >/dev/null 2>&1 && command -v rg >/dev/null 2>&1 && command -v eza >/dev/null 2>&1 && command -v gdu >/dev/null 2>&1; then
    run_test "Check tool availability (all available)" test_platform_check_tool_availability_available_only
else
    skip_test "Check tool availability (all available)" "modern tools not fully available"
fi

run_test "Check tool availability bash only" test_platform_check_tool_availability_bash_only

run_test "Validate development environment" test_platform_validate_development_environment

# Test suggestion system
test_platform_suggest_tool_installation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    # Test suggestion system with a non-existent tool
    suggest_tool_installation "nonexistent_tool_12345"
}

run_test "Suggest tool installation provides guidance" test_platform_suggest_tool_installation

run_test "Show tool status brief" test_platform_show_tool_status_brief
run_test "Show tool status detailed" test_platform_show_tool_status_detailed

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
    # Test tool availability to set state
    check_tool_availability bash >/dev/null 2>&1
    [[ -n "$(get_platform_tool_counts)" ]] && [[ "$(get_platform_status)" == "ready" ]]
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

run_test "Platform state reset clears all state variables" test_platform_state_reset
run_test "Platform set error state stores error information" test_platform_set_error_state
run_test "Platform set success state clears error information" test_platform_set_success_state
run_test "Platform state accessors return correct values" test_platform_state_accessors
run_test "Platform success/failure helpers work correctly" test_platform_success_failure_helpers
run_test "Platform module validation passes for complete module" test_platform_module_validation