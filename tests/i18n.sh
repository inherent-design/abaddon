# i18n module tests
# Test functions for abaddon-i18n.sh - Translation and internationalization service

# Test module loading and dependencies
test_i18n_requires_dependencies() {
    # Should fail without required modules loaded
    source "$(get_module_path i18n)"
}

test_i18n_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    [[ "${ABADDON_I18N_LOADED:-}" == "1" ]]
}

# Test i18n state management
test_i18n_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    clear_i18n_state
    [[ "${ABADDON_I18N_INITIALIZED:-}" == "false" ]]
}

# Test basic initialization
test_i18n_basic_init() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    # Create minimal test translation file
    local test_dir="/tmp/abaddon_i18n_$$"
    mkdir -p "$test_dir/translations"
    echo '{"test":{"message":"Hello"}}' > "$test_dir/translations/en.json"
    
    export ABADDON_LIB_DIR="$test_dir"
    i18n_init --app-domain="test" --app-translations="$test_dir/translations" >/dev/null 2>&1
    
    local result=$(is_i18n_ready && echo "true" || echo "false")
    rm -rf "$test_dir"
    
    [[ "$result" == "true" ]]
}

# Test locale detection
test_i18n_locale_detection() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    local test_dir="/tmp/abaddon_i18n_$$"
    mkdir -p "$test_dir/translations"
    echo '{"test":"value"}' > "$test_dir/translations/en.json"
    
    export ABADDON_LIB_DIR="$test_dir"
    export LANG="en_US.UTF-8"
    
    i18n_init --app-domain="test" --app-translations="$test_dir/translations" >/dev/null 2>&1
    local locale=$(get_i18n_locale)
    
    rm -rf "$test_dir"
    
    [[ "$locale" == "en" ]]
}

# Test basic translation
test_i18n_basic_translation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    local test_dir="/tmp/abaddon_i18n_$$"
    mkdir -p "$test_dir/translations"
    echo '{"welcome":"Hello World"}' > "$test_dir/translations/en.json"
    
    export ABADDON_LIB_DIR="$test_dir"
    i18n_init --app-domain="test" --app-translations="$test_dir/translations" >/dev/null 2>&1
    
    t 'test.welcome' >/dev/null 2>&1
    local result=$(get_i18n_value)
    local status=$(get_i18n_lookup_status)
    
    rm -rf "$test_dir"
    
    [[ "$result" == "Hello World" && "$status" == "success" ]]
}

# Test variable substitution
test_i18n_variable_substitution() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    local test_dir="/tmp/abaddon_i18n_$$"
    mkdir -p "$test_dir/translations"
    echo '{"greeting":"Hello {0}!"}' > "$test_dir/translations/en.json"
    
    export ABADDON_LIB_DIR="$test_dir"
    i18n_init --app-domain="test" --app-translations="$test_dir/translations" >/dev/null 2>&1
    
    t 'test.greeting' 'Atlas' >/dev/null 2>&1
    local result=$(get_i18n_value)
    local status=$(get_i18n_lookup_status)
    
    rm -rf "$test_dir"
    
    [[ "$result" == "Hello Atlas!" && "$status" == "success" ]]
}

# Test missing key error
test_i18n_missing_key() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    local test_dir="/tmp/abaddon_i18n_$$"
    mkdir -p "$test_dir/translations"
    echo '{"existing":"value"}' > "$test_dir/translations/en.json"
    
    export ABADDON_LIB_DIR="$test_dir"
    i18n_init --app-domain="test" --app-translations="$test_dir/translations" >/dev/null 2>&1
    
    t 'test.nonexistent' >/dev/null 2>&1
    local status=$(get_i18n_lookup_status)
    local result=$(get_i18n_value)
    
    rm -rf "$test_dir"
    
    [[ "$status" == "not_found" && "$result" == "[missing_key:test.nonexistent]" ]]
}

# Test uninitialized error
test_i18n_uninitialized() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    clear_i18n_state
    
    t 'test.message' >/dev/null 2>&1
    local status=$(get_i18n_lookup_status)
    local result=$(get_i18n_value)
    
    [[ "$status" == "error" && "$result" == "[i18n_not_initialized:test.message]" ]]
}

# Register all i18n tests following Abaddon patterns
run_test "i18n module requires dependencies (dependency check)" test_i18n_requires_dependencies false
run_test "i18n module loads with all dependencies" test_i18n_loads_with_dependencies

run_test "i18n state reset clears all state" test_i18n_state_reset
run_test "i18n basic initialization works" test_i18n_basic_init
run_test "i18n locale detection from environment" test_i18n_locale_detection

run_test "i18n basic translation lookup" test_i18n_basic_translation
run_test "i18n variable substitution" test_i18n_variable_substitution

run_test "i18n missing key returns error" test_i18n_missing_key
run_test "i18n uninitialized state returns error" test_i18n_uninitialized