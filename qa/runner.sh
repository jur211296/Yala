#!/bin/bash
# QA Automation Runner for Yala iOS
# Uses agent-device to execute batch scripts against iOS Simulator
#
# Usage:
#   ./qa/runner.sh                           # All suites
#   ./qa/runner.sh --suite 05                # Only transactions suite
#   ./qa/runner.sh --suite 01 --scenario s1.1  # Only scenario 1.1
#   ./qa/runner.sh --from 06                 # Start from suite 06
#   ./qa/runner.sh --dry-run                 # Show what would run

set -euo pipefail

QA_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_ID=$(date +%Y-%m-%dT%H-%M-%S)
RESULTS_DIR="/tmp/qa/$RUN_ID"
APP_NAME="Yala"
PLATFORM="ios"
DEVICE="iPhone 17 Pro"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

# Parse arguments
SUITE_FILTER=""
SCENARIO_FILTER=""
FROM_SUITE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --suite) SUITE_FILTER="$2"; shift 2 ;;
        --scenario) SCENARIO_FILTER="$2"; shift 2 ;;
        --from) FROM_SUITE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Create results directory
mkdir -p "$RESULTS_DIR/screenshots" "$RESULTS_DIR/reports"

# Resolve app path in simulator
resolve_app_path() {
    local app_path
    app_path=$(find ~/Library/Developer/CoreSimulator/Devices -name "${APP_NAME}.app" -path "*/data/Containers/Bundle/Application/*" 2>/dev/null | head -1)
    if [[ -z "$app_path" ]]; then
        echo -e "${RED}Error: ${APP_NAME}.app not found in simulator. Build and install first.${NC}"
        exit 1
    fi
    echo "$app_path"
}

# Run a single batch file
run_batch() {
    local batch_file="$1"
    local label="$2"
    local screenshot_dir="$RESULTS_DIR/screenshots/$(dirname "$label" | xargs basename 2>/dev/null || echo "root")"

    mkdir -p "$screenshot_dir"

    if $DRY_RUN; then
        echo -e "  ${BLUE}[DRY] $label${NC}"
        return 0
    fi

    # Create temp file with placeholder substitution
    local tmp_batch="/tmp/qa-batch-$$.json"
    sed -e "s|{{SCREENSHOT_DIR}}|$screenshot_dir|g" \
        -e "s|{{APP_PATH}}|$APP_PATH|g" \
        -e "s|{{APP_NAME}}|$APP_NAME|g" \
        "$batch_file" > "$tmp_batch"

    local result exit_code
    result=$(agent-device batch --steps-file "$tmp_batch" --json 2>&1) || true
    exit_code=$?

    # Save result
    local report_name
    report_name=$(echo "$label" | tr '/' '-')
    echo "$result" > "$RESULTS_DIR/reports/${report_name}.json"

    rm -f "$tmp_batch"

    if echo "$result" | grep -q '"ok": false\|"error"'; then
        echo -e "  ${RED}FAIL${NC} $label"
        # Extract error details
        local error_step
        error_step=$(echo "$result" | grep -o '"step": [0-9]*' | head -1 | grep -o '[0-9]*')
        local error_cmd
        error_cmd=$(echo "$result" | grep -o '"command": "[^"]*"' | head -1)
        if [[ -n "$error_step" ]]; then
            echo -e "       Step $error_step: $error_cmd"
        fi
        return 1
    else
        echo -e "  ${GREEN}PASS${NC} $label"
        return 0
    fi
}

# Run a fixture
run_fixture() {
    local fixture_name="$1"
    local fixture_path="$QA_DIR/fixtures/$fixture_name"

    if [[ ! -f "$fixture_path" ]]; then
        echo -e "${YELLOW}Warning: Fixture $fixture_name not found, skipping${NC}"
        return 1
    fi

    echo -e "${BLUE}  fixture: $fixture_name${NC}"
    run_batch "$fixture_path" "fixtures/$fixture_name"
}

# Run all scenarios in a suite
run_suite() {
    local suite_dir="$1"
    local suite_name
    suite_name=$(basename "$suite_dir")
    local passed=0
    local failed=0

    echo -e "\n${YELLOW}=== Suite: $suite_name ===${NC}"

    for batch in "$suite_dir"/s*.json; do
        [[ -f "$batch" ]] || continue
        local scenario_name
        scenario_name=$(basename "$batch" .json)

        # Apply scenario filter
        if [[ -n "$SCENARIO_FILTER" && "$scenario_name" != *"$SCENARIO_FILTER"* ]]; then
            continue
        fi

        if run_batch "$batch" "$suite_name/$scenario_name"; then
            ((passed++))
            ((TOTAL_PASS++))
        else
            ((failed++))
            ((TOTAL_FAIL++))
        fi
    done

    echo -e "${BLUE}--- $suite_name: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC} ---"
}

# Suite definitions: suite_dir:fixture1,fixture2,...
SUITES=(
    "01-onboarding:fresh-install.json"
    "02-accounts:fresh-install.json,onboarding-complete.json"
    "03-categories:fresh-install.json,onboarding-complete.json"
    "04-tags:fresh-install.json,onboarding-complete.json"
    "05-transactions:fresh-install.json,with-transactions.json"
    "06-budgets:fresh-install.json,with-transactions.json"
    "07-scheduled-payments:fresh-install.json,with-transactions.json"
    "08-favorites:fresh-install.json,with-transactions.json"
    "09-panel:fresh-install.json,with-transactions.json"
    "10-statistics:fresh-install.json,with-transactions.json"
    "11-filters:fresh-install.json,with-transactions.json"
    "12-import-export:fresh-install.json,with-transactions.json"
    "13-settings:fresh-install.json,onboarding-complete.json"
    "14-edge-cases:fresh-install.json,onboarding-complete.json"
)

# Main execution
echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Yala QA Automation - agent-device       ║${NC}"
echo -e "${BLUE}╠═══════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║ Run ID: $RUN_ID        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"

if ! $DRY_RUN; then
    APP_PATH=$(resolve_app_path)
    echo -e "App: $APP_PATH"
fi

for entry in "${SUITES[@]}"; do
    suite_name="${entry%%:*}"
    fixtures="${entry#*:}"

    # Apply suite filter
    if [[ -n "$SUITE_FILTER" && "$suite_name" != *"$SUITE_FILTER"* ]]; then
        continue
    fi

    # Apply --from filter
    if [[ -n "$FROM_SUITE" ]]; then
        suite_num="${suite_name%%-*}"
        if [[ "$suite_num" < "$FROM_SUITE" ]]; then
            continue
        fi
    fi

    # Run fixtures for this suite
    echo -e "\n${BLUE}Setting up: $suite_name${NC}"
    IFS=',' read -ra fixture_list <<< "$fixtures"
    fixture_ok=true
    for fixture in "${fixture_list[@]}"; do
        if ! run_fixture "$fixture"; then
            echo -e "${RED}Fixture failed, skipping suite $suite_name${NC}"
            fixture_ok=false
            break
        fi
    done

    if $fixture_ok; then
        run_suite "$QA_DIR/suites/$suite_name"
    else
        ((TOTAL_SKIP++))
    fi
done

# Final summary
echo -e "\n${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              QA SUMMARY                   ║${NC}"
echo -e "${BLUE}╠═══════════════════════════════════════════╣${NC}"
echo -e "  ${GREEN}Passed:  $TOTAL_PASS${NC}"
echo -e "  ${RED}Failed:  $TOTAL_FAIL${NC}"
echo -e "  ${YELLOW}Skipped: $TOTAL_SKIP${NC}"
echo -e "${BLUE}╠═══════════════════════════════════════════╣${NC}"
echo -e "  Results:     $RESULTS_DIR"
echo -e "  Screenshots: $RESULTS_DIR/screenshots/"
echo -e "  Reports:     $RESULTS_DIR/reports/"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"

# Exit with error if any failures
[[ $TOTAL_FAIL -eq 0 ]]
