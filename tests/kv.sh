# KV module tests
# Test functions for abaddon-kv.sh - Enhanced Key/Value Abstraction Layer

# Test module loading and dependencies
test_kv_requires_dependencies() {
    # Should fail without required modules loaded
    source "$(get_module_path kv)"
}

test_kv_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    [[ "${ABADDON_KV_LOADED:-}" == "1" ]]
}

# Test KV state management
test_kv_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Set some state first
    ABADDON_KV_VALUE="test value"
    ABADDON_KV_STATUS="success"
    ABADDON_KV_FORMAT="json"
    ABADDON_KV_TOOL="jq"
    
    clear_kv_state
    
    [[ -z "${ABADDON_KV_VALUE:-}" ]] && \
    [[ -z "${ABADDON_KV_STATUS:-}" ]] && \
    [[ -z "${ABADDON_KV_FORMAT:-}" ]] && \
    [[ -z "${ABADDON_KV_TOOL:-}" ]]
}

test_kv_set_error_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    clear_kv_state
    set_kv_error "test error message"
    
    [[ "${ABADDON_KV_STATUS:-}" == "error" ]] && \
    [[ "${ABADDON_KV_VALUE:-}" == "test error message" ]]
}

test_kv_set_success_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    clear_kv_state
    set_kv_success "success value"
    
    [[ "${ABADDON_KV_STATUS:-}" == "success" ]] && \
    [[ "${ABADDON_KV_VALUE:-}" == "success value" ]]
}

# Test tool detection via Platform
test_kv_platform_tool_detection() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Test that Platform's tool detection is available
    declare -F get_best_tool >/dev/null && declare -F check_tool >/dev/null
}

test_kv_get_tool_for_format_json() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    if command -v jq >/dev/null 2>&1; then
        local tool
        tool=$(get_tool_for_format "json")
        [[ "$tool" == "jq" ]]
    else
        ! get_tool_for_format "json" >/dev/null 2>&1
    fi
}

test_kv_get_tool_for_format_yaml() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    if command -v yq >/dev/null 2>&1; then
        local tool
        tool=$(get_tool_for_format "yaml")
        [[ "$tool" == "yq" ]]
    else
        ! get_tool_for_format "yaml" >/dev/null 2>&1
    fi
}

test_kv_get_tool_for_format_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    get_tool_for_format "invalid_format" >/dev/null 2>&1
}

# Test file format detection
test_kv_detect_format_json() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Create test JSON file
    local test_file="/tmp/test_kv_format_$$"
    echo '{"name": "test"}' > "$test_file"
    
    detect_file_format "$test_file" >/dev/null 2>&1
    local result=$?
    local format="${ABADDON_KV_FORMAT:-}"
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$format" == "json" ]]
}

test_kv_detect_format_yaml() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Create test YAML file
    local test_file="/tmp/test_kv_format_$$"
    cat > "$test_file" << 'EOF'
name: test
version: 1.0
EOF
    
    detect_file_format "$test_file" >/dev/null 2>&1
    local result=$?
    local format="${ABADDON_KV_FORMAT:-}"
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$format" == "yaml" ]]
}

test_kv_detect_format_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    detect_file_format "/nonexistent/file/$$" >/dev/null 2>&1
}

# Test cached extraction
test_kv_execute_cached_extraction_json() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test JSON file
    local test_file="/tmp/test_kv_extract_$$"
    echo '{"project": {"name": "test-project"}}' > "$test_file"
    
    # Initialize required state
    clear_kv_state
    detect_file_format "$test_file" >/dev/null 2>&1
    
    execute_cached_extraction "$test_file" "project.name" "default" >/dev/null 2>&1
    local result=$?
    local value="${ABADDON_KV_VALUE:-}"
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$value" == "test-project" ]]
}

test_kv_execute_cached_extraction_with_default() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test JSON file without the requested key
    local test_file="/tmp/test_kv_extract_$$"
    echo '{"project": {}}' > "$test_file"
    
    # Initialize required state
    clear_kv_state
    detect_file_format "$test_file" >/dev/null 2>&1
    
    execute_cached_extraction "$test_file" "project.missing" "default_value" >/dev/null 2>&1
    local result=$?
    local value="${ABADDON_KV_VALUE:-}"
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$value" == "default_value" ]]
}

# Test main KV interface
test_kv_get_config_value_json() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config file
    local test_file="/tmp/test_config_$$"
    cat > "$test_file" << 'EOF'
{
  "app": {
    "name": "my-app",
    "version": "1.2.3"
  },
  "database": {
    "host": "localhost",
    "port": 5432
  }
}
EOF
    
    get_config_value "app.name" "$test_file" "default" >/dev/null 2>&1
    local result=$?
    local value
    value=$(get_kv_value)
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$value" == "my-app" ]]
}

test_kv_get_config_value_yaml() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if yq not available
    if ! command -v yq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test YAML config file
    local test_file="/tmp/test_config_$$"
    cat > "$test_file" << 'EOF'
app:
  name: my-yaml-app
  version: 2.0.0
database:
  host: localhost
  port: 3306
EOF
    
    get_config_value "app.name" "$test_file" "default" >/dev/null 2>&1
    local result=$?
    local value
    value=$(get_kv_value)
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$value" == "my-yaml-app" ]]
}

test_kv_get_config_value_missing_file() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    get_config_value "app.name" "/nonexistent/file/$$" "default" >/dev/null 2>&1
}

test_kv_get_config_value_missing_key() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config file
    local test_file="/tmp/test_config_$$"
    echo '{"app": {"name": "test"}}' > "$test_file"
    
    get_config_value "app.missing" "$test_file" "default_value" >/dev/null 2>&1
    local result=$?
    local value
    value=$(get_kv_value)
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$value" == "default_value" ]]
}

# Test key existence checking
test_kv_key_exists_present() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config file
    local test_file="/tmp/test_config_$$"
    echo '{"app": {"name": "test"}}' > "$test_file"
    
    kv_key_exists "app.name" "$test_file" >/dev/null 2>&1
    local result=$?
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]]
}

test_kv_key_exists_missing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config file
    local test_file="/tmp/test_config_$$"
    echo '{"app": {}}' > "$test_file"
    
    # Missing key should return false (exit code 1)
    kv_key_exists "app.missing" "$test_file" >/dev/null 2>&1
    local result=$?
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 1 ]]
}

# Test batch operations
test_kv_get_config_values_batch() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config file
    local test_file="/tmp/test_config_$$"
    cat > "$test_file" << 'EOF'
{
  "app": {
    "name": "test-app",
    "version": "1.0.0"
  }
}
EOF
    
    get_config_values "$test_file" "app.name" "app.version" >/dev/null 2>&1
    local result=$?
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]]
}

test_kv_get_config_values_mixed_results() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config file
    local test_file="/tmp/test_config_$$"
    echo '{"app": {"name": "test"}}' > "$test_file"
    
    # Mix existing and missing keys
    get_config_values "$test_file" "app.name" "app.missing" >/dev/null 2>&1
    # Should handle mixed results appropriately
    
    # Cleanup
    rm -f "$test_file"
}

# Test config file validation
test_kv_validate_config_file_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Create valid JSON config file
    local test_file="/tmp/test_config_$$"
    echo '{"name": "test", "version": "1.0"}' > "$test_file"
    
    validate_config_file "$test_file" >/dev/null 2>&1
    local result=$?
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]]
}

test_kv_validate_config_file_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Create invalid JSON config file
    local test_file="/tmp/test_config_$$"
    echo '{"name": "test", "version":}' > "$test_file"
    
    ! validate_config_file "$test_file" >/dev/null 2>&1
    local result=$?
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]]
}

# Test state accessor functions
test_kv_get_status() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    set_kv_success "test"
    local status
    status=$(get_kv_status)
    
    [[ "$status" == "success" ]]
}

test_kv_get_value() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    set_kv_success "test_value"
    local value
    value=$(get_kv_value)
    
    [[ "$value" == "test_value" ]]
}

test_kv_get_format() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    ABADDON_KV_FORMAT="json"
    local format
    format=$(get_kv_format)
    
    [[ "$format" == "json" ]]
}

test_kv_get_tool() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    ABADDON_KV_TOOL="jq"
    local tool
    tool=$(get_kv_tool)
    
    [[ "$tool" == "jq" ]]
}

test_kv_succeeded() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    set_kv_success "test"
    kv_succeeded
}

test_kv_failed() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    set_kv_error "test error"
    kv_failed
}

test_kv_succeeded_false_on_error() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    set_kv_error "test error"
    kv_succeeded
    local result=$?
    [[ $result -eq 1 ]]  # Should return false (exit code 1)
}

test_kv_failed_false_on_success() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    set_kv_success "test"
    kv_failed
    local result=$?
    [[ $result -eq 1 ]]  # Should return false (exit code 1)
}

# Test statistics
test_kv_get_stats() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Perform some operations to generate stats
    if command -v jq >/dev/null 2>&1; then
        local test_file="/tmp/test_stats_$$"
        echo '{"name": "test"}' > "$test_file"
        
        get_config_value "name" "$test_file" "default" >/dev/null 2>&1
        
        # Cleanup
        rm -f "$test_file"
        
        # Output the stats directly for run_test_with_output to check
        get_kv_stats
    else
        return 0  # Skip if jq not available
    fi
}

# Test module validation
test_kv_validate_module() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    kv_validate >/dev/null 2>&1
}

test_kv_info_output() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Output the info directly for run_test_with_output to check
    kv_info
}

# Test complex scenarios
test_kv_array_access() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config with array
    local test_file="/tmp/test_array_$$"
    cat > "$test_file" << 'EOF'
{
  "items": [
    {"name": "first"},
    {"name": "second"}
  ]
}
EOF
    
    get_config_value "items[0].name" "$test_file" "default" >/dev/null 2>&1
    local result=$?
    local value
    value=$(get_kv_value)
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$value" == "first" ]]
}

test_kv_nested_objects() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config with deep nesting
    local test_file="/tmp/test_nested_$$"
    cat > "$test_file" << 'EOF'
{
  "app": {
    "config": {
      "database": {
        "connection": {
          "host": "deep-host"
        }
      }
    }
  }
}
EOF
    
    get_config_value "app.config.database.connection.host" "$test_file" "default" >/dev/null 2>&1
    local result=$?
    local value
    value=$(get_kv_value)
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]] && [[ "$value" == "deep-host" ]]
}

test_kv_cache_behavior() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test config file
    local test_file="/tmp/test_cache_$$"
    echo '{"name": "cached-value"}' > "$test_file"
    
    # First call - should cache
    get_config_value "name" "$test_file" "default" >/dev/null 2>&1
    local value1
    value1=$(get_kv_value)
    
    # Second call - should use cache
    get_config_value "name" "$test_file" "default" >/dev/null 2>&1
    local value2
    value2=$(get_kv_value)
    
    # Cleanup
    rm -f "$test_file"
    
    [[ "$value1" == "$value2" ]] && [[ "$value1" == "cached-value" ]]
}

# Test new string extraction API
test_kv_extract_string_json() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Test JSON string extraction
    local json_data='{"app": {"name": "test-app", "version": "1.0.0"}}'
    kv_extract_string "app.name" "json" "$json_data" "default"
    
    [[ "$(get_kv_value)" == "test-app" ]] && [[ "$(get_kv_status)" == "success" ]]
}

test_kv_extract_string_missing_key() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Test missing key with default
    local json_data='{"app": {"name": "test-app"}}'
    kv_extract_string "app.missing" "json" "$json_data" "default_value"
    
    [[ "$(get_kv_value)" == "default_value" ]] && [[ "$(get_kv_status)" == "success" ]]
}

test_kv_extract_string_invalid_format() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Test unsupported format
    kv_extract_string "key" "xml" "<root><key>value</key></root>" "default"
}

test_kv_extract_string_yaml() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path kv)"
    
    # Skip if yq not available
    if ! command -v yq >/dev/null 2>&1; then
        return 0
    fi
    
    # Test YAML string extraction  
    local yaml_data="app:
  name: yaml-app
  version: 2.0.0"
    kv_extract_string "app.name" "yaml" "$yaml_data" "default"
    
    [[ "$(get_kv_value)" == "yaml-app" ]] && [[ "$(get_kv_status)" == "success" ]]
}

# Register all KV tests
run_test "KV module requires dependencies (dependency check)" test_kv_requires_dependencies false
run_test "KV module loads with all dependencies" test_kv_loads_with_dependencies

run_test "KV state reset clears all state" test_kv_state_reset
run_test "Set KV error state works" test_kv_set_error_state
run_test "Set KV success state works" test_kv_set_success_state

run_test "KV platform tool detection integration works" test_kv_platform_tool_detection

if command -v jq >/dev/null 2>&1; then
    run_test "Get tool for JSON format returns jq" test_kv_get_tool_for_format_json
else
    run_test "Get tool for JSON format fails without jq" test_kv_get_tool_for_format_json false
fi

if command -v yq >/dev/null 2>&1; then
    run_test "Get tool for YAML format returns yq" test_kv_get_tool_for_format_yaml
else
    run_test "Get tool for YAML format fails without yq" test_kv_get_tool_for_format_yaml false
fi

run_test "Get tool for invalid format fails" test_kv_get_tool_for_format_invalid false

run_test "Detect file format: JSON" test_kv_detect_format_json
run_test "Detect file format: YAML" test_kv_detect_format_yaml
run_test "Detect file format: nonexistent file" test_kv_detect_format_nonexistent false

if command -v jq >/dev/null 2>&1; then
    run_test "Execute cached extraction: JSON data" test_kv_execute_cached_extraction_json
    run_test "Execute cached extraction: with default" test_kv_execute_cached_extraction_with_default
    run_test "Get config value: JSON format" test_kv_get_config_value_json
    run_test "Get config value: missing key uses default" test_kv_get_config_value_missing_key
    run_test "KV key exists: present key" test_kv_key_exists_present
    run_test "KV key exists: missing key" test_kv_key_exists_missing
    run_test "Get config values: batch operation" test_kv_get_config_values_batch
    run_test "Get config values: mixed results" test_kv_get_config_values_mixed_results
    run_test "Array access in config values" test_kv_array_access
    run_test "Nested object access" test_kv_nested_objects
    run_test "Cache behavior consistency" test_kv_cache_behavior
else
    skip_test "JSON-based KV tests" "jq not available"
fi

if command -v yq >/dev/null 2>&1; then
    run_test "Get config value: YAML format" test_kv_get_config_value_yaml
else
    skip_test "YAML-based KV tests" "yq not available"
fi

run_test "Get config value: missing file" test_kv_get_config_value_missing_file false

run_test "Validate config file: valid format" test_kv_validate_config_file_valid
run_test "Validate config file: invalid format" test_kv_validate_config_file_invalid false

run_test "Get KV status returns current status" test_kv_get_status
run_test "Get KV value returns current value" test_kv_get_value
run_test "Get KV format returns current format" test_kv_get_format
run_test "Get KV tool returns current tool" test_kv_get_tool

run_test "KV succeeded returns true for success" test_kv_succeeded
run_test "KV failed returns true for error" test_kv_failed
run_test "KV succeeded returns false for error" test_kv_succeeded_false_on_error
run_test "KV failed returns false for success" test_kv_failed_false_on_success

if command -v jq >/dev/null 2>&1; then
    run_test_with_output "KV stats output includes statistics header" test_kv_get_stats "KV Statistics" contains
else
    skip_test "KV statistics test" "jq not available"
fi

# New KV string extraction tests
if command -v jq >/dev/null 2>&1; then
    run_test "KV string extraction: JSON data" test_kv_extract_string_json
    run_test "KV string extraction: missing key with default" test_kv_extract_string_missing_key
else
    skip_test "KV string extraction JSON tests" "jq not available"
fi

run_test "KV string extraction: invalid format fails" test_kv_extract_string_invalid_format false

if command -v yq >/dev/null 2>&1; then
    run_test "KV string extraction: YAML data" test_kv_extract_string_yaml
else
    skip_test "KV string extraction YAML tests" "yq not available"
fi

run_test "KV module validation passes" test_kv_validate_module
run_test_with_output "KV info output includes module name" test_kv_info_output "Abaddon KV" contains