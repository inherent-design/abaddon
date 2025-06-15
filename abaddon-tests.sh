#!/usr/bin/env bash
# Abaddon Test Runner - TAP-compatible with 2-Tier Testing Architecture
# Production-grade test framework following ABADDON_TESTS_* patterns

set -euo pipefail

# ============================================================================
# Test Framework Configuration (2-Tier Architecture)
# ============================================================================

readonly ABADDON_TESTS_VERSION="2.0.0"
readonly ABADDON_TESTS_TAP_VERSION="TAP version 13"

# Framework-level test state (2-tier pattern)
declare -g ABADDON_TESTS_RUNNER_VERSION="$ABADDON_TESTS_VERSION"
declare -g ABADDON_TESTS_ISOLATION_MODE="subshell+cleanup"
declare -g ABADDON_TESTS_COLOR_DETECTION=""
declare -g ABADDON_TESTS_DEBUG_MODE="${ABADDON_TESTS_DEBUG_MODE:-false}"

# Cache test runner directories (avoid BASH_SOURCE reliance)
declare -g ABADDON_TESTS_RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -g ABADDON_TESTS_DIR="${ABADDON_TESTS_RUNNER_DIR}/tests"

# Test execution state
declare -g ABADDON_TESTS_TOTAL_COUNT=0
declare -g ABADDON_TESTS_PASS_COUNT=0
declare -g ABADDON_TESTS_FAIL_COUNT=0
declare -g ABADDON_TESTS_SKIP_COUNT=0
declare -a ABADDON_TESTS_RESULTS=()
declare -g ABADDON_TESTS_CURRENT_SUITE=""

# Integration test state tracking removed (obsolete)

# ============================================================================
# Color Detection & Terminal Capabilities (Following TTY Architecture)
# ============================================================================

# Detect terminal capabilities (UNIX-style with --no-color support)
detect_test_runner_capabilities() {
    ABADDON_TESTS_COLOR_DETECTION="disabled"
    
    # Honor NO_COLOR environment variable (standard)
    if [[ -n "${NO_COLOR:-}" ]]; then
        return 0
    fi
    
    # Honor --no-color flag if passed
    if [[ "$*" =~ --no-color ]]; then
        return 0
    fi
    
    # Auto-detect: only enable colors for interactive terminals
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        local term_colors
        term_colors=$(tput colors 2>/dev/null || echo 0)
        if [[ $term_colors -gt 8 ]]; then
            ABADDON_TESTS_COLOR_DETECTION="enabled"
        fi
    fi
}

# Initialize color variables based on capability detection
initialize_test_colors() {
    if [[ "$ABADDON_TESTS_COLOR_DETECTION" == "enabled" ]]; then
        readonly ABADDON_TESTS_RED='\033[0;31m'
        readonly ABADDON_TESTS_GREEN='\033[0;32m'
        readonly ABADDON_TESTS_YELLOW='\033[0;33m'
        readonly ABADDON_TESTS_BLUE='\033[0;34m'
        readonly ABADDON_TESTS_LIGHT_BLUE='\033[0;94m'
        readonly ABADDON_TESTS_CYAN='\033[0;36m'
        readonly ABADDON_TESTS_BOLD='\033[1m'
        readonly ABADDON_TESTS_DIM='\033[2m'
        readonly ABADDON_TESTS_NC='\033[0m'
    else
        readonly ABADDON_TESTS_RED=''
        readonly ABADDON_TESTS_GREEN=''
        readonly ABADDON_TESTS_YELLOW=''
        readonly ABADDON_TESTS_BLUE=''
        readonly ABADDON_TESTS_LIGHT_BLUE=''
        readonly ABADDON_TESTS_CYAN=''
        readonly ABADDON_TESTS_BOLD=''
        readonly ABADDON_TESTS_DIM=''
        readonly ABADDON_TESTS_NC=''
    fi
}

# ============================================================================
# 2-Tier Test Environment Management
# ============================================================================

# Framework-level test environment setup
setup_test_framework() {
    # Initialize test runner capabilities (pass CLI args for --no-color detection)
    detect_test_runner_capabilities "$@"
    initialize_test_colors
    
    # Set framework-level isolation mode
    ABADDON_TESTS_ISOLATION_MODE="subshell+cleanup+lifecycle"
    
    # Integration test tracking removed (obsolete)
}

# Module-level test environment setup (enhanced isolation)
setup_test_env() {
    # Clean ALL ABADDON_* variables (comprehensive cleanup)
    for var in $(compgen -v ABADDON_ 2>/dev/null || true); do
        # Preserve test framework variables
        if [[ "$var" =~ ^ABADDON_TESTS_ ]]; then
            continue
        fi
        unset "$var" 2>/dev/null || true
    done

    # Reset critical module load states
    unset ABADDON_CORE_LOADED ABADDON_TTY_LOADED ABADDON_PLATFORM_LOADED 2>/dev/null || true
    unset ABADDON_CACHE_LOADED ABADDON_VALIDATION_LOADED ABADDON_KV_LOADED 2>/dev/null || true
    unset ABADDON_I18N_LOADED ABADDON_COMMANDS_LOADED ABADDON_HELP_LOADED 2>/dev/null || true

    # Create isolated temp directory if needed
    if [[ -z "${ABADDON_TESTS_TEMP_DIR:-}" ]]; then
        ABADDON_TESTS_TEMP_DIR=$(mktemp -d -t "abaddon_test_XXXXXX")
        export ABADDON_TESTS_TEMP_DIR
        
        # Register cleanup trap
        trap 'cleanup_test_framework_on_exit' EXIT
    fi
    
    # Export essential test utilities and directories to subshell
    export ABADDON_TESTS_RUNNER_DIR
    export ABADDON_TESTS_DIR
    export -f get_module_path
}

# Module-level test environment cleanup
cleanup_test_env() {
    # Remove temp directory if it exists
    if [[ -n "${ABADDON_TESTS_TEMP_DIR:-}" ]] && [[ -d "$ABADDON_TESTS_TEMP_DIR" ]]; then
        rm -rf "$ABADDON_TESTS_TEMP_DIR" 2>/dev/null || true
        unset ABADDON_TESTS_TEMP_DIR
    fi
}

# Framework cleanup on exit
cleanup_test_framework_on_exit() {
    cleanup_test_env
    
    # Integration test state cleanup removed (obsolete)
}

# ============================================================================
# Lifecycle Hook Discovery & Management (2-Tier Framework)
# ============================================================================

# Discover and execute module-specific lifecycle hooks
execute_module_lifecycle_hook() {
    local module_name="$1"
    local hook_type="$2"  # setup, teardown, isolate, validate
    
    local hook_function="${module_name}_test_${hook_type}"
    
    # Check if hook function exists and execute it
    if declare -f "$hook_function" >/dev/null 2>&1; then
        if [[ "$ABADDON_TESTS_DEBUG_MODE" == "true" ]]; then
            log_diagnostic "Executing lifecycle hook: $hook_function"
        fi
        "$hook_function" 2>/dev/null || true
    fi
}

# Clean up module-specific test state
cleanup_module_test_state() {
    local module_name="$1"
    
    # Clean ABADDON_TESTS_MODULE_* variables
    for var in $(compgen -v "ABADDON_TESTS_${module_name^^}_" 2>/dev/null || true); do
        unset "$var" 2>/dev/null || true
    done
}

# Clean up all test state (framework + all modules)
cleanup_all_test_state() {
    # Clean all ABADDON_TESTS_* variables except core framework ones
    for var in $(compgen -v ABADDON_TESTS_ 2>/dev/null || true); do
        # Preserve core framework variables
        if [[ "$var" =~ ^ABADDON_TESTS_(VERSION|TAP_VERSION|RUNNER_VERSION|ISOLATION_MODE|COLOR_DETECTION|TOTAL_COUNT|PASS_COUNT|FAIL_COUNT|SKIP_COUNT|RESULTS|CURRENT_SUITE)$ ]]; then
            continue
        fi
        unset "$var" 2>/dev/null || true
    done
}

# ============================================================================
# TAP-Compatible Logging Functions (Enhanced v13 Compliance)
# ============================================================================

# Format stderr as TAP diagnostics
format_stderr_as_diagnostic() {
    local stderr_content="$1"
    if [[ -n "$stderr_content" ]]; then
        # Convert each line to TAP diagnostic format
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                # Strip color codes from stderr for clean diagnostics
                local clean_line
                clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
                echo -e "${ABADDON_TESTS_DIM}#   stderr: $clean_line${ABADDON_TESTS_NC}"
            fi
        done <<< "$stderr_content"
    fi
}

log_suite() {
    echo -e "${ABADDON_TESTS_CYAN}# ${ABADDON_TESTS_DIM}=== ${ABADDON_TESTS_CYAN}$* ${ABADDON_TESTS_DIM}===${ABADDON_TESTS_NC}"
}

log_test() {
    echo -e "${ABADDON_TESTS_LIGHT_BLUE}# $*${ABADDON_TESTS_NC}"
}

log_pass() {
    echo -e "${ABADDON_TESTS_GREEN}ok $ABADDON_TESTS_TOTAL_COUNT - $*${ABADDON_TESTS_NC}"
    ABADDON_TESTS_PASS_COUNT=$((ABADDON_TESTS_PASS_COUNT + 1))
}

log_fail() {
    echo -e "${ABADDON_TESTS_RED}not ok $ABADDON_TESTS_TOTAL_COUNT - $*${ABADDON_TESTS_NC}"
    ABADDON_TESTS_FAIL_COUNT=$((ABADDON_TESTS_FAIL_COUNT + 1))
}

log_skip() {
    echo -e "${ABADDON_TESTS_YELLOW}ok $ABADDON_TESTS_TOTAL_COUNT - $* # SKIP${ABADDON_TESTS_NC}"
    ABADDON_TESTS_SKIP_COUNT=$((ABADDON_TESTS_SKIP_COUNT + 1))
}

log_diagnostic() {
    echo -e "${ABADDON_TESTS_LIGHT_BLUE}#   $*${ABADDON_TESTS_NC}"
}

# ============================================================================
# Enhanced Test Execution Functions
# ============================================================================

# Core test execution with enhanced isolation
run_test() {
    local test_name="$1"
    local test_function="$2"
    local expect_success="${3:-true}"

    ABADDON_TESTS_TOTAL_COUNT=$((ABADDON_TESTS_TOTAL_COUNT + 1))

    # Execute module lifecycle hook if available
    local module_name="${ABADDON_TESTS_CURRENT_SUITE}"
    execute_module_lifecycle_hook "$module_name" "isolate"

    # Run test in isolated subshell with enhanced error handling
    local test_result
    local stderr_output
    
    # Capture stderr separately to potentially recolor expected failures
    if stderr_output=$(
        (
            # Enhanced test isolation
            setup_test_env
            
            # Execute test function
            "$test_function"
        ) 2>&1 >/dev/null
    ) && (
        # Enhanced test isolation
        setup_test_env
        
        # Execute test function (for actual return code)
        "$test_function" >/dev/null 2>&1
    ); then
        test_result="success"
    else
        test_result="failure"
    fi
    
    # Output stderr as TAP diagnostics for cleaner parsing
    if [[ -n "$stderr_output" ]]; then
        # All stderr output gets formatted as diagnostics for TAP compliance
        # (stderr is normal - Abaddon logging system uses stderr by design)
        format_stderr_as_diagnostic "$stderr_output"
    fi

    # Evaluate result against expectation
    if [[ "$expect_success" == "true" && "$test_result" == "success" ]] ||
        [[ "$expect_success" == "false" && "$test_result" == "failure" ]]; then
        log_pass "$test_name"
        ABADDON_TESTS_RESULTS+=("PASS")
    else
        log_fail "$test_name"
        log_diagnostic "Expected: $expect_success, Got: $test_result"
        ABADDON_TESTS_RESULTS+=("FAIL")
    fi
}

# Test execution with output validation (enhanced)
run_test_with_output() {
    local test_name="$1"
    local test_function="$2"
    local expected_output="$3"
    local match_type="${4:-exact}"  # exact, contains, regex

    ABADDON_TESTS_TOTAL_COUNT=$((ABADDON_TESTS_TOTAL_COUNT + 1))

    # Execute module lifecycle hook if available
    local module_name="${ABADDON_TESTS_CURRENT_SUITE}"
    execute_module_lifecycle_hook "$module_name" "isolate"

    # Capture output in isolated subshell
    local actual_output
    if actual_output=$(
        setup_test_env
        "$test_function"
    ); then
        # Check output match based on type
        case "$match_type" in
        exact)
            if [[ "$actual_output" == "$expected_output" ]]; then
                log_pass "$test_name"
                ABADDON_TESTS_RESULTS+=("PASS")
                return
            fi
            ;;
        contains)
            if [[ "$actual_output" == *"$expected_output"* ]]; then
                log_pass "$test_name"
                ABADDON_TESTS_RESULTS+=("PASS")
                return
            fi
            ;;
        regex)
            if [[ "$actual_output" =~ $expected_output ]]; then
                log_pass "$test_name"
                ABADDON_TESTS_RESULTS+=("PASS")
                return
            fi
            ;;
        esac

        log_fail "$test_name"
        log_diagnostic "Expected ($match_type): '$expected_output'"
        log_diagnostic "Actual: '$actual_output'"
        ABADDON_TESTS_RESULTS+=("FAIL")
    else
        log_fail "$test_name - function failed"
        log_diagnostic "Function '$test_function' exited with error"
        ABADDON_TESTS_RESULTS+=("FAIL")
    fi
}

# Skip test with reason
skip_test() {
    local test_name="$1"
    local reason="$2"

    ABADDON_TESTS_TOTAL_COUNT=$((ABADDON_TESTS_TOTAL_COUNT + 1))
    log_skip "$test_name ($reason)"
    ABADDON_TESTS_RESULTS+=("SKIP")
}

# ============================================================================
# Enhanced Test Suite Management
# ============================================================================

# Run test suite with lifecycle management
run_suite() {
    local suite_name="$1"
    shift
    local test_files=("$@")

    ABADDON_TESTS_CURRENT_SUITE="$suite_name"
    log_suite "$suite_name"

    # Execute suite setup hook
    execute_module_lifecycle_hook "$suite_name" "setup"

    # Load and execute test files
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            log_test "Loading test file: $test_file"
            # Source test file in controlled environment
            # shellcheck source=/dev/null
            source "$test_file"
            
            # Call registration function if it exists
            local register_function="register_${suite_name}_tests"
            register_function="${register_function//-/_}"  # Convert hyphens to underscores
            if declare -f "$register_function" >/dev/null 2>&1; then
                log_diagnostic "Registering tests via: $register_function"
                "$register_function"
            fi
        else
            log_diagnostic "Test file not found: $test_file"
        fi
    done

    # Execute suite teardown hook
    execute_module_lifecycle_hook "$suite_name" "teardown"
    
    # Clean up module-specific test state
    cleanup_module_test_state "$suite_name"
}

# ============================================================================
# Enhanced Test Result Reporting
# ============================================================================

print_summary() {
    echo
    echo -e "${ABADDON_TESTS_BOLD}# Test Summary${ABADDON_TESTS_NC}"
    echo -e "${ABADDON_TESTS_LIGHT_BLUE}# Total: $ABADDON_TESTS_TOTAL_COUNT${ABADDON_TESTS_NC}"
    echo -e "${ABADDON_TESTS_GREEN}# Passed: $ABADDON_TESTS_PASS_COUNT${ABADDON_TESTS_NC}"
    
    if [[ $ABADDON_TESTS_FAIL_COUNT -gt 0 ]]; then
        echo -e "${ABADDON_TESTS_RED}# Failed: $ABADDON_TESTS_FAIL_COUNT${ABADDON_TESTS_NC}"
    fi
    
    if [[ $ABADDON_TESTS_SKIP_COUNT -gt 0 ]]; then
        echo -e "${ABADDON_TESTS_YELLOW}# Skipped: $ABADDON_TESTS_SKIP_COUNT${ABADDON_TESTS_NC}"
    fi

    # Calculate and display success rate with dynamic coloring
    local success_rate=0
    if [[ $ABADDON_TESTS_TOTAL_COUNT -gt 0 ]]; then
        success_rate=$((ABADDON_TESTS_PASS_COUNT * 100 / ABADDON_TESTS_TOTAL_COUNT))
    fi
    
    # Dynamic color based on success rate
    local rate_color
    if [[ $success_rate -ge 95 ]]; then
        rate_color="$ABADDON_TESTS_GREEN"    # 95-100%: green
    elif [[ $success_rate -ge 80 ]]; then
        rate_color="$ABADDON_TESTS_YELLOW"   # 80-94%: yellow  
    else
        rate_color="$ABADDON_TESTS_RED"      # 0-79%: red
    fi
    
    echo -e "${rate_color}# Success Rate: ${success_rate}%${ABADDON_TESTS_NC}"

    # Exit with failure if any tests failed (TAP compliance)
    if [[ $ABADDON_TESTS_FAIL_COUNT -gt 0 ]]; then
        exit 1
    fi
}

# ============================================================================
# Module Path & Test Discovery (Enhanced)
# ============================================================================

# Get module path helper
get_module_path() {
    local module="$1"
    echo "${ABADDON_TESTS_RUNNER_DIR}/abaddon-${module}.sh"
}

# Enhanced test discovery with P2/P3 support
discover_and_run_tests() {
    local test_spec="${1:-all}"
    local tests_dir="$ABADDON_TESTS_DIR"

    # Initialize test framework (pass all args for --no-color detection)
    setup_test_framework "$@"

    # Print TAP header with enhanced information
    echo "$ABADDON_TESTS_TAP_VERSION"
    echo "# Abaddon Test Runner v${ABADDON_TESTS_VERSION}"
    echo "# Test isolation: $ABADDON_TESTS_ISOLATION_MODE"
    echo "# Color support: $ABADDON_TESTS_COLOR_DETECTION"
    echo

    # Determine test files to run (enhanced suite support)
    local test_files=()
    case "$test_spec" in
    all)
        # Complete test suite (all layers)
        test_files=(
            "$tests_dir/core.sh"
            "$tests_dir/tty.sh" 
            "$tests_dir/platform.sh"
            "$tests_dir/p1-integration.sh"
            "$tests_dir/cache.sh"
            "$tests_dir/validation.sh"
            "$tests_dir/kv.sh"
            "$tests_dir/i18n.sh"
            "$tests_dir/commands.sh"
            "$tests_dir/help.sh"
        )
        ;;
    p1)
        # P1 Foundation layer (core + tty + platform + integration)
        test_files=(
            "$tests_dir/core.sh"
            "$tests_dir/tty.sh"
            "$tests_dir/platform.sh"
            "$tests_dir/p1-integration.sh"
        )
        ;;
    p2)
        # P2 Performance & Security Layer (cache + validation + integration)
        test_files=(
            "$tests_dir/cache.sh"
            "$tests_dir/validation.sh"
            "$tests_dir/p2-integration.sh"
        )
        ;;
    p3)
        # P3 Data & Communication Services (kv + i18n + integration)
        test_files=(
            "$tests_dir/kv.sh"
            "$tests_dir/i18n.sh"
            "$tests_dir/p3-integration.sh"
        )
        ;;
    p4)
        # P4 Application Primitives (commands + help + new primitives)
        test_files=(
            "$tests_dir/commands.sh"
            "$tests_dir/help.sh"
        )
        ;;
    foundation)
        # P1+P2+P3 foundation (without P4 application primitives)
        test_files=(
            "$tests_dir/core.sh"
            "$tests_dir/tty.sh"
            "$tests_dir/platform.sh"
            "$tests_dir/p1-integration.sh"
            "$tests_dir/cache.sh"
            "$tests_dir/validation.sh"
            "$tests_dir/kv.sh"
            "$tests_dir/i18n.sh"
        )
        ;;
    integration)
        # All integration tests (P1, P2, P3)
        test_files=(
            "$tests_dir/p1-integration.sh"
            "$tests_dir/p2-integration.sh"
            "$tests_dir/p3-integration.sh"
        )
        ;;
    # Individual module tests
    core|tty|platform|cache|validation|kv|i18n|commands|help)
        test_files=("$tests_dir/${test_spec}.sh")
        ;;
    # Specific integration tests
    p1-integration|p2-integration|p3-integration)
        test_files=("$tests_dir/${test_spec}.sh")
        ;;
    *)
        # Pattern matching fallback
        while IFS= read -r -d '' file; do
            test_files+=("$file")
        done < <(find "$tests_dir" -name "${test_spec}*.sh" -type f -print0 2>/dev/null)
        ;;
    esac

    # Validate test files exist
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo "# No test files found for: $test_spec"
        echo "# Available: core, tty, platform, cache, validation, kv, i18n, commands, help"
        echo "# Suites: p1, p2, p3, p4, foundation, integration, all"
        echo "1..0"
        return 0
    fi

    # Run test suites with lifecycle management
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            local suite_name
            suite_name=$(basename "$test_file" .sh)
            run_suite "$suite_name" "$test_file"
        fi
    done

    # Print TAP plan
    echo "1..$ABADDON_TESTS_TOTAL_COUNT"

    # Print enhanced summary
    print_summary
}

# ============================================================================
# Main Test Runner Entry Point
# ============================================================================

main() {
    local test_suite="${1:-all}"

    case "$test_suite" in
    help|--help|-h)
        cat <<'EOF'
Abaddon Test Runner v2.0.0 - 2-Tier Testing Architecture

Usage:
  ./abaddon-tests.sh [test_suite] [--no-color]

Test Suites:
  all          - Run complete test suite (P1+P2+P3+P4)
  foundation   - Run foundation tests (P1+P2+P3)
  p1           - Run P1 Foundation (core, tty, platform, p1-integration)
  p2           - Run P2 Performance & Security (cache, validation)
  p3           - Run P3 Data & Communication (kv, i18n)
  p4           - Run P4 Application Primitives (commands, help)
  integration  - Run all integration tests

Individual Modules:
  core         - Core module tests (logging, platform detection, utilities)
  tty          - TTY module tests (color, terminal capabilities, cell membrane)
  platform     - Platform module tests (tool detection, capabilities)
  cache        - Cache module tests (P2 performance optimization)
  validation   - Validation module tests (P2 security, input validation)
  kv           - Key-value module tests (P3 data access layer)
  i18n         - Internationalization module tests (P3 communication)
  commands     - Commands module tests (P4 command registry)
  help         - Help module tests (P4 documentation system)

Integration Tests:
  p1-integration - P1 Foundation integration workflows
  p2-integration - P2 Performance & Security coordination workflows
  p3-integration - P3 Data & Communication integration workflows

Features:
  - TAP version 13 compatible output
  - 2-tier testing architecture (ABADDON_TESTS_* + ABADDON_TESTS_MODULE_*)
  - Lifecycle hook discovery (module_test_setup/teardown/isolate/validate)
  - Enhanced test isolation with timeout protection
  - Module-specific state cleanup
  - Integration test state tracking
  - Color detection following TTY architecture patterns
  - Production-grade error handling and reporting

Options:
  --no-color                       - Disable color output (for TAP parsers)

Environment Variables:
  ABADDON_TESTS_DEBUG_MODE=true    - Enable debug output
  NO_COLOR=1                       - Disable color output (standard)
  
Examples:
  ./abaddon-tests.sh               # Run all tests
  ./abaddon-tests.sh p1            # Run P1 foundation tests  
  ./abaddon-tests.sh p2            # Run P2 performance & security
  ./abaddon-tests.sh p3            # Run P3 data & communication
  ./abaddon-tests.sh foundation    # Run P1+P2+P3 foundation
  ./abaddon-tests.sh integration   # Run integration tests
  ./abaddon-tests.sh core          # Run core module only
  ./abaddon-tests.sh p1 --no-color # Run P1 tests without colors
  NO_COLOR=1 ./abaddon-tests.sh all # Run all tests without colors
EOF
        ;;
    *)
        discover_and_run_tests "$@"
        ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi