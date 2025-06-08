#!/usr/bin/env bash
# Abaddon Test Runner - TAP-compatible with Atlas logging
# Custom test framework for abaddon modules with proper isolation

set -euo pipefail

# Test framework configuration
readonly TEST_RUNNER_VERSION="1.0.0"
readonly TAP_VERSION="TAP version 13"

# Atlas-style logging with color detection
COLORS_SUPPORTED=false
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    TERM_COLORS=$(tput colors 2>/dev/null || echo 0)
    [[ $TERM_COLORS -gt 8 ]] && COLORS_SUPPORTED=true
fi

# Color definitions
if [[ "$COLORS_SUPPORTED" == "true" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly BOLD=''
    readonly NC=''
fi

# Test state tracking
declare -g TEST_COUNT=0
declare -g PASS_COUNT=0
declare -g FAIL_COUNT=0
declare -g SKIP_COUNT=0
declare -a TEST_RESULTS=()
declare -g CURRENT_SUITE=""

# Test isolation helpers
setup_test_env() {
    # Clean ABADDON_* variables
    for var in $(compgen -v ABADDON_); do
        unset "$var" 2>/dev/null || true
    done

    # Reset critical globals
    unset ABADDON_CORE_LOADED 2>/dev/null || true
    unset ABADDON_PLATFORM_LOADED 2>/dev/null || true
    unset ABADDON_PROGRESS_LOADED 2>/dev/null || true

    # Create isolated temp directory if needed
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        TEST_TEMP_DIR=$(mktemp -d -t "abaddon_test_XXXXXX")
        export TEST_TEMP_DIR
        trap "rm -rf '$TEST_TEMP_DIR'" EXIT
    fi
}

cleanup_test_env() {
    # Remove temp directory
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
        unset TEST_TEMP_DIR
    fi
}

# Logging functions
log_suite() {
    echo -e "${CYAN}# === $* ===${NC}"
}

log_test() {
    echo -e "${BLUE}# $*${NC}"
}

log_pass() {
    echo -e "${GREEN}ok $TEST_COUNT - $*${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
    echo -e "${RED}not ok $TEST_COUNT - $*${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

log_skip() {
    echo -e "${YELLOW}ok $TEST_COUNT - $* # SKIP${NC}"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

log_diagnostic() {
    echo -e "${YELLOW}# $*${NC}"
}

# Core testing functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    local expect_success="${3:-true}"

    TEST_COUNT=$((TEST_COUNT + 1))

    # Run test in isolated subshell
    local test_result
    if (
        setup_test_env
        "$test_function" 2>/dev/null
    ); then
        test_result="success"
    else
        test_result="failure"
    fi

    # Evaluate result
    if [[ "$expect_success" == "true" && "$test_result" == "success" ]] ||
        [[ "$expect_success" == "false" && "$test_result" == "failure" ]]; then
        log_pass "$test_name"
        TEST_RESULTS+=("PASS")
    else
        log_fail "$test_name"
        log_diagnostic "Expected: $expect_success, Got: $test_result"
        TEST_RESULTS+=("FAIL")
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_function="$2"
    local expected_output="$3"
    local match_type="${4:-exact}" # exact, contains, regex

    TEST_COUNT=$((TEST_COUNT + 1))

    # Capture output in isolated subshell
    local actual_output
    if actual_output=$(
        setup_test_env
        "$test_function" 2>/dev/null
    ); then
        # Check output match
        case "$match_type" in
        exact)
            if [[ "$actual_output" == "$expected_output" ]]; then
                log_pass "$test_name"
                TEST_RESULTS+=("PASS")
                return
            fi
            ;;
        contains)
            if [[ "$actual_output" == *"$expected_output"* ]]; then
                log_pass "$test_name"
                TEST_RESULTS+=("PASS")
                return
            fi
            ;;
        regex)
            if [[ "$actual_output" =~ $expected_output ]]; then
                log_pass "$test_name"
                TEST_RESULTS+=("PASS")
                return
            fi
            ;;
        esac

        log_fail "$test_name"
        log_diagnostic "Expected ($match_type): '$expected_output'"
        log_diagnostic "Actual: '$actual_output'"
        TEST_RESULTS+=("FAIL")
    else
        log_fail "$test_name - function failed"
        log_diagnostic "Function '$test_function' exited with error"
        TEST_RESULTS+=("FAIL")
    fi
}

skip_test() {
    local test_name="$1"
    local reason="$2"

    TEST_COUNT=$((TEST_COUNT + 1))
    log_skip "$test_name ($reason)"
    TEST_RESULTS+=("SKIP")
}

# Test suite runner
run_suite() {
    local suite_name="$1"
    shift
    local test_files=("$@")

    CURRENT_SUITE="$suite_name"
    log_suite "$suite_name"

    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            log_diagnostic "Loading test file: $test_file"
            # shellcheck source=/dev/null
            source "$test_file"
        else
            log_diagnostic "Test file not found: $test_file"
        fi
    done
}

# Test result reporting
print_summary() {
    echo
    echo -e "${BOLD}# Test Summary${NC}"
    echo -e "${CYAN}# Total: $TEST_COUNT${NC}"
    echo -e "${GREEN}# Passed: $PASS_COUNT${NC}"
    [[ $FAIL_COUNT -gt 0 ]] && echo -e "${RED}# Failed: $FAIL_COUNT${NC}"
    [[ $SKIP_COUNT -gt 0 ]] && echo -e "${YELLOW}# Skipped: $SKIP_COUNT${NC}"

    local success_rate=0
    if [[ $TEST_COUNT -gt 0 ]]; then
        success_rate=$((PASS_COUNT * 100 / TEST_COUNT))
    fi
    echo -e "${CYAN}# Success Rate: ${success_rate}%${NC}"

    # Exit with failure if any tests failed
    if [[ $FAIL_COUNT -gt 0 ]]; then
        exit 1
    fi
}

# Module path helpers
get_module_path() {
    local module="$1"
    echo "$(dirname "${BASH_SOURCE[0]}")/abaddon-${module}.sh"
}

# Test discovery and execution
discover_and_run_tests() {
    local test_spec="${1:-all}"
    local tests_dir="$(dirname "${BASH_SOURCE[0]}")/tests"

    echo "$TAP_VERSION"
    echo "# Abaddon Test Runner v${TEST_RUNNER_VERSION}"
    echo "# Test isolation: subshells + variable cleanup"
    echo "# Color support: $COLORS_SUPPORTED"
    echo

    # Determine which test files to run
    local test_files=()
    case "$test_spec" in
        all)
            test_files=("$tests_dir/core.sh" "$tests_dir/platform.sh" "$tests_dir/progress.sh" "$tests_dir/p1-integration.sh" "$tests_dir/cache.sh" "$tests_dir/validation.sh" "$tests_dir/kv.sh")
            ;;
        p1)
            test_files=("$tests_dir/core.sh" "$tests_dir/platform.sh" "$tests_dir/progress.sh" "$tests_dir/p1-integration.sh")
            ;;
        p2)
            test_files=("$tests_dir/cache.sh" "$tests_dir/validation.sh" "$tests_dir/kv.sh")
            ;;
        core|platform|progress|cache|validation|kv)
            test_files=("$tests_dir/${test_spec}.sh")
            ;;
        p1-integration)
            test_files=("$tests_dir/p1-integration.sh")
            ;;
        integration)
            # Backward compatibility - run p1-integration
            test_files=("$tests_dir/p1-integration.sh")
            ;;
        *)
            # Fallback to pattern matching for backward compatibility
            while IFS= read -r -d '' file; do
                test_files+=("$file")
            done < <(find "$tests_dir" -name "$test_spec" -type f -print0 2>/dev/null)
            ;;
    esac

    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo "# No test files found for: $test_spec"
        echo "# Available test suites: core, platform, progress, cache, validation, kv, p1-integration, p1, p2, all"
        echo "1..0"
        return 0
    fi

    # Run specified test suites
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            local suite_name
            suite_name=$(basename "$test_file" .sh)
            run_suite "$suite_name" "$test_file"
        fi
    done

    # Print TAP plan
    echo "1..$TEST_COUNT"

    # Print summary
    print_summary
}

# Main execution
main() {
    local test_suite="${1:-all}"

    case "$test_suite" in
    help|--help|-h)
        cat <<'EOF'
Abaddon Test Runner - TAP-compatible testing framework

Usage:
  abaddon-tests.sh [test_suite]

Test Suites:
  all          - Run all test suites (default)
  p1           - Run Phase 1 foundation tests (core, platform, progress, p1-integration)
  p2           - Run Phase 2 runtime tests (cache, validation, kv)
  core         - Run core module tests
  platform     - Run platform module tests  
  progress     - Run progress module tests
  cache        - Run cache module tests
  validation   - Run validation module tests
  kv           - Run kv module tests
  p1-integration - Run Phase 1 integration tests
  integration  - Run Phase 1 integration tests (backward compatibility)

Features:
  - TAP version 13 compatible output
  - Atlas-style logging with color detection
  - Test isolation via subshells
  - ABADDON_* variable cleanup
  - Temporary directory lifecycle management
  - No external dependencies (pure bash)

Examples:
  ./abaddon-tests.sh            # Run all tests
  ./abaddon-tests.sh core       # Run only core tests
  ./abaddon-tests.sh platform   # Run only platform tests
  ./abaddon-tests.sh progress   # Run only progress tests
EOF
        ;;
    *)
        discover_and_run_tests "$test_suite"
        ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
