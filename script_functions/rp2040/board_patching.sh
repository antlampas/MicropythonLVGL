# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Create/update a custom RP2040 board folder used by MicroPython build.
create_custom_board() {
    print_step "STEP 5a: Create board definition $BOARD"

    local board_dir="$LVGL_DIR/lib/micropython/ports/rp2/boards/$BOARD"
    if [[ ! "$BOARD_MODULE_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        fail "Invalid BOARD_MODULE_NAME='$BOARD_MODULE_NAME' (must be a valid Python module name)"
    fi
    mkdir -p "$board_dir/modules"

    write_file "$board_dir/mpconfigboard.cmake" < "$HEREDOC_TEMPLATES_DIR/rp2040/board/mpconfigboard.cmake"
    write_file "$board_dir/mpconfigboard.h" < "$HEREDOC_TEMPLATES_DIR/rp2040/board/mpconfigboard.h"
    write_file "$board_dir/pins.csv" < "$HEREDOC_TEMPLATES_DIR/rp2040/board/pins.csv"
    write_file "$board_dir/board.json" < "$HEREDOC_TEMPLATES_DIR/rp2040/board/board.json"
    # When enabled, freeze the helper module into firmware via board manifest.
    if [ "$FREEZE_BOARD_MODULE" = "1" ]; then
        write_file "$board_dir/manifest.py" < "$HEREDOC_TEMPLATES_DIR/rp2040/board/manifest.py"
        write_file "$board_dir/modules/${BOARD_MODULE_NAME}.py" < "$HEREDOC_TEMPLATES_DIR/rp2040/board/board_module.py"
    else
        write_file "$board_dir/manifest.py" <<'EOF'
include("$(PORT_DIR)/boards/manifest.py")
EOF
        rm -f "$board_dir/modules/${BOARD_MODULE_NAME}.py"
        info "Frozen board module disabled (FREEZE_BOARD_MODULE=0)"
    fi

    ok "Custom board ready in $board_dir"
}

# Materialize the SPI API patch helper into the cloned repo.
create_patch_spi_api_script() {
    print_step "STEP 5b: Create gen/patch_spi_api.py"

    write_file "$LVGL_DIR/gen/patch_spi_api.py" < "$HEREDOC_TEMPLATES_DIR/rp2040/patch_spi_api.py"

    chmod +x "$LVGL_DIR/gen/patch_spi_api.py"
    ok "Created: gen/patch_spi_api.py"
}

# Materialize the RP2040 tree patch helper into the cloned repo.
create_tree_patch_script() {
    print_step "STEP 5c: Create gen/patch_rp2040_tree.py"

    write_file "$LVGL_DIR/gen/patch_rp2040_tree.py" < "$HEREDOC_TEMPLATES_DIR/rp2040/patch_rp2040_tree.py"

    chmod +x "$LVGL_DIR/gen/patch_rp2040_tree.py"
    ok "Created: gen/patch_rp2040_tree.py"
}

# Apply broader source tree fixes required by current lvgl_micropython revision.
apply_tree_patches() {
    print_step "STEP 5d: Apply tree patches"

    local -a args=("--root" "$LVGL_DIR")
    if [ "$DEBUG_PATCHES" = "1" ]; then
        args+=("--enable-debug")
        warn "DEBUG_PATCHES=1 -> debug prints will be injected"
    fi

    "$PYTHON_BIN" "$LVGL_DIR/gen/patch_rp2040_tree.py" "${args[@]}" || fail "Failed applying tree patches"
    ok "Tree patching completed"
}

# Patch machine_spi.c compatibility symbols and sync modified file in tree.
patch_machine_spi() {
    print_step "STEP 5e: Patch machine_spi.c"

    local src="$LVGL_DIR/micropy_updates/rp2/machine_spi.c"
    local dst="$LVGL_DIR/lib/micropython/ports/rp2/machine_spi.c"

    [ -f "$src" ] || fail "Missing source patch file: $src"
    [ -f "$dst" ] || fail "Missing destination file: $dst"

    "$PYTHON_BIN" "$LVGL_DIR/gen/patch_spi_api.py" "$src" || fail "Failed patching source machine_spi.c"

    if ! cmp -s "$src" "$dst"; then
        cp "$src" "$dst"
        info "Copied patched machine_spi.c into lib/micropython"
    fi

    "$PYTHON_BIN" "$LVGL_DIR/gen/patch_spi_api.py" "$dst" || fail "Failed patching destination machine_spi.c"

    local residuals
    residuals="$(grep -nE 'machine_hw_spi_obj_t|\.mosi|\.miso|\.active_devices|self->baudrate' "$dst" 2>/dev/null || true)"

    if [ -n "$residuals" ]; then
        warn "Residual patterns found in machine_spi.c (will be re-patched by cmake):"
        echo "$residuals"
    else
        ok "No residual patterns in machine_spi.c"
    fi
}

# Prepare board assets, apply source patches, then configure LVGL fonts.
prepare_build_context() {
    create_custom_board
    create_patch_spi_api_script
    create_tree_patch_script
    apply_tree_patches
    patch_machine_spi
    configure_lvgl_fonts
}
