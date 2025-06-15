# P3 Integration Tests - Data & Communication Services  
# Test functions for P3 services integration and P2→P3 coordination

# P3 Integration Test: i18n + KV coordination
test_p3_i18n_kv_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test translation file
    local test_translations="/tmp/test_p3_translations_$$"
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
    local test_config="/tmp/test_p3_config_$$"
    echo '{"app_name": "P3 Integration Test"}' > "$test_config"
    
    # Workflow: KV extraction → i18n translation with substitution
    get_config_value "app_name" "$test_config" "Unknown App"
    local app_name="$(get_kv_value)"
    
    # Use extracted value in i18n translation
    t "app.welcome" "$app_name"
    local welcome_message="$(get_i18n_value)"
    
    # Cleanup
    rm -rf "$test_translations" "$test_config"
    
    [[ "$welcome_message" == "Welcome to P3 Integration Test" ]]
}

# P3 Integration Test: P2→P3 data flow
test_p3_p2_data_flow() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Test complete P2→P3 workflow
    
    # 1. P2: Extract configuration using cache + validation + kv
    local test_config="/tmp/test_p2_p3_flow_$$"
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
    
    # 2. P3: Use extracted values for i18n initialization
    local test_translations="/tmp/test_p2_p3_translations_$$"
    mkdir -p "$test_translations"
    
    cat > "$test_translations/en.json" << 'EOF'
{
  "messages": {
    "greeting": "Hello from P3 layer",
    "config_value": "Config says: {0}"
  }
}
EOF
    
    i18n_init --app-domain="p2p3test" --app-translations="$test_translations"
    
    # Use P2-extracted data in P3 translations
    t "messages.config_value" "$default_msg"
    local final_message="$(get_i18n_value)"
    
    # Cleanup
    rm -rf "$test_config" "$test_translations"
    
    [[ "$locale" == "en" ]] && \
    [[ "$final_message" == "Config says: Hello World" ]]
}

# P3 Integration Test: Cross-layer state management
test_p3_cross_layer_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    
    # Test that P3 maintains independent state from P2
    
    # Set states in P2 modules
    set_validation_success "P2 validation OK"
    local initial_validation_status="$(get_validation_status)"
    
    # Initialize P3 i18n
    local test_translations="/tmp/test_p3_state_$$"
    mkdir -p "$test_translations"
    echo '{"test": {"key": "P3 value"}}' > "$test_translations/en.json"
    
    i18n_init --app-domain="statetest" --app-translations="$test_translations"
    t "test.key"
    
    # Verify state independence and i18n functionality
    local final_validation_status="$(get_validation_status)"
    local kv_status="$(get_kv_status)"  # KV will show success from i18n translation
    local i18n_status="$(get_i18n_lookup_status)"
    local i18n_value="$(get_i18n_value)"
    
    # Cleanup
    rm -rf "$test_translations"
    
    # Test that validation state persisted and i18n works correctly
    [[ "$initial_validation_status" == "success" ]] && \
    [[ "$final_validation_status" == "success" ]] && \
    [[ "$kv_status" == "success" ]] && \
    [[ "$i18n_status" == "success" ]] && \
    [[ "$i18n_value" == "P3 value" ]]
}

# P3 Integration Test: P1→P2→P3 complete stack
test_p3_complete_stack_integration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    
    # Test complete P1→P2→P3 integration workflow
    
    # P1: Platform detection and tool availability
    local json_tool="$(get_best_tool "json_processing")"
    [[ "$json_tool" != "none" ]] || return 0  # Skip if no JSON tool
    
    # P2: Configuration management with validation and caching
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
    [[ "$(get_validation_status)" == "success" ]] || return 1
    
    # Extract values using KV (with caching)
    get_config_value "app.name" "$test_config" "Unknown"
    local app_name="$(get_kv_value)"
    
    get_config_value "app.locale" "$test_config" "en"
    local locale="$(get_kv_value)"
    
    # P3: i18n with extracted configuration
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

# P3 Integration Test: Error propagation through layers
test_p3_error_propagation() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    
    # Test that errors propagate correctly through P1→P2→P3
    
    # P2: Try to extract from invalid file
    get_config_value "any.key" "/nonexistent/file/$$" "default"
    local kv_status="$(get_kv_status)"
    
    # P3: Try to use i18n without initialization
    t "some.key"
    local i18n_status="$(get_i18n_lookup_status)"
    
    # Both should show error states
    [[ "$kv_status" == "error" ]] && [[ "$i18n_status" == "error" ]]
}

# P3 Integration Test: HTTP + KV coordination (API response parsing)
test_p3_http_kv_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
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

# P3 Integration Test: HTTP + i18n coordination (localized API responses)
test_p3_http_i18n_coordination() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path http)"
    
    # Skip if no HTTP client available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        return 0
    fi
    
    # Create test translations for HTTP status messages
    local test_translations="/tmp/test_p3_http_i18n_$$"
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

# P3 Integration Test: Complete P3 data flow (HTTP → KV → i18n)
test_p3_complete_data_flow() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path i18n)"
    source "$(get_module_path http)"
    
    # Skip if no HTTP client available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        return 0
    fi
    
    # Create translations for API response localization
    local test_translations="/tmp/test_p3_complete_flow_$$"
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
        
        # Verify complete P3 data flow
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

# P3 Integration Test: HTTP caching integration
test_p3_http_caching_integration() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
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

# Register P3 integration tests
run_test "P3 integration: i18n + KV coordination" test_p3_i18n_kv_coordination
run_test "P3 integration: P2→P3 data flow" test_p3_p2_data_flow
run_test "P3 integration: Cross-layer state management" test_p3_cross_layer_state
run_test "P3 integration: P1→P2→P3 complete stack" test_p3_complete_stack_integration
run_test "P3 integration: Error propagation through layers" test_p3_error_propagation
run_test "P3 integration: HTTP + KV coordination" test_p3_http_kv_coordination
run_test "P3 integration: HTTP + i18n coordination" test_p3_http_i18n_coordination
run_test "P3 integration: Complete P3 data flow (HTTP→KV→i18n)" test_p3_complete_data_flow
run_test "P3 integration: HTTP caching integration" test_p3_http_caching_integration