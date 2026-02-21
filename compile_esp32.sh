#!/usr/bin/env bash
# Author: antlampas
# Created: 2026-02-18
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# ============================================================
# Full script: clone + setup esp-idf + build
# lvgl_micropython for Waveshare ESP32-S3-Touch-LCD-1.28
# ============================================================

set -euo pipefail

# Build mode:
# - all: bootstrap + build
# - bootstrap: fetch/setup only
# - build: reuse existing tree and build
MODE="${1:-all}" # all|bootstrap|build

# Resolve repository-local paths once so every sourced module can reuse them.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEREDOC_TEMPLATES_DIR="${SCRIPT_DIR}/script_heredoc_templates"
FUNCTIONS_DIR="${SCRIPT_DIR}/script_functions/esp32"
COMMON_FUNCTIONS_DIR="${SCRIPT_DIR}/script_functions/common"

# Keep all generated content inside the current workspace folder.
WORKING_DIR="$(pwd)"
LVGL_DIR="${WORKING_DIR}/ESP32/lvgl_micropython"
REPO_URL="https://github.com/lvgl-micropython/lvgl_micropython"

# Shared ANSI colors used by logging helpers.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load shell modules in dependency order.
for module in \
    "$COMMON_FUNCTIONS_DIR/logging_io.sh" \
    "$COMMON_FUNCTIONS_DIR/lvgl_repo.sh" \
    "$FUNCTIONS_DIR/platform_config.sh" \
    "$FUNCTIONS_DIR/board_module.sh" \
    "$FUNCTIONS_DIR/prebuild_setup.sh" \
    "$FUNCTIONS_DIR/build_output.sh" \
    "$FUNCTIONS_DIR/workflow.sh"; do
    if [ ! -f "$module" ]; then
        echo "[ERROR] Missing function module: $module"
        exit 1
    fi
    # shellcheck disable=SC1090
    source "$module"
done

# Initialize all ESP32-specific defaults before running the workflow.
init_esp32_defaults

# Entrypoint defined in script_functions/esp32/workflow.sh
main
