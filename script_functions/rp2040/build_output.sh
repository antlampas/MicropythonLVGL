# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Build RP2040 firmware using make.py with selected board/display options.
build_firmware() {
    print_step "STEP 6: Build"

    # Build folder names follow MicroPython RP2 conventions.
    local manifest="$LVGL_DIR/lib/micropython/ports/rp2/boards/$BOARD/manifest.py"
    local build_dir="$LVGL_DIR/lib/micropython/ports/rp2/build-$BOARD"

    [ -f "$manifest" ] || fail "Missing manifest: $manifest"

    info "Port:    $TARGET_PORT"
    info "Board:   $BOARD"
    if [ "$FREEZE_BOARD_MODULE" = "1" ]; then
        info "Module:  $BOARD_MODULE_NAME"
    else
        info "Module:  disabled (FREEZE_BOARD_MODULE=0)"
    fi
    info "Display: $DISPLAY_DRIVER"
    info "Indev:   $INDEV"
    info "Manifest: $manifest"
    info "Fonts (Mont.): $LVGL_MONTSERRAT_FONTS"
    info "Font default:  montserrat_$LVGL_FONT_DEFAULT_SIZE"

    if [ "$CLEAN_BUILD" = "1" ] && [ -d "$build_dir" ]; then
        info "CLEAN_BUILD=1 -> removing $build_dir"
        rm -rf "$build_dir"
    fi

    export LV_CFLAGS="$LV_CFLAGS_EXTRA"
    export LV_PORT="rp2"
    unset SECOND_BUILD || true

    local -a build_args=(
        "$TARGET_PORT"
        "BOARD=$BOARD"
        "DISPLAY=$DISPLAY_DRIVER"
        "INDEV=$INDEV"
        "GEN_SCRIPT=$PYTHON_BIN"
        "LV_PORT=rp2"
    )

    if [ "$FREEZE_BOARD_MODULE" = "1" ]; then
        build_args+=("FROZEN_MANIFEST=$manifest")
    fi

    # Unset host DISPLAY vars to avoid leaking desktop-specific env into build logic.
    env -u DISPLAY -u DISPLAY_DRIVER "$PYTHON_BIN" make.py "${build_args[@]}" || fail "Build failed"

    ok "Build completed"
}

# Validate that firmware payload fits reserved flash area.
check_firmware_size() {
    print_step "STEP 7: Check firmware size"

    local flash_total=$((2048 * 1024))
    local flash_fs=$((1024 * 1024))
    local flash_fw_max=$((flash_total - flash_fs))
    local elf_file="$LVGL_DIR/lib/micropython/ports/rp2/build-$BOARD/firmware.elf"

    if [ ! -f "$elf_file" ]; then
        warn "ELF not found: $elf_file"
        return
    fi

    local fw_size
    fw_size="$(arm-none-eabi-size -A "$elf_file" 2>/dev/null | awk '/^\.boot2|^\.text|^\.rodata|^\.binary_info|^\.data/ {sum += $2} END {print sum+0}')"

    if [ -z "$fw_size" ] || [ "$fw_size" -eq 0 ]; then
        local map_file fw_end_hex fw_end
        map_file="${elf_file}.map"
        if [ -f "$map_file" ]; then
            fw_end_hex="$(grep '__flash_binary_end' "$map_file" | awk '{print $1}' | head -n 1)"
            if [ -n "$fw_end_hex" ]; then
                fw_end=$((fw_end_hex))
                fw_size=$((fw_end - 0x10000000))
            fi
        fi
    fi

    if [ -z "$fw_size" ] || [ "$fw_size" -le 0 ]; then
        warn "Could not determine firmware size"
        return
    fi

    local fw_kb=$((fw_size / 1024))
    local max_kb=$((flash_fw_max / 1024))
    local fs_kb=$((flash_fs / 1024))
    local margin_kb=$(((flash_fw_max - fw_size) / 1024))

    info "Firmware:  ${fw_kb} KB"
    info "Max avail: ${max_kb} KB"
    info "Filesys:   ${fs_kb} KB"
    info "Margin:    ${margin_kb} KB"

    if [ "$fw_size" -gt "$flash_fw_max" ]; then
        local overlap=$(((fw_size - flash_fw_max) / 1024))
        fail "FIRMWARE TOO LARGE: overlaps filesystem by ${overlap} KB"
    fi

    ok "Firmware fits in flash (${fw_kb}/${max_kb} KB)"
}

# Locate produced .uf2 firmware and copy a stable artifact in workspace root.
locate_firmware() {
    print_step "STEP 8: Locate firmware"

    local uf2
    uf2="$(find "$LVGL_DIR/lib/micropython/ports/rp2/build-$BOARD" -maxdepth 1 -name '*.uf2' -print -quit 2>/dev/null || true)"

    if [ -z "$uf2" ]; then
        uf2="$(find "$LVGL_DIR/build" -name '*.uf2' -print -quit 2>/dev/null || true)"
    fi

    if [ -z "$uf2" ]; then
        warn "No .uf2 found"
        return
    fi

    local firmware_name uf2_size uf2_kb
    firmware_name="${uf2##*/}"
    cp "$uf2" "$WORKING_DIR/firmware_rp2040.uf2"
    uf2_size="$(stat -c %s "$uf2")"
    uf2_kb=$((uf2_size / 1024))

    ok "Firmware found (${uf2_kb} KB): $uf2"
    ok "Copied to: $WORKING_DIR/$firmware_name"

    info "To flash:"
    echo "  1. Hold BOOTSEL and connect USB"
    echo "  2. Copy flash_nuke.uf2 to the RPI-RP2 drive"
    echo "  3. Enter BOOTSEL again"
    echo "  4. cp \"$WORKING_DIR/firmware_rp2040.uf2\" \"/media/\$USER/RPI-RP2/\""
}

# Optionally remove local clone to free disk space.
cleanup_repo() {
    if [ "$CLEAN_REPO" != "1" ]; then
        info "CLEAN_REPO=0 -> keeping $LVGL_DIR"
        return
    fi

    print_step "STEP 9: Cleanup repository"
    rm -rf "$LVGL_DIR"
    ok "Removed: $LVGL_DIR"
}
