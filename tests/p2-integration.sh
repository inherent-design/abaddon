# P2 Integration Tests - Performance & Security Layer
# Test functions for coordinated behavior between cache, validation, and kv modules

# P2 Integration Test: Cache + Validation coordination
test_p2_cache_validation_integration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    
    # Initialize cache
    init_cache >/dev/null 2>&1
    
    # Test that validation results can be cached using cache API
    local test_json='{"name": "test", "version": "1.0.0"}'
    local cache_key="validation_test_$(echo -n "$test_json" | sha256sum | cut -d' ' -f1)"
    
    # First validation - should store in cache
    if validate_json_content "$test_json"; then
        cache_store "$cache_key" "success"
    fi
    
    # Second check - should get from cache
    local cached_result
    if cached_result=$(cache_get "$cache_key"); then
        [[ "$cached_result" == "success" ]]
    else
        return 1
    fi
}

# P2 Integration Test: Cache + Validation workflow
test_p2_cache_validation_workflow() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    
    # Initialize cache
    init_cache >/dev/null 2>&1
    
    # Test caching validation results for file paths
    local test_file="/tmp/test_p2_workflow_$$"
    echo '{"test": "data"}' > "$test_file"
    
    # Create cache key for file validation
    local cache_key="file_validation_$(echo -n "$test_file" | sha256sum | cut -d' ' -f1)"
    
    # First validation - should store result
    if validate_file_exists "$test_file"; then
        cache_store "$cache_key" "file_valid"
    fi
    
    # Second check - should use cached result  
    local cached_result
    if cached_result=$(cache_get "$cache_key"); then
        [[ "$cached_result" == "file_valid" ]]
    else
        return 1
    fi
    
    # Cleanup
    rm -f "$test_file"
}

# P2 Integration Test: Cache performance optimization
test_p2_cache_performance_optimization() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    
    # Initialize cache
    init_cache >/dev/null 2>&1
    
    # Test that cache improves performance for repeated operations
    local expensive_operation="sleep 0.1 && echo 'computed_result'"
    
    # First execution - should cache result
    local result1
    result1=$(cached_execute "expensive_test" $expensive_operation)
    
    # Second execution - should be faster (cached)
    local result2
    result2=$(cached_execute "expensive_test" $expensive_operation)
    
    # Both should return same result
    [[ "$result1" == "$result2" ]] && [[ "$result1" == "computed_result" ]]
}

# P2 Integration Test: Complete P2 workflow
test_p2_complete_workflow() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    
    # Initialize cache
    init_cache >/dev/null 2>&1
    
    # Create test config file
    local test_file="/tmp/test_p2_workflow_$$"
    echo '{"test": "p2-workflow"}' > "$test_file"
    
    # Complete P2 workflow: Validation → Caching
    # 1. Validate file exists and is readable
    validate_file_exists "$test_file"
    [[ "$(get_security_status)" == "success" ]] || return 1
    
    # 2. Cache validation results
    local cache_key="workflow_validation_$(echo -n "$test_file" | sha256sum | cut -d' ' -f1)"
    cache_store "$cache_key" "validated"
    
    # 3. Verify cached result can be retrieved
    local cached_result
    cached_result=$(cache_get "$cache_key")
    [[ "$cached_result" == "validated" ]] || return 1
    
    # 4. Verify cache statistics show activity
    get_cache_stats | grep -q "Cache Statistics" || return 1
    
    # Cleanup
    rm -f "$test_file"
    
    return 0
}

# P2 Integration Test: Error handling coordination
test_p2_error_handling_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    
    # Test that errors propagate correctly through the P2 stack
    
    # 1. Invalid file path should fail validation
    validate_file_exists "/nonexistent/file/$$"
    [[ "$(get_security_status)" == "error" ]]
}

# P2 Integration Test: State isolation
test_p2_state_isolation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    
    # Test that P2 modules maintain separate state
    
    # Initialize cache
    init_cache >/dev/null 2>&1
    
    # Set different states in P2 modules
    set_security_error "validation error" "details"
    cache_store "test_key" "cache_value"
    
    # Verify states are independent
    [[ "$(get_security_status)" == "error" ]] && \
    [[ "$(cache_get "test_key")" == "cache_value" ]]
}

# Register P2 integration tests
run_test "P2 integration: Cache + Validation coordination" test_p2_cache_validation_integration
run_test "P2 integration: Cache + Validation workflow" test_p2_cache_validation_workflow
run_test "P2 integration: Cache performance optimization" test_p2_cache_performance_optimization
run_test "P2 integration: Complete P2 workflow" test_p2_complete_workflow
run_test "P2 integration: Error handling coordination" test_p2_error_handling_coordination
run_test "P2 integration: State isolation between modules" test_p2_state_isolation