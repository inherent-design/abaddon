# HTTP module tests
# Test functions for abaddon-http.sh - Generic HTTP client with response parsing integration

# Test module loading and dependencies
test_http_requires_dependencies() {
    # Should fail without required modules loaded
    source "$(get_module_path http)"
}

test_http_loads_with_dependencies() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    [[ "${ABADDON_HTTP_LOADED:-}" == "1" ]]
}

# Test HTTP state management
test_http_state_reset() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Set some state first
    ABADDON_HTTP_RESPONSE_BODY="test response"
    ABADDON_HTTP_STATUS="success"
    ABADDON_HTTP_STATUS_CODE="200"
    ABADDON_HTTP_LAST_URL="https://example.com"
    
    reset_http_state
    
    [[ -z "${ABADDON_HTTP_RESPONSE_BODY:-}" ]] && \
    [[ -z "${ABADDON_HTTP_STATUS:-}" ]] && \
    [[ -z "${ABADDON_HTTP_STATUS_CODE:-}" ]] && \
    [[ -z "${ABADDON_HTTP_LAST_URL:-}" ]]
}

test_http_set_error_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    reset_http_state
    set_http_error "test error message"
    
    [[ "${ABADDON_HTTP_STATUS:-}" == "error" ]] && \
    [[ "${ABADDON_HTTP_ERROR_MESSAGE:-}" == "test error message" ]]
}

test_http_set_success_state() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    reset_http_state
    set_http_success
    
    [[ "${ABADDON_HTTP_STATUS:-}" == "success" ]] && \
    [[ -z "${ABADDON_HTTP_ERROR_MESSAGE:-}" ]]
}

# Test HTTP client detection
test_http_client_detection() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Reset detection state
    ABADDON_HTTP_CLIENT_DETECTED="false"
    ABADDON_HTTP_CLIENT=""
    
    detect_http_client
    
    # Should detect at least one client (curl, wget, or fetch)
    [[ -n "${ABADDON_HTTP_CLIENT:-}" ]] && \
    [[ "${ABADDON_HTTP_CLIENT_DETECTED:-}" == "true" ]]
}

# Test URL validation
test_http_url_validation_valid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    validate_url "https://example.com"
}

test_http_url_validation_invalid() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    validate_url "not-a-url"
}

test_http_url_validation_invalid_scheme() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    validate_url "ssh://example.com"
}

test_http_url_validation_file_scheme() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    validate_url "file:///tmp/test.txt"
}

test_http_url_validation_ftp_scheme() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    if command -v curl >/dev/null 2>&1; then
        validate_url "ftp://example.com/file.txt"
    else
        # Should fail without curl
        validate_url "ftp://example.com/file.txt"
        local result=$?
        [[ $result -eq 1 ]]
    fi
}

# Test HTTP request input validation
test_http_request_missing_method() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    http_request "" "https://example.com"
}

test_http_request_missing_url() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    http_request "GET" ""
}

test_http_request_invalid_url() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    http_request "GET" "not-a-url"
}

# Test HTTP GET function
test_http_get_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    declare -F http_get >/dev/null
}

# Real HTTP integration tests using httpbin.org
test_http_real_json_get() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Test real HTTP GET with JSON response
    http_get "https://httpbin.org/json"
    
    if http_succeeded; then
        # Parse the JSON response
        http_parse_response "json" "slideshow.title"
        if [[ "$(get_kv_value)" == "Sample Slide Show" ]]; then
            return 0
        fi
    fi
    
    return 1
}

test_http_real_status_codes() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Test 404 status
    http_get "https://httpbin.org/status/404"
    
    if [[ "$(get_http_status_code)" == "404" ]]; then
        return 0
    fi
    
    return 1
}

test_http_real_user_agent() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Test custom user agent
    http_get "https://httpbin.org/user-agent"
    
    if http_succeeded; then
        http_parse_response "json" "[\"user-agent\"]"
        if [[ "$(get_kv_value)" == "Abaddon-HTTP/1.0.0" ]]; then
            return 0
        fi
    fi
    
    return 1
}

test_http_real_post_data() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Test POST with JSON data
    http_post "https://httpbin.org/post" '{"test": "data", "number": 42}'
    
    if http_succeeded; then
        # Verify the posted data was echoed back
        http_parse_response "json" "json.test"
        if [[ "$(get_kv_value)" == "data" ]]; then
            return 0
        fi
    fi
    
    return 1
}

test_http_get_state_tracking() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Mock successful execution (skip actual network call)
    # Test that state variables are set correctly
    ABADDON_HTTP_LAST_URL=""
    ABADDON_HTTP_LAST_METHOD=""
    
    # This will fail due to no network, but should set tracking variables
    http_get "https://httpbin.org/json" 2>/dev/null || true
    
    [[ "${ABADDON_HTTP_LAST_URL:-}" == "https://httpbin.org/json" ]] && \
    [[ "${ABADDON_HTTP_LAST_METHOD:-}" == "GET" ]]
}

# Test HTTP POST function
test_http_post_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    declare -F http_post >/dev/null
}

test_http_post_state_tracking() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Test that state variables are set correctly
    ABADDON_HTTP_LAST_URL=""
    ABADDON_HTTP_LAST_METHOD=""
    
    # This will fail due to no network, but should set tracking variables
    http_post "https://httpbin.org/post" "test data" 2>/dev/null || true
    
    [[ "${ABADDON_HTTP_LAST_URL:-}" == "https://httpbin.org/post" ]] && \
    [[ "${ABADDON_HTTP_LAST_METHOD:-}" == "POST" ]]
}

# Test HTTP PUT function
test_http_put_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    declare -F http_put >/dev/null
}

# Test HTTP DELETE function
test_http_delete_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    declare -F http_delete >/dev/null
}

# Test HTTP response parsing
test_http_parse_response_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    declare -F http_parse_response >/dev/null
}

test_http_parse_response_no_body() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    reset_http_state
    
    http_parse_response "json" "key"
}

test_http_parse_response_failed_request() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    reset_http_state
    ABADDON_HTTP_RESPONSE_BODY="test response"
    ABADDON_HTTP_STATUS="error"
    
    http_parse_response "json" "key"
}

# Test state accessor functions
test_http_get_response_accessor() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_RESPONSE_BODY="test response"
    
    [[ "$(get_http_response)" == "test response" ]]
}

test_http_get_status_accessor() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_STATUS="success"
    
    [[ "$(get_http_status)" == "success" ]]
}

test_http_get_status_code_accessor() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_STATUS_CODE="200"
    
    [[ "$(get_http_status_code)" == "200" ]]
}

test_http_get_headers_accessor() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_RESPONSE_HEADERS="Content-Type: application/json"
    
    [[ "$(get_http_headers)" == "Content-Type: application/json" ]]
}

test_http_get_error_accessor() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_ERROR_MESSAGE="test error"
    
    [[ "$(get_http_error)" == "test error" ]]
}

test_http_get_last_url_accessor() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_LAST_URL="https://example.com"
    
    [[ "$(get_http_last_url)" == "https://example.com" ]]
}

test_http_get_last_method_accessor() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_LAST_METHOD="POST"
    
    [[ "$(get_http_last_method)" == "POST" ]]
}

test_http_get_execution_time_accessor() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_EXECUTION_TIME="150ms"
    
    [[ "$(get_http_execution_time)" == "150ms" ]]
}

# Test success/failure check functions
test_http_succeeded_function() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_STATUS="success"
    http_succeeded
}

test_http_failed_function() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    ABADDON_HTTP_STATUS="error"
    http_failed
}

# Test HTTP statistics
test_http_stats_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    declare -F get_http_stats >/dev/null
}

test_http_stats_output() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Output the stats directly for run_test_with_output to check
    get_http_stats
}

# Test module validation
test_http_validate_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    declare -F http_validate >/dev/null
}

test_http_validate_success() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Should pass validation if HTTP client is available
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        http_validate
    else
        # Skip if no HTTP client available
        true
    fi
}

# Test module information
test_http_info_function_exists() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    declare -F http_info >/dev/null
}

test_http_info_output() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Output the info directly for run_test_with_output to check
    http_info
}

# Test configuration variables
test_http_configuration_defaults() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    [[ "${ABADDON_HTTP_USER_AGENT:-}" == "Abaddon-HTTP/1.0.0" ]] && \
    [[ "${ABADDON_HTTP_TIMEOUT:-}" == "30" ]] && \
    [[ "${ABADDON_HTTP_MAX_REDIRECTS:-}" == "5" ]] && \
    [[ "${ABADDON_HTTP_RETRY_COUNT:-}" == "3" ]] && \
    [[ "${ABADDON_HTTP_CACHE_ENABLED:-}" == "true" ]]
}

test_http_environment_override() {
    # Test environment variable override
    export ABADDON_HTTP_TIMEOUT="60"
    export ABADDON_HTTP_USER_AGENT="CustomAgent/1.0"
    
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    [[ "${ABADDON_HTTP_TIMEOUT:-}" == "60" ]] && \
    [[ "${ABADDON_HTTP_USER_AGENT:-}" == "CustomAgent/1.0" ]]
}

# Performance and integration tests
test_http_request_tracking() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    local initial_requests="${ABADDON_HTTP_REQUESTS:-0}"
    
    # This will fail but should increment request counter
    http_get "https://httpbin.org/json" 2>/dev/null || true
    
    [[ "${ABADDON_HTTP_REQUESTS:-0}" -gt "$initial_requests" ]]
}

# Test curl-specific functionality
test_http_curl_args_construction() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Test that curl implementation function exists
    declare -F execute_curl_request >/dev/null
}

# Test wget-specific functionality  
test_http_wget_args_construction() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Test that wget implementation function exists
    declare -F execute_wget_request >/dev/null
}

# Test fetch-specific functionality
test_http_fetch_args_construction() {
    source "$(get_module_path core)"
    source "$(get_module_path platform)"
    source "$(get_module_path cache)"
    source "$(get_module_path validation)"
    source "$(get_module_path kv)"
    source "$(get_module_path http)"
    
    # Test that fetch implementation function exists
    declare -F execute_fetch_request >/dev/null
}

# Register all HTTP tests
run_test "HTTP module requires dependencies (dependency check)" test_http_requires_dependencies false
run_test "HTTP module loads with all dependencies" test_http_loads_with_dependencies

run_test "HTTP state reset clears all state" test_http_state_reset
run_test "Set HTTP error state works" test_http_set_error_state
run_test "Set HTTP success state works" test_http_set_success_state

if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || command -v fetch >/dev/null 2>&1; then
    run_test "HTTP client detection finds available client" test_http_client_detection
else
    skip_test "HTTP client detection" "no HTTP client available (curl, wget, or fetch)"
fi

run_test "HTTP URL validation accepts valid HTTPS URLs" test_http_url_validation_valid
run_test "HTTP URL validation rejects invalid URLs" test_http_url_validation_invalid false
run_test "HTTP URL validation rejects unsupported schemes" test_http_url_validation_invalid_scheme false
run_test "HTTP URL validation accepts file:// URLs" test_http_url_validation_file_scheme

if command -v curl >/dev/null 2>&1; then
    run_test "HTTP URL validation accepts FTP URLs with curl" test_http_url_validation_ftp_scheme
else
    run_test "HTTP URL validation rejects FTP URLs without curl" test_http_url_validation_ftp_scheme false
fi

run_test "HTTP request fails without method" test_http_request_missing_method false
run_test "HTTP request fails without URL" test_http_request_missing_url false
run_test "HTTP request fails with invalid URL" test_http_request_invalid_url false

run_test "HTTP GET function exists" test_http_get_function_exists
run_test "HTTP GET tracks request state" test_http_get_state_tracking
run_test "HTTP POST function exists" test_http_post_function_exists
run_test "HTTP POST tracks request state" test_http_post_state_tracking
run_test "HTTP PUT function exists" test_http_put_function_exists
run_test "HTTP DELETE function exists" test_http_delete_function_exists

run_test "HTTP parse response function exists" test_http_parse_response_function_exists
run_test "HTTP parse response fails without body" test_http_parse_response_no_body false
run_test "HTTP parse response fails for failed requests" test_http_parse_response_failed_request false

run_test "Get HTTP response accessor works" test_http_get_response_accessor
run_test "Get HTTP status accessor works" test_http_get_status_accessor
run_test "Get HTTP status code accessor works" test_http_get_status_code_accessor
run_test "Get HTTP headers accessor works" test_http_get_headers_accessor
run_test "Get HTTP error accessor works" test_http_get_error_accessor
run_test "Get HTTP last URL accessor works" test_http_get_last_url_accessor
run_test "Get HTTP last method accessor works" test_http_get_last_method_accessor
run_test "Get HTTP execution time accessor works" test_http_get_execution_time_accessor

run_test "HTTP succeeded returns true for success" test_http_succeeded_function
run_test "HTTP failed returns true for error" test_http_failed_function

run_test "HTTP stats function exists" test_http_stats_function_exists
run_test_with_output "HTTP stats output includes statistics header" test_http_stats_output "HTTP Client Statistics" contains

if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || command -v fetch >/dev/null 2>&1; then
    run_test "HTTP module validation passes" test_http_validate_success
else
    skip_test "HTTP module validation" "no HTTP client available"
fi

run_test "HTTP validate function exists" test_http_validate_function_exists
run_test "HTTP info function exists" test_http_info_function_exists
run_test_with_output "HTTP info output includes module name" test_http_info_output "abaddon-http.sh" contains

run_test "HTTP configuration defaults are correct" test_http_configuration_defaults
run_test "HTTP environment override works" test_http_environment_override
run_test "HTTP request tracking increments counters" test_http_request_tracking

run_test "HTTP curl implementation function exists" test_http_curl_args_construction
run_test "HTTP wget implementation function exists" test_http_wget_args_construction
run_test "HTTP fetch implementation function exists" test_http_fetch_args_construction

# Real HTTP integration tests (network dependent)
if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    # Only run real HTTP tests if we have network tools available
    run_test "HTTP real JSON GET with parsing" test_http_real_json_get
    run_test "HTTP real status code handling" test_http_real_status_codes  
    run_test "HTTP real user agent verification" test_http_real_user_agent
    run_test "HTTP real POST data verification" test_http_real_post_data
else
    skip_test "Real HTTP integration tests" "no HTTP client available"
fi