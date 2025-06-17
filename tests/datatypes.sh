# Datatypes module tests
# Test functions for abaddon-datatypes.sh - User-facing data validation and parsing

# Test module loading and dependencies
test_datatypes_requires_dependencies() {
    # Should fail without required modules loaded
    source "$(get_module_path datatypes)"
}

test_datatypes_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    [[ "${ABADDON_DATATYPES_LOADED:-}" == "1" ]]
}

# Test datatypes state management
test_datatypes_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    # Set some state first
    ABADDON_DATATYPES_STATUS="success"
    ABADDON_DATATYPES_VALIDATED_VALUE="test"
    
    clear_datatypes_state
    
    [[ -z "${ABADDON_DATATYPES_STATUS:-}" ]] && \
    [[ -z "${ABADDON_DATATYPES_VALIDATED_VALUE:-}" ]]
}

# Test identifier validation
test_datatypes_validate_identifier_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier "valid_identifier"
    
    [[ "$(get_datatypes_status)" == "ready" ]] && \
    [[ "$(get_datatypes_value)" == "valid_identifier" ]]
}

test_datatypes_validate_identifier_invalid_start() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier "123invalid"
}

test_datatypes_validate_identifier_invalid_chars() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier "invalid-name"
}

test_datatypes_validate_identifier_empty() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier ""
}

test_datatypes_validate_identifier_reserved_word() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier "if" "true"
}

test_datatypes_validate_identifier_non_strict() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier "if" "false"
    
    [[ "$(get_datatypes_status)" == "ready" ]]
}

# Test UUID validation
test_datatypes_validate_uuid_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_uuid "550e8400-e29b-41d4-a716-446655440000"
    
    [[ "$(get_datatypes_status)" == "ready" ]]
}

test_datatypes_validate_uuid_v4() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    # This UUID has version "3" instead of "4" at position 14, making it invalid for v4
    validate_uuid "550e8400-e29b-31d4-a716-446655440000" "4"
}

test_datatypes_validate_uuid_invalid_format() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_uuid "not-a-uuid"
}

test_datatypes_validate_uuid_empty() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_uuid ""
}

# Test ISO datetime validation
test_datatypes_validate_iso_datetime_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_iso_datetime "2023-12-25T10:30:00"
    
    [[ "$(get_datatypes_status)" == "ready" ]]
}

test_datatypes_validate_iso_datetime_with_ms() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_iso_datetime "2023-12-25T10:30:00.123"
    
    [[ "$(get_datatypes_status)" == "ready" ]]
}

test_datatypes_validate_iso_datetime_with_timezone() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_iso_datetime "2023-12-25T10:30:00Z"
    
    [[ "$(get_datatypes_status)" == "ready" ]]
}

test_datatypes_validate_iso_datetime_require_timezone() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_iso_datetime "2023-12-25T10:30:00" "true"
}

test_datatypes_validate_iso_datetime_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_iso_datetime "not-a-date"
}

# Test URI encoding
test_datatypes_uri_encode_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    uri_encode "hello world"
    
    [[ "$(get_datatypes_value)" == "hello%20world" ]]
}

test_datatypes_uri_encode_special_chars() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    uri_encode "hello@example.com"
    
    [[ "$(get_datatypes_value)" == "hello%40example.com" ]]
}

test_datatypes_uri_encode_empty() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    uri_encode ""
    
    [[ "$(get_datatypes_value)" == "" ]]
}

# Test URI decoding
test_datatypes_uri_decode_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    uri_decode "hello%20world"
    
    [[ "$(get_datatypes_value)" == "hello world" ]]
}

test_datatypes_uri_decode_plus() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    uri_decode "hello+world"
    
    [[ "$(get_datatypes_value)" == "hello world" ]]
}

# Test HTML escaping
test_datatypes_html_escape_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    html_escape "<script>alert('test')</script>"
    
    [[ "$(get_datatypes_value)" == "&lt;script&gt;alert(&#39;test&#39;)&lt;/script&gt;" ]]
}

test_datatypes_html_escape_ampersand() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    html_escape "Tom & Jerry"
    
    [[ "$(get_datatypes_value)" == "Tom &amp; Jerry" ]]
}

# Test HTML unescaping
test_datatypes_html_unescape_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    html_unescape "&lt;script&gt;alert(&#39;test&#39;)&lt;/script&gt;"
    
    [[ "$(get_datatypes_value)" == "<script>alert('test')</script>" ]]
}

# Test JSON key validation
test_datatypes_validate_json_key_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_json_key "config.database.host"
    
    [[ "$(get_datatypes_status)" == "ready" ]]
}

test_datatypes_validate_json_key_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_json_key "invalid key with spaces"
}

# Test state accessor functions
test_datatypes_get_value() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier "test_value"
    
    [[ "$(get_datatypes_value)" == "test_value" ]]
}

test_datatypes_get_error() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier ""
    
    [[ -n "$(get_datatypes_error)" ]]
}

test_datatypes_get_validation_type() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier "test"
    
    [[ "$(get_datatypes_validation_type)" == "identifier" ]]
}

# Test success/failure functions
test_datatypes_succeeded_function() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier "valid_id"
    datatypes_succeeded
}

test_datatypes_failed_function() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    validate_identifier ""
    datatypes_failed
}

# Test module validation
test_datatypes_validate_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    declare -F datatypes_validate >/dev/null
}

test_datatypes_validate_success() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    datatypes_validate
}

# Test module info
test_datatypes_info_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    declare -F datatypes_info >/dev/null
}

test_datatypes_info_output() {
    source "$(get_module_path core)"
    source "$(get_module_path datatypes)"
    
    # Output the info directly for run_test_with_output to check
    datatypes_info
}

# Register all datatypes tests
run_test "Datatypes module requires dependencies (dependency check)" test_datatypes_requires_dependencies false
run_test "Datatypes module loads with all dependencies" test_datatypes_loads_with_dependencies

run_test "Datatypes state reset clears all state" test_datatypes_state_reset

run_test "Datatypes validate identifier accepts valid identifier" test_datatypes_validate_identifier_valid
run_test "Datatypes validate identifier rejects number start" test_datatypes_validate_identifier_invalid_start false
run_test "Datatypes validate identifier rejects invalid chars" test_datatypes_validate_identifier_invalid_chars false
run_test "Datatypes validate identifier rejects empty" test_datatypes_validate_identifier_empty false
run_test "Datatypes validate identifier rejects reserved word in strict mode" test_datatypes_validate_identifier_reserved_word false
run_test "Datatypes validate identifier allows reserved word in non-strict mode" test_datatypes_validate_identifier_non_strict

run_test "Datatypes validate UUID accepts valid UUID" test_datatypes_validate_uuid_valid
run_test "Datatypes validate UUID v4 validation fails" test_datatypes_validate_uuid_v4 false
run_test "Datatypes validate UUID rejects invalid format" test_datatypes_validate_uuid_invalid_format false
run_test "Datatypes validate UUID rejects empty" test_datatypes_validate_uuid_empty false

run_test "Datatypes validate ISO datetime accepts basic format" test_datatypes_validate_iso_datetime_basic
run_test "Datatypes validate ISO datetime accepts milliseconds" test_datatypes_validate_iso_datetime_with_ms
run_test "Datatypes validate ISO datetime accepts timezone" test_datatypes_validate_iso_datetime_with_timezone
run_test "Datatypes validate ISO datetime requires timezone when specified" test_datatypes_validate_iso_datetime_require_timezone false
run_test "Datatypes validate ISO datetime rejects invalid format" test_datatypes_validate_iso_datetime_invalid false

run_test "Datatypes URI encode basic text" test_datatypes_uri_encode_basic
run_test "Datatypes URI encode special characters" test_datatypes_uri_encode_special_chars
run_test "Datatypes URI encode empty string" test_datatypes_uri_encode_empty

run_test "Datatypes URI decode basic text" test_datatypes_uri_decode_basic
run_test "Datatypes URI decode plus signs" test_datatypes_uri_decode_plus

run_test "Datatypes HTML escape basic text" test_datatypes_html_escape_basic
run_test "Datatypes HTML escape ampersand" test_datatypes_html_escape_ampersand

run_test "Datatypes HTML unescape basic text" test_datatypes_html_unescape_basic

run_test "Datatypes validate JSON key accepts valid key" test_datatypes_validate_json_key_valid
run_test "Datatypes validate JSON key rejects invalid key" test_datatypes_validate_json_key_invalid false

run_test "Datatypes get value accessor works" test_datatypes_get_value
run_test "Datatypes get error accessor works" test_datatypes_get_error
run_test "Datatypes get validation type accessor works" test_datatypes_get_validation_type

run_test "Datatypes succeeded returns true for success" test_datatypes_succeeded_function
run_test "Datatypes failed returns true for error" test_datatypes_failed_function

run_test "Datatypes validate function exists" test_datatypes_validate_function_exists
run_test "Datatypes module validation passes" test_datatypes_validate_success

run_test "Datatypes info function exists" test_datatypes_info_function_exists
run_test_with_output "Datatypes info output includes module name" test_datatypes_info_output "abaddon-datatypes.sh" contains