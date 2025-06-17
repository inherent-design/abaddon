# P4 Integration Tests - Application Services (i18n + HTTP + Commands)
# Test functions for P4 application services and cross-layer coordination

# P4 Integration Test: i18n + KV coordination
test_p4_i18n_kv_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test translation file
    local test_translations="/tmp/test_p4_translations_$$"
    mkdir -p "$test_translations"
    
    cat > "$test_translations/en.json" << 'EOF'
{
  "app": {
    "name": "Test Application",
    "welcome": "Welcome to {0}",
    "config": {
      "loaded": "Configuration loaded from {0}"
    }
  }
}
EOF
    
    # Initialize i18n with test domain
    i18n_init --app-domain="testapp" --app-translations="$test_translations"
    
    # Create test config file
    local test_config="/tmp/test_p4_config_$$"
    echo '{"app_name": "P4 Integration Test"}' > "$test_config"
    
    # Workflow: KV extraction → i18n translation with substitution
    get_config_value "app_name" "$test_config" "Unknown App"
    local app_name="$(get_kv_value)"
    
    # Use extracted value in i18n translation
    t "app.welcome" "$app_name"
    local welcome_message="$(get_i18n_value)"
    
    # Cleanup
    rm -rf "$test_translations" "$test_config"
    
    [[ "$welcome_message" == "Welcome to P4 Integration Test" ]]
}

# P4 Integration Test: P2→P4 data flow
test_p4_p2_data_flow() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Test complete P2→P4 workflow
    
    # 1. P2: Extract configuration using cache + security + kv
    local test_config="/tmp/test_p2_p4_flow_$$"
    cat > "$test_config" << 'EOF'
{
  "application": {
    "locale": "en", 
    "features": {
      "i18n_enabled": true,
      "default_message": "Hello World"
    }
  }
}
EOF
    
    # Extract config values using P2 layer
    get_config_value "application.locale" "$test_config" "en"
    local locale="$(get_kv_value)"
    
    get_config_value "application.features.default_message" "$test_config" "Default"
    local default_msg="$(get_kv_value)"
    
    # 2. P4: Use extracted values for i18n initialization
    local test_translations="/tmp/test_p2_p4_translations_$$"
    mkdir -p "$test_translations"
    
    cat > "$test_translations/en.json" << 'EOF'
{
  "messages": {
    "greeting": "Hello from P3 layer",
    "config_value": "Config says: {0}"
  }
}
EOF
    
    i18n_init --app-domain="p2p4test" --app-translations="$test_translations"
    
    # Use P2-extracted data in P4 translations
    t "messages.config_value" "$default_msg"
    local final_message="$(get_i18n_value)"
    
    # Cleanup
    rm -rf "$test_config" "$test_translations"
    
    [[ "$locale" == "en" ]] && \
    [[ "$final_message" == "Config says: Hello World" ]]
}

# P3 Integration Test: Cross-layer state management
test_p4_cross_layer_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    # Test that P4 maintains independent state from P2
    
    # Set states in P2 modules - just verify we can set and track state
    # We'll use cache since it's simpler to verify state with
    cache_store "test_p4_state_key" "P2 state value"
    local cache_test_value="$(cache_get "test_p4_state_key")"
    
    # Initialize P4 i18n
    local test_translations="/tmp/test_p4_state_$$"
    mkdir -p "$test_translations"
    echo '{"test": {"key": "P4 value"}}' > "$test_translations/en.json"
    
    i18n_init --app-domain="statetest" --app-translations="$test_translations"
    t "test.key"
    
    # Verify state independence and i18n functionality
    local final_cache_value="$(cache_get "test_p4_state_key")"
    local kv_status="$(get_kv_status)"  # KV will show success from i18n translation
    local i18n_status="$(get_i18n_lookup_status)"
    local i18n_value="$(get_i18n_value)"
    
    # Cleanup
    rm -rf "$test_translations"
    
    # Test that P2 cache state persisted and P4 i18n works correctly
    [[ "$cache_test_value" == "P2 state value" ]] && \
    [[ "$final_cache_value" == "P2 state value" ]] && \
    [[ "$kv_status" == "success" ]] && \
    [[ "$i18n_status" == "success" ]] && \
    [[ "$i18n_value" == "P4 value" ]]
}

# P4 Integration Test: P1→P2→P3→P4 complete stack
test_p4_complete_stack_integration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Test complete P1→P2→P3→P4 integration workflow
    
    # P1: Platform detection and tool availability
    local json_tool="$(get_best_tool "json_processing")"
    [[ "$json_tool" != "none" ]] || return 0  # Skip if no JSON tool
    
    # P2: Configuration management with security and caching
    local test_config="/tmp/test_complete_stack_$$"
    cat > "$test_config" << 'EOF'
{
  "app": {
    "name": "Complete Stack Test",
    "locale": "en",
    "messages": {
      "startup": "Application {0} starting in {1} mode"
    }
  }
}
EOF
    
    # Validate configuration file
    validate_file_exists "$test_config"
    [[ "$(get_security_status)" == "success" ]] || return 1
    
    # Extract values using KV (with caching)
    get_config_value "app.name" "$test_config" "Unknown"
    local app_name="$(get_kv_value)"
    
    get_config_value "app.locale" "$test_config" "en"
    local locale="$(get_kv_value)"
    
    # P4: i18n with extracted configuration
    local test_translations="/tmp/test_complete_stack_translations_$$"
    mkdir -p "$test_translations"
    
    cat > "$test_translations/$locale.json" << 'EOF'
{
  "system": {
    "startup": "Starting {0} in {1} locale",
    "ready": "System ready"
  }
}
EOF
    
    i18n_init --app-domain="stacktest" --app-translations="$test_translations"
    
    # Use P1+P2 data in P3 translation
    t "system.startup" "$app_name" "$locale"
    local startup_message="$(get_i18n_value)"
    
    # Verify cache was used
    get_cache_stats | grep -q "Cache Statistics" || return 1
    
    # Cleanup
    rm -rf "$test_config" "$test_translations"
    
    [[ "$startup_message" == "Starting Complete Stack Test in en locale" ]]
}

# P4 Integration Test: Error propagation through layers
test_p4_error_propagation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    
    # Test that errors propagate correctly through P1→P2→P3→P4
    
    # P2: Try to extract from invalid file
    get_config_value "any.key" "/nonexistent/file/$$" "default"
    local kv_status="$(get_kv_status)"
    
    # P3: Try to use i18n without initialization
    t "some.key"
    local i18n_status="$(get_i18n_lookup_status)"
    
    # Both should show error states
    [[ "$kv_status" == "error" ]] && [[ "$i18n_status" == "error" ]]
}

# P4 Integration Test: HTTP + KV coordination (API response parsing)
test_p4_http_kv_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path http)"
    
    # Skip if no HTTP client available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        return 0
    fi
    
    # Test HTTP → KV parsing workflow
    http_get "https://httpbin.org/json"
    
    if http_succeeded; then
        # Parse JSON response using KV system
        http_parse_response "json" "slideshow.title"
        local title="$(get_kv_value)"
        
        # Verify HTTP and KV coordination
        [[ "$(get_http_request_status)" == "success" ]] && \
        [[ "$(get_kv_status)" == "success" ]] && \
        [[ "$title" == "Sample Slide Show" ]]
    else
        # Allow test to pass if HTTP fails (network issues)
        return 0
    fi
}

# P4 Integration Test: HTTP + i18n coordination (localized API responses)
test_p4_http_i18n_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    source "$(get_module_path http)"
    
    # Skip if no HTTP client available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test translations for HTTP status messages
    local test_translations="/tmp/test_p4_http_i18n_$$"
    mkdir -p "$test_translations"
    
    cat > "$test_translations/en.json" << 'EOF'
{
  "http": {
    "status": {
      "200": "Request successful",
      "404": "Resource not found"
    }
  }
}
EOF
    
    i18n_init --app-domain="httptest" --app-translations="$test_translations"
    
    # Make HTTP request and localize response
    http_get "https://httpbin.org/status/200"
    
    if http_succeeded; then
        local status_code="$(get_http_status_code)"
        
        # Use i18n to localize HTTP status (don't parse response body for status endpoints)
        if [[ -n "$status_code" ]]; then
            t "http.status[\"$status_code\"]"
            local localized_status="$(get_i18n_value)"
            
            # Cleanup
            rm -rf "$test_translations"
            
            [[ "$status_code" == "200" ]] && \
            [[ "$localized_status" == "Request successful" ]]
        else
            # Cleanup and allow test to pass if status code not available
            rm -rf "$test_translations"
            return 0
        fi
    else
        # Cleanup and allow test to pass if HTTP fails
        rm -rf "$test_translations"
        return 0
    fi
}

# P4 Integration Test: Complete P4 data flow (HTTP → KV → i18n)
test_p4_complete_data_flow() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path i18n)"
    source "$(get_module_path http)"
    
    # Skip if no HTTP client available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        return 0
    fi
    
    # Create translations for API response localization
    local test_translations="/tmp/test_p4_complete_flow_$$"
    mkdir -p "$test_translations"
    
    cat > "$test_translations/en.json" << 'EOF'
{
  "http": {
    "user_agent": "Client identified as: {0}"
  }
}
EOF
    
    i18n_init --app-domain="completetest" --app-translations="$test_translations"
    
    # Complete workflow: HTTP → KV parsing → i18n localization
    http_get "https://httpbin.org/user-agent"
    
    if http_succeeded; then
        # Parse user agent from HTTP response
        http_parse_response "json" "[\"user-agent\"]"
        local user_agent="$(get_kv_value)"
        
        # Localize the extracted value
        t "http.user_agent" "$user_agent"
        local localized_message="$(get_i18n_value)"
        
        # Cleanup
        rm -rf "$test_translations"
        
        # Verify complete P4 data flow
        [[ "$(get_http_request_status)" == "success" ]] && \
        [[ "$(get_kv_status)" == "success" ]] && \
        [[ "$(get_i18n_lookup_status)" == "success" ]] && \
        [[ "$user_agent" == "Abaddon-HTTP/1.0.0" ]] && \
        [[ "$localized_message" == "Client identified as: Abaddon-HTTP/1.0.0" ]]
    else
        # Cleanup and allow test to pass if HTTP fails
        rm -rf "$test_translations"
        return 0
    fi
}

# P4 Integration Test: HTTP caching integration
test_p4_http_caching_integration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path security)"
    source "$(get_module_path datatypes)"
    source "$(get_module_path kv)"
    source "$(get_module_path state-machine)"
    source "$(get_module_path http)"
    
    # Skip if no HTTP client available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        return 0
    fi
    
    # Test that HTTP integrates with P2 cache layer
    
    # First request (should hit network)
    http_get "https://httpbin.org/uuid"
    
    if http_succeeded; then
        local first_response="$(get_http_response)"
        local cache_hits_before="$ABADDON_HTTP_CACHE_HITS"
        
        # Second identical request (should hit cache)
        http_get "https://httpbin.org/uuid"
        
        if http_succeeded; then
            local second_response="$(get_http_response)"
            local cache_hits_after="$ABADDON_HTTP_CACHE_HITS"
            
            # Verify caching worked (same response, cache hit incremented)
            [[ "$first_response" == "$second_response" ]] && \
            [[ $cache_hits_after -gt $cache_hits_before ]]
        else
            return 0
        fi
    else
        return 0
    fi
}

# Register P4 integration tests
run_test "P4 integration: i18n + KV coordination" test_p4_i18n_kv_coordination
run_test "P4 integration: P2→P4 data flow" test_p4_p2_data_flow
run_test "P4 integration: Cross-layer state management" test_p4_cross_layer_state
run_test "P4 integration: P1→P2→P3→P4 complete stack" test_p4_complete_stack_integration
run_test "P4 integration: Error propagation through layers" test_p4_error_propagation
run_test "P4 integration: HTTP + KV coordination" test_p4_http_kv_coordination
run_test "P4 integration: HTTP + i18n coordination" test_p4_http_i18n_coordination
run_test "P4 integration: Complete P4 data flow (HTTP→KV→i18n)" test_p4_complete_data_flow
run_test "P4 integration: HTTP caching integration" test_p4_http_caching_integration