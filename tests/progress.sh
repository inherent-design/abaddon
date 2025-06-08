# Progress module tests
# Test functions for abaddon-progress.sh

# Test module loading and dependencies
test_progress_requires_core() {
    # Should fail without core loaded
    source "$(get_module_path progress)"
}

test_progress_loads_with_core() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    [[ "${ABADDON_PROGRESS_LOADED:-}" == "1" ]]
}

# Test terminal feature detection
test_progress_detect_terminal_features() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    detect_terminal_features
    # Should set global variables
    [[ -n "${TERM_COLORS:-}" ]] && [[ -n "${TERM_INTERACTIVE:-}" ]] && [[ -n "${TERM_WIDTH:-}" ]]
}

# Test spinner frame functions
test_progress_get_spinner_frames_basic() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    get_spinner_frames "basic"
}

test_progress_get_spinner_frames_unicode() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    get_spinner_frames "unicode"
}

test_progress_get_spinner_frames_dots() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    get_spinner_frames "dots"
}

test_progress_get_spinner_frames_auto() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    get_spinner_frames "auto"
}

# Test progress bar (non-interactive mode)
test_progress_show_progress_simple() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    # Force non-interactive mode for testing
    TERM_INTERACTIVE=false
    show_progress 5 10 "test progress"
}

test_progress_show_progress_complete() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    TERM_INTERACTIVE=false
    show_progress 10 10 "completed"
}

# Test status icons
test_progress_status_icon_success() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    status_icon "success" false
}

test_progress_status_icon_error() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    status_icon "error" false
}

test_progress_status_icon_warning() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    status_icon "warning" false
}

test_progress_status_icon_info() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    status_icon "info" false
}

test_progress_status_icon_working() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    status_icon "working" false
}

test_progress_status_icon_custom() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    status_icon "custom_status" false
}

# Test formatting functions
test_progress_format_bold() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    format_bold "test text"
}

test_progress_format_dim() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    format_dim "test text"
}

test_progress_format_underline() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    format_underline "test text"
}

# Test section headers
test_progress_section_header_level1() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    section_header "Test Section" 1
}

test_progress_section_header_level2() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    section_header "Test Section" 2
}

test_progress_section_header_level3() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    section_header "Test Section" 3
}

test_progress_section_header_default() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    section_header "Test Section"
}

# Test table functions (non-interactive mode)
test_progress_create_table() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    TERM_INTERACTIVE=false
    TERM_COLORS=0
    create_table "Column1" "Column2" "Column3"
}

test_progress_add_table_row() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    TERM_INTERACTIVE=false
    TERM_COLORS=0
    add_table_row "Value1" "Value2" "Value3"
}

test_progress_close_table() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    TERM_INTERACTIVE=false
    TERM_COLORS=0
    close_table 3
}

# Test utility functions
test_progress_clear_line() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    TERM_INTERACTIVE=false
    clear_line
}

# Test spinner function with background process
test_progress_show_spinner_simple() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    TERM_INTERACTIVE=false
    
    # Start a background process
    sleep 0.1 &
    local pid=$!
    
    show_spinner "Testing" "$pid"
    local result=$?
    
    # Wait for process to complete
    wait "$pid" 2>/dev/null || true
    
    return $result
}

test_progress_show_spinner_failing_process() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    TERM_INTERACTIVE=false
    
    # Start a failing background process
    (sleep 0.1; exit 1) &
    local pid=$!
    
    # Capture result without triggering set -e
    local result=0
    show_spinner "Failing test" "$pid" || result=$?
    
    # Wait for process to complete
    wait "$pid" 2>/dev/null || true
    
    # Should return non-zero for failed process
    [[ $result -ne 0 ]]
}

# Test variables set by detect_terminal_features
test_progress_terminal_variables_set() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    # Variables should be set during module load
    [[ -n "${TERM_COLORS:-}" ]] && \
    [[ -n "${TERM_INTERACTIVE:-}" ]] && \
    [[ -n "${TERM_WIDTH:-}" ]] && \
    [[ -n "${TERM_SUPPORTS_UNICODE:-}" ]]
}

# Test terminal feature detection with mocked environment
test_progress_detect_features_with_tput() {
    source "$(get_module_path core)"
    source "$(get_module_path progress)"
    
    # Mock environment for consistent testing
    if command -v tput >/dev/null 2>&1; then
        detect_terminal_features
        [[ "${TERM_COLORS:-0}" -ge 0 ]]
    else
        # tput not available, should still work
        detect_terminal_features
        [[ "${TERM_COLORS:-0}" -ge 0 ]]
    fi
}

# Register all progress tests
run_test "Progress module requires core module" test_progress_requires_core false
run_test "Progress module loads with core" test_progress_loads_with_core

run_test "Terminal feature detection sets variables" test_progress_detect_terminal_features
run_test "Terminal variables are set on load" test_progress_terminal_variables_set
run_test "Detect features works with/without tput" test_progress_detect_features_with_tput

run_test_with_output "Get spinner frames basic" test_progress_get_spinner_frames_basic "|" contains
run_test_with_output "Get spinner frames unicode" test_progress_get_spinner_frames_unicode "⠋|\\|" regex
run_test_with_output "Get spinner frames dots" test_progress_get_spinner_frames_dots "⠁|\\|" regex
run_test "Get spinner frames auto returns frames" test_progress_get_spinner_frames_auto

run_test_with_output "Show progress simple" test_progress_show_progress_simple "Progress: 5/10 \\(50%\\)" regex
run_test_with_output "Show progress complete" test_progress_show_progress_complete "Progress: 10/10 \\(100%\\)" regex

run_test_with_output "Status icon success" test_progress_status_icon_success "✓" exact
run_test_with_output "Status icon error" test_progress_status_icon_error "✗" exact
run_test_with_output "Status icon warning" test_progress_status_icon_warning "!" exact
run_test_with_output "Status icon info" test_progress_status_icon_info "i" exact
run_test_with_output "Status icon working" test_progress_status_icon_working "\\.\\.\\.|⠋" regex
run_test_with_output "Status icon custom" test_progress_status_icon_custom "custom_status" exact

run_test_with_output "Format bold contains text" test_progress_format_bold "test text" contains
run_test_with_output "Format dim contains text" test_progress_format_dim "test text" contains
run_test_with_output "Format underline contains text" test_progress_format_underline "test text" contains

run_test_with_output "Section header level 1" test_progress_section_header_level1 "Test Section" contains
run_test_with_output "Section header level 2" test_progress_section_header_level2 "Test Section" contains
run_test_with_output "Section header level 3" test_progress_section_header_level3 "Test Section" contains
run_test_with_output "Section header default" test_progress_section_header_default "Test Section" contains

run_test_with_output "Create table shows headers" test_progress_create_table "Column1" contains
run_test_with_output "Add table row shows values" test_progress_add_table_row "Value1" contains
run_test "Close table completes successfully" test_progress_close_table

run_test "Clear line function succeeds" test_progress_clear_line

run_test "Show spinner with successful process" test_progress_show_spinner_simple
run_test "Show spinner with failing process" test_progress_show_spinner_failing_process