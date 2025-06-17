# Object Tests - Stateful Proto-Object System
# Test functions for abaddon-object.sh - schema composition, lifecycle management, versioning

# Test object module loading and dependencies
test_object_requires_dependencies() {
    # Should fail without required modules loaded
    source "$(get_module_path object)"
}

test_object_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    [[ "${ABADDON_OBJECT_LOADED:-}" == "1" ]]
}

# Test object system initialization
test_object_system_init() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test_context"
    
    [[ "$ABADDON_OBJECT_SYSTEM_INITIALIZED" == "true" ]] && \
    [[ "$ABADDON_OBJECT_STATUS" == "ready" ]]
}

# Test object state management
test_object_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    # Set some state first
    ABADDON_OBJECT_STATUS="test_status"
    ABADDON_OBJECT_ERROR="test_error"
    ABADDON_OBJECT_CURRENT_OBJECT="test_obj"
    
    clear_object_state
    
    [[ -z "${ABADDON_OBJECT_STATUS:-}" ]] && \
    [[ -z "${ABADDON_OBJECT_ERROR:-}" ]] && \
    [[ -z "${ABADDON_OBJECT_CURRENT_OBJECT:-}" ]] && \
    [[ "$ABADDON_OBJECT_SYSTEM_INITIALIZED" == "false" ]]
}

test_object_set_error_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    clear_object_state
    set_object_error "test error message"
    
    [[ "${ABADDON_OBJECT_STATUS:-}" == "error" ]] && \
    [[ "${ABADDON_OBJECT_ERROR:-}" == "test error message" ]]
}

test_object_set_success_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    clear_object_state
    set_object_success "test_operation"
    
    [[ "${ABADDON_OBJECT_STATUS:-}" == "success" ]] && \
    [[ "${ABADDON_OBJECT_LAST_OPERATION:-}" == "test_operation" ]]
}

# Test basic object creation
test_object_creation_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_basic_obj"
    create_object "$test_obj" "stateful"
    local result=$?
    local status="$ABADDON_OBJECT_STATUS"
    local current="$ABADDON_OBJECT_CURRENT_OBJECT"
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $result -eq 0 ]] && \
    [[ "$status" == "object_created" ]] && \
    [[ "$current" == "$test_obj" ]]
}

test_object_creation_multiple_schemas() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_multi_obj"
    create_object "$test_obj" "stateful" "executable"
    local result=$?
    local schemas="${ABADDON_OBJECT_SCHEMAS[$test_obj]:-}"
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $result -eq 0 ]] && \
    [[ "$schemas" == "stateful executable" ]]
}

test_object_creation_invalid_id() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    # Test invalid identifier (with hyphen)
    create_object "test-invalid" "stateful"
    local result=$?
    
    [[ $result -eq 1 ]] && \
    [[ "$ABADDON_OBJECT_STATUS" == "error" ]]
}

test_object_creation_duplicate() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_dup_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    # Try to create duplicate
    create_object "$test_obj" "executable" >/dev/null 2>&1
    local result=$?
    local status="$ABADDON_OBJECT_STATUS"
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $result -eq 1 ]] && \
    [[ "$status" == "error" ]]
}

test_object_creation_system_not_initialized() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    clear_object_state  # Ensure not initialized
    
    create_object "test_obj" "stateful"
    local result=$?
    
    [[ $result -eq 1 ]] && \
    [[ "$ABADDON_OBJECT_STATUS" == "error" ]]
}

# Test object destruction
test_object_destruction() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_destroy_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    destroy_object "$test_obj"
    local result=$?
    
    [[ $result -eq 0 ]] && \
    [[ "$ABADDON_OBJECT_STATUS" == "object_destroyed" ]] && \
    ! object_exists "$test_obj"
}

test_object_destruction_nonexistent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    destroy_object "nonexistent_obj"
    local result=$?
    
    [[ $result -eq 1 ]] && \
    [[ "$ABADDON_OBJECT_STATUS" == "error" ]]
}

# Test object state management
test_object_state_setting() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_state_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    object_set_state "$test_obj" "custom_state" "custom_value"
    local result=$?
    local retrieved_value
    retrieved_value=$(object_get_state "$test_obj" "custom_state")
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $result -eq 0 ]] && \
    [[ "$retrieved_value" == "custom_value" ]]
}

test_object_state_nonexistent_object() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    object_set_state "nonexistent" "test_state" "test_value"
    local result=$?
    
    [[ $result -eq 1 ]] && \
    [[ "$ABADDON_OBJECT_STATUS" == "error" ]]
}

test_object_existence_check() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_exist_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    object_exists "$test_obj"
    local exists_result=$?
    
    ! object_exists "nonexistent_obj"
    local not_exists_result=$?
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $exists_result -eq 0 ]] && \
    [[ $not_exists_result -eq 0 ]]
}

test_object_state_check() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_state_check_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    # Auto-checkpoint is enabled by default, so expect checkpointed state after creation
    local expected_state="$ABADDON_OBJECT_STATE_CHECKPOINTED"
    object_is_in_state "$test_obj" "existence" "$expected_state"
    local result=$?
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $result -eq 0 ]]
}

# Test schema system
test_schema_registration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    # Define a dummy function for testing
    dummy_function() { echo "test"; return 0; }
    
    # Use an existing function for testing (disable strict validation temporarily)
    local old_strict="$ABADDON_OBJECT_STRICT_VALIDATION"
    ABADDON_OBJECT_STRICT_VALIDATION="false"
    
    register_schema "TEST_SCHEMA" "test_behavior" "dummy_function"
    local result=$?
    
    # Restore strict validation
    ABADDON_OBJECT_STRICT_VALIDATION="$old_strict"
    
    [[ $result -eq 0 ]]
}

test_schema_invalid_names() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    # Test invalid schema name with hyphen
    register_schema "TEST-SCHEMA" "test_behavior" "test_function"
    local result=$?
    
    [[ $result -eq 1 ]] && \
    [[ "$ABADDON_OBJECT_STATUS" == "error" ]]
}

test_default_schemas_loaded() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    # Check that default schemas are registered
    declare -p "ABADDON_SCHEMA_STATEFUL" >/dev/null 2>&1 && \
    declare -p "ABADDON_SCHEMA_EXECUTABLE" >/dev/null 2>&1 && \
    declare -p "ABADDON_SCHEMA_WORKFLOW" >/dev/null 2>&1 && \
    declare -p "ABADDON_SCHEMA_STATE_MACHINE" >/dev/null 2>&1
}

# Test versioning and history
test_object_versioning() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_version_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    local initial_version="${ABADDON_OBJECT_VERSIONS[$test_obj]}"
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ "$initial_version" == "1" ]]
}

test_object_history_recording() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_history_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    # Check that creation was recorded in history
    local history_key="${test_obj}:1"
    local history_entry="${ABADDON_OBJECT_HISTORY[$history_key]:-}"
    
    # Capture before cleanup since cleanup might modify the arrays
    local has_entry=false
    [[ -n "$history_entry" ]] && [[ "$history_entry" =~ created ]] && has_entry=true
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ "$has_entry" == "true" ]]
}

test_object_checkpoint_creation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_checkpoint_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    object_checkpoint "$test_obj" "test_checkpoint" >/dev/null 2>&1
    local result=$?
    local checkpoint_key="${test_obj}:test_checkpoint"
    local checkpoint_exists=false
    [[ -n "${ABADDON_OBJECT_CHECKPOINTS[$checkpoint_key]:-}" ]] && checkpoint_exists=true
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $result -eq 0 ]] && \
    [[ "$checkpoint_exists" == "true" ]]
}

test_object_rollback() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_rollback_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    object_checkpoint "$test_obj" "test_checkpoint" >/dev/null 2>&1
    
    object_rollback "$test_obj" "test_checkpoint"
    local result=$?
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $result -eq 0 ]]
}

test_object_rollback_nonexistent_checkpoint() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_rollback_fail_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    object_rollback "$test_obj" "nonexistent_checkpoint" >/dev/null 2>&1
    local result=$?
    local status="$ABADDON_OBJECT_STATUS"
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
    
    [[ $result -eq 1 ]] && \
    [[ "$status" == "error" ]]
}

# Test query and information functions
test_list_objects() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj1="test_list_obj1"
    local test_obj2="test_list_obj2"
    create_object "$test_obj1" "stateful" >/dev/null 2>&1
    create_object "$test_obj2" "executable" >/dev/null 2>&1
    
    local object_list
    object_list=$(list_objects "name")
    
    # Cleanup
    destroy_object "$test_obj1" 2>/dev/null || true
    destroy_object "$test_obj2" 2>/dev/null || true
    
    [[ "$object_list" =~ $test_obj1 ]] && \
    [[ "$object_list" =~ $test_obj2 ]]
}

test_get_object_stats() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_system_init "test"
    
    local test_obj="test_stats_obj"
    create_object "$test_obj" "stateful" >/dev/null 2>&1
    
    # Output the stats directly for run_test_with_output to check
    get_object_stats
    
    # Cleanup
    destroy_object "$test_obj" 2>/dev/null || true
}

# Test module validation
test_object_validate_module() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    object_validate >/dev/null 2>&1
}

test_object_info_output() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path object)"
    
    # Output the info directly for run_test_with_output to check
    object_info
}

# Register object tests
run_test "Object module requires dependencies (dependency check)" test_object_requires_dependencies false
run_test "Object module loads with all dependencies" test_object_loads_with_dependencies

run_test "Object system initialization" test_object_system_init
run_test "Object state reset clears all state" test_object_state_reset
run_test "Set object error state works" test_object_set_error_state
run_test "Set object success state works" test_object_set_success_state

run_test "Object creation: basic single schema" test_object_creation_basic
run_test "Object creation: multiple schemas" test_object_creation_multiple_schemas
run_test "Object creation: invalid ID rejected" test_object_creation_invalid_id
run_test "Object creation: duplicate fails" test_object_creation_duplicate
run_test "Object creation: system not initialized fails" test_object_creation_system_not_initialized

run_test "Object destruction: successful" test_object_destruction
run_test "Object destruction: nonexistent fails" test_object_destruction_nonexistent

run_test "Object state: setting and getting" test_object_state_setting
run_test "Object state: nonexistent object fails" test_object_state_nonexistent_object
run_test "Object existence check" test_object_existence_check
run_test "Object state check" test_object_state_check

run_test "Schema registration" test_schema_registration
run_test "Schema registration: invalid names rejected" test_schema_invalid_names
run_test "Default schemas loaded at initialization" test_default_schemas_loaded

run_test "Object versioning: initial version is 1" test_object_versioning
run_test "Object history: creation recorded" test_object_history_recording
run_test "Object checkpoint: creation successful" test_object_checkpoint_creation
run_test "Object rollback: to checkpoint" test_object_rollback
run_test "Object rollback: nonexistent checkpoint fails" test_object_rollback_nonexistent_checkpoint

run_test "List objects: multiple objects" test_list_objects
run_test_with_output "Object stats output includes statistics header" test_get_object_stats "Object System Statistics" contains

run_test "Object module validation passes" test_object_validate_module
run_test_with_output "Object info output includes module name" test_object_info_output "abaddon-object.sh" contains