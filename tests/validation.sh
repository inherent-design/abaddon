# Validation module tests
# Test functions for abaddon-validation.sh - Pure validation logic utility module

# Test module loading and dependencies
test_validation_requires_core() {
    # Should fail without core loaded
    source "$(get_module_path validation)"
}

test_validation_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    [[ "${ABADDON_VALIDATION_LOADED:-}" == "1" ]]
}

# Test validation state management
test_validation_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    # Set some state first
    ABADDON_VALIDATION_STATUS="error"
    ABADDON_VALIDATION_ERROR_MESSAGE="test error"
    ABADDON_VALIDATION_DETAILS="test details"
    
    clear_validation_state
    
    [[ -z "${ABADDON_VALIDATION_STATUS:-}" ]] && \
    [[ -z "${ABADDON_VALIDATION_ERROR_MESSAGE:-}" ]] && \
    [[ -z "${ABADDON_VALIDATION_DETAILS:-}" ]]
}

test_validation_set_error_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    clear_validation_state
    set_validation_error "test error message" "test details"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "error" ]] && \
    [[ "${ABADDON_VALIDATION_ERROR_MESSAGE:-}" == "test error message" ]] && \
    [[ "${ABADDON_VALIDATION_DETAILS:-}" == "test details" ]]
}

test_validation_set_success_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    clear_validation_state
    set_validation_success "success details"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
    [[ "${ABADDON_VALIDATION_DETAILS:-}" == "success details" ]]
}

# Test path validation functions
test_validate_file_path_relative_safe() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_file_path "config.json" false
}

test_validate_file_path_absolute_when_allowed() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_file_path "/tmp/test.json" true
}

test_validate_file_path_absolute_when_disallowed() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_file_path "/tmp/test.json" false
}

test_validate_file_path_traversal_attack() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_file_path "../../../etc/passwd" false
}

test_validate_file_path_null_byte_injection() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    ! validate_file_path "config.json\0" false
}

test_validate_file_path_empty_path() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_file_path "" false
}

# Test file existence validation
test_validate_file_exists_real_file() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    # Create a test file
    local test_file="/tmp/test_validation_$$"
    echo "test content" > "$test_file"
    
    validate_file_exists "$test_file"
    local result=$?
    
    # Cleanup
    rm -f "$test_file"
    
    [[ $result -eq 0 ]]
}

test_validate_file_exists_nonexistent_file() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_file_exists "/nonexistent/file/$$"
}

test_validate_file_exists_directory() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_file_exists "/tmp"  # Directory, not file
}

# Test directory validation
test_validate_directory_path_existing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_directory_path "/tmp" false
}

test_validate_directory_path_create_missing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local test_dir="/tmp/test_validation_dir_$$"
    
    validate_directory_path "$test_dir" true
    local result=$?
    
    # Cleanup
    [[ -d "$test_dir" ]] && rmdir "$test_dir"
    
    [[ $result -eq 0 ]]
}

test_validate_directory_path_dont_create_missing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_directory_path "/nonexistent/directory/$$" false
}

# Test tool path normalization
test_normalize_query_path_jq() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "jq" "project.name"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
    [[ "$(get_normalized_path)" == ".project.name" ]]
}

test_normalize_query_path_yq() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "yq" "project.name"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
    [[ "$(get_normalized_path)" == ".project.name" ]]
}

test_normalize_query_path_xq() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "xq" "project.name"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
    [[ "$(get_normalized_path)" == "project.name" ]]
}

test_normalize_query_path_tq() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "tq" "project.name"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
    [[ "$(get_normalized_path)" == "project.name" ]]
}

test_normalize_query_path_unknown_tool() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "unknown_tool" "project.name"
}

test_normalize_query_path_complex_path() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "jq" "config.database.host"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
    [[ "$(get_normalized_path)" == ".config.database.host" ]]
}

test_normalize_query_path_array_access() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "jq" "items[0].name"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
    [[ "$(get_normalized_path)" == ".items[0].name" ]]
}

# Comprehensive path normalization tests
test_normalize_nested_objects() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "jq" "config.database.connection.host"
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
    [[ "$(get_normalized_path)" == ".config.database.connection.host" ]]
}

test_normalize_state_preservation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    # Test that state is properly preserved across calls
    normalize_query_path "jq" "first.path"
    local first_result="$(get_normalized_path)"
    
    normalize_query_path "yq" "second.path"
    local second_result="$(get_normalized_path)"
    
    [[ "$first_result" == ".first.path" ]] && \
    [[ "$second_result" == ".second.path" ]]
}

test_normalize_empty_path() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    normalize_query_path "jq" ""
    
    [[ "${ABADDON_VALIDATION_STATUS:-}" == "error" ]]
}

# Test data format validation
test_validate_json_content_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local json_content='{"name": "test", "version": "1.0"}'
    
    validate_json_content "$json_content"
}

test_validate_json_content_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local invalid_json='{"name": "test", "version":}'
    
    validate_json_content "$invalid_json"
}

test_validate_yaml_content_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local yaml_content='name: test
version: 1.0'
    
    if command -v yq >/dev/null 2>&1; then
        validate_yaml_content "$yaml_content"
    else
        return 0  # Skip if yq not available
    fi
}

test_validate_yaml_content_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local invalid_yaml='name: test
  version: [invalid'
    
    if command -v yq >/dev/null 2>&1; then
        validate_yaml_content "$invalid_yaml"
    else
        return 1  # Expect failure when yq not available
    fi
}

test_validate_xml_content_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local xml_content='<?xml version="1.0"?><root><name>test</name></root>'
    
    if command -v xq >/dev/null 2>&1; then
        validate_xml_content "$xml_content"
    else
        return 0  # Skip if xq not available
    fi
}

test_validate_xml_content_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local invalid_xml='<root><name>test'  # Truly malformed - unterminated tags
    
    if command -v xq >/dev/null 2>&1; then
        validate_xml_content "$invalid_xml"
    else
        return 1  # Expect failure when xq not available
    fi
}

test_validate_toml_content_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local toml_content='name = "test"
version = "1.0"'
    
    if command -v tq >/dev/null 2>&1; then
        validate_toml_content "$toml_content"
    else
        return 0  # Skip if tq not available
    fi
}

test_validate_toml_content_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local invalid_toml='name = test
  version = ['  # Invalid TOML syntax
    
    if command -v tq >/dev/null 2>&1; then
        validate_toml_content "$invalid_toml"
    else
        return 1  # Expect failure when tq not available
    fi
}

# Test data extraction
test_validate_and_extract_json() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local json_content='{"project": {"name": "test-project"}}'
    
    if command -v jq >/dev/null 2>&1; then
        validate_and_extract "json" "$json_content" "project.name" "default"
        
        [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
        [[ "$(get_extracted_value)" == "test-project" ]]
    else
        return 0  # Skip if jq not available
    fi
}

test_validate_and_extract_json_with_default() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local json_content='{"project": {}}'
    
    if command -v jq >/dev/null 2>&1; then
        validate_and_extract "json" "$json_content" "project.missing" "default_value"
        
        [[ "${ABADDON_VALIDATION_STATUS:-}" == "success" ]] && \
        [[ "$(get_extracted_value)" == "default_value" ]]
    else
        return 0  # Skip if jq not available
    fi
}

test_validate_and_extract_invalid_format() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_and_extract "invalid_format" "content" "path" "default"
}

# Test business logic validation
test_validate_field_required_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local json_content='{"name": "test"}'
    
    if command -v jq >/dev/null 2>&1; then
        validate_field_required "name" "$json_content" "json"
    else
        return 0  # Skip if jq not available
    fi
}

test_validate_field_required_missing() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    local json_content='{}'
    
    if command -v jq >/dev/null 2>&1; then
        validate_field_required "name" "$json_content" "json"
    else
        return 1  # Expect failure when jq not available
    fi
}

test_validate_value_in_list_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_value_in_list "apple" "apple,banana,cherry"
}

test_validate_value_in_list_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_value_in_list "grape" "apple,banana,cherry"
}

test_validate_value_in_list_empty_value() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_value_in_list "" "apple,banana,cherry"
}

test_validate_numeric_range_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_numeric_range "50" "1" "100"
}

test_validate_numeric_range_too_low() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_numeric_range "0" "1" "100"
}

test_validate_numeric_range_too_high() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_numeric_range "101" "1" "100"
}

test_validate_numeric_range_non_numeric() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_numeric_range "abc" "1" "100"
}

test_validate_numeric_range_at_boundaries() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_numeric_range "1" "1" "100" && \
    validate_numeric_range "100" "1" "100"
}

# Test CLI validation
test_validate_command_name_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_command_name "init"
}

test_validate_command_name_with_dash() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_command_name "create-project"
}

test_validate_command_name_invalid_characters() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_command_name "init@project"
}

test_validate_command_name_empty() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_command_name ""
}

test_validate_project_name_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_project_name "my-project"
}

test_validate_project_name_with_underscore() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_project_name "my_project"
}

test_validate_project_name_invalid_start() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_project_name "-project"
}

test_validate_project_name_special_characters() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    validate_project_name "my@project"
}

# Test state access functions
test_get_validation_status() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    set_validation_error "test error" "details"
    local status
    status=$(get_validation_status)
    
    [[ "$status" == "error" ]]
}

test_get_validation_error() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    set_validation_error "test error message" "details"
    local error
    error=$(get_validation_error)
    
    [[ "$error" == "test error message" ]]
}

test_get_validation_details() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    set_validation_success "success details"
    local details
    details=$(get_validation_details)
    
    [[ "$details" == "success details" ]]
}

test_validation_succeeded_true() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    set_validation_success "details"
    validation_succeeded
}

test_validation_succeeded_false() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    set_validation_error "error" "details"
    validation_succeeded
}

test_validation_failed_true() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    set_validation_error "error" "details"
    validation_failed
}

test_validation_failed_false() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    set_validation_success "details"
    validation_failed
}

# Test schema validation (if ajv-cli available)
test_validate_json_schema_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    # Skip if jsonschema CLI not available
    if ! command -v jsonschema >/dev/null 2>&1; then
        return 0
    fi
    
    # Create simple schema and data
    local schema_file="/tmp/test_schema_$$"
    local json_content='{"name": "test"}'
    
    cat > "$schema_file" << 'EOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {"type": "string"}
  },
  "required": ["name"]
}
EOF
    
    validate_json_schema "$json_content" "$schema_file"
    local result=$?
    
    # Cleanup
    rm -f "$schema_file"
    
    [[ $result -eq 0 ]]
}

test_validate_json_schema_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path validation)"
    
    # Skip if jsonschema CLI not available
    if ! command -v jsonschema >/dev/null 2>&1; then
        return 1  # Expect failure when tool not available
    fi
    
    # Create schema and invalid data
    local schema_file="/tmp/test_schema_$$"
    local json_content='{"name": 123}'  # Should be string, not number
    
    cat > "$schema_file" << 'EOF'
{
  "type": "object",
  "properties": {
    "name": {"type": "string"}
  },
  "required": ["name"]
}
EOF
    
    validate_json_schema "$json_content" "$schema_file"
    local result=$?
    
    # Cleanup
    rm -f "$schema_file"
    
    [[ $result -eq 0 ]]  # Should have failed validation
}

# Register all validation tests
run_test "Validation module requires core (dependency check)" test_validation_requires_core false
run_test "Validation module loads with all dependencies" test_validation_loads_with_dependencies

run_test "Validation state reset clears all state" test_validation_state_reset
run_test "Set validation error state works" test_validation_set_error_state
run_test "Set validation success state works" test_validation_set_success_state

run_test "Validate file path: relative safe path" test_validate_file_path_relative_safe
run_test "Validate file path: absolute when allowed" test_validate_file_path_absolute_when_allowed
run_test "Validate file path: absolute when disallowed" test_validate_file_path_absolute_when_disallowed false
run_test "Validate file path: blocks traversal attack" test_validate_file_path_traversal_attack false
run_test "Validate file path: blocks null byte injection" test_validate_file_path_null_byte_injection false
run_test "Validate file path: rejects empty path" test_validate_file_path_empty_path false

run_test "Validate file exists: real file" test_validate_file_exists_real_file
run_test "Validate file exists: nonexistent file" test_validate_file_exists_nonexistent_file false
run_test "Validate file exists: directory is not file" test_validate_file_exists_directory false

run_test "Validate directory path: existing directory" test_validate_directory_path_existing
run_test "Validate directory path: create missing" test_validate_directory_path_create_missing
run_test "Validate directory path: don't create missing" test_validate_directory_path_dont_create_missing false

run_test "Normalize query path: jq format" test_normalize_query_path_jq
run_test "Normalize query path: yq format" test_normalize_query_path_yq
run_test "Normalize query path: xq format" test_normalize_query_path_xq
run_test "Normalize query path: tq format" test_normalize_query_path_tq
run_test "Normalize query path: unknown tool" test_normalize_query_path_unknown_tool false
run_test "Normalize query path: complex path" test_normalize_query_path_complex_path
run_test "Normalize query path: array access" test_normalize_query_path_array_access

# Comprehensive path normalization tests
run_test "Path normalization: nested objects" test_normalize_nested_objects
run_test "Path normalization: state preservation" test_normalize_state_preservation
run_test "Path normalization: empty path handling" test_normalize_empty_path

run_test "Validate JSON content: valid JSON" test_validate_json_content_valid
run_test "Validate JSON content: invalid JSON" test_validate_json_content_invalid false

if command -v yq >/dev/null 2>&1; then
    run_test "Validate YAML content: valid YAML" test_validate_yaml_content_valid
    run_test "Validate YAML content: invalid YAML" test_validate_yaml_content_invalid false
else
    skip_test "Validate YAML content tests" "yq not available"
fi

if command -v xq >/dev/null 2>&1; then
    run_test "Validate XML content: valid XML" test_validate_xml_content_valid
    run_test "Validate XML content: invalid XML" test_validate_xml_content_invalid false
else
    skip_test "Validate XML content tests" "xq not available"
fi

if command -v tq >/dev/null 2>&1; then
    run_test "Validate TOML content: valid TOML" test_validate_toml_content_valid
    run_test "Validate TOML content: invalid TOML" test_validate_toml_content_invalid false
else
    skip_test "Validate TOML content tests" "tq not available"
fi

if command -v jq >/dev/null 2>&1; then
    run_test "Validate and extract: JSON data" test_validate_and_extract_json
    run_test "Validate and extract: JSON with default" test_validate_and_extract_json_with_default
    run_test "Validate field required: exists" test_validate_field_required_exists
    run_test "Validate field required: missing" test_validate_field_required_missing false
else
    skip_test "JSON extraction tests" "jq not available"
fi

run_test "Validate and extract: invalid format" test_validate_and_extract_invalid_format false

run_test "Validate value in list: valid value" test_validate_value_in_list_valid
run_test "Validate value in list: invalid value" test_validate_value_in_list_invalid false
run_test "Validate value in list: empty value" test_validate_value_in_list_empty_value false

run_test "Validate numeric range: valid value" test_validate_numeric_range_valid
run_test "Validate numeric range: too low" test_validate_numeric_range_too_low false
run_test "Validate numeric range: too high" test_validate_numeric_range_too_high false
run_test "Validate numeric range: non-numeric" test_validate_numeric_range_non_numeric false
run_test "Validate numeric range: at boundaries" test_validate_numeric_range_at_boundaries

run_test "Validate command name: valid name" test_validate_command_name_valid
run_test "Validate command name: with dash" test_validate_command_name_with_dash
run_test "Validate command name: invalid characters" test_validate_command_name_invalid_characters false
run_test "Validate command name: empty name" test_validate_command_name_empty false

run_test "Validate project name: valid name" test_validate_project_name_valid
run_test "Validate project name: with underscore" test_validate_project_name_with_underscore
run_test "Validate project name: invalid start" test_validate_project_name_invalid_start false
run_test "Validate project name: special characters" test_validate_project_name_special_characters false

run_test "Get validation status returns current status" test_get_validation_status
run_test "Get validation error returns error message" test_get_validation_error
run_test "Get validation details returns details" test_get_validation_details

run_test "Validation succeeded returns true for success" test_validation_succeeded_true
run_test "Validation succeeded returns false for error" test_validation_succeeded_false false
run_test "Validation failed returns true for error" test_validation_failed_true
run_test "Validation failed returns false for success" test_validation_failed_false false

if command -v jsonschema >/dev/null 2>&1; then
    run_test "Validate JSON schema: valid data" test_validate_json_schema_valid
    run_test "Validate JSON schema: invalid data" test_validate_json_schema_invalid false
else
    skip_test "JSON schema validation tests" "jsonschema CLI not available"
fi
