# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Build ESP32 firmware using make.py with selected board/display options.
build_firmware() {
    print_step "STEP 6: Build"

    info "Port:          $TARGET_PORT"
    info "Board:         $BOARD"
    info "Board variant: $BOARD_VARIANT"
    info "Display:       $DISPLAY_DRIVER"
    info "Indev:         $INDEV"
    info "Python:        $PYTHON_BIN"
    info "Board profile: $BOARD_PROFILE"
    if [ "$FREEZE_BOARD_MODULE" = "1" ]; then
        info "Board module:  $BOARD_MODULE_NAME"
    fi
    info "Fonts (Mont.): $LVGL_MONTSERRAT_FONTS"
    info "Font default:  montserrat_$LVGL_FONT_DEFAULT_SIZE"

    # Build folder name follows MicroPython ESP32 convention.
    local build_dir="$LVGL_DIR/lib/micropython/ports/esp32/build-$BOARD"
    local -a build_args=(
        "$TARGET_PORT"
        "BOARD=$BOARD"
        "DISPLAY=$DISPLAY_DRIVER"
        "INDEV=$INDEV"
        "GEN_SCRIPT=$PYTHON_BIN"
    )

    if [ "$FREEZE_BOARD_MODULE" = "1" ]; then
        build_args+=("FROZEN_MANIFEST=$FROZEN_BOARD_MANIFEST")
    fi

    if [ -n "$BOARD_VARIANT" ] && [ "$BOARD_VARIANT" != "-" ]; then
        build_dir="${build_dir}-${BOARD_VARIANT}"
        build_args+=("BOARD_VARIANT=$BOARD_VARIANT")
    fi

    if [ "$CLEAN_BUILD" = "1" ] && [ -d "$build_dir" ]; then
        info "CLEAN_BUILD=1 -> removing $build_dir"
        rm -rf "$build_dir"
    fi

    if [ -n "${LV_CFLAGS_EXTRA:-}" ]; then
        export LV_CFLAGS="$LV_CFLAGS_EXTRA"
    fi

    # Unset host DISPLAY vars to avoid leaking desktop-specific env into build logic.
    env -u DISPLAY -u DISPLAY_DRIVER "$PYTHON_BIN" make.py "${build_args[@]}" || fail "Build failed"
    ok "Build completed"
}

# Validate that firmware binary fits the application partition.
check_firmware_size() {
    print_step "STEP 7: Check firmware size"

    local build_dir="$LVGL_DIR/lib/micropython/ports/esp32/build-$BOARD"
    local app_bin partition_csv part_values app_max fs_size fw_size

    if [ -n "$BOARD_VARIANT" ] && [ "$BOARD_VARIANT" != "-" ]; then
        build_dir="${build_dir}-${BOARD_VARIANT}"
    fi

    app_bin="$build_dir/micropython.bin"
    partition_csv="$LVGL_DIR/build/partitions.csv"
    if [ ! -f "$partition_csv" ]; then
        partition_csv="$build_dir/partition_table/partition-table.csv"
    fi

    if [ ! -f "$app_bin" ]; then
        warn "App binary not found: $app_bin"
        return
    fi

    if [ ! -f "$partition_csv" ]; then
        warn "Partition CSV not found (skipping size check): $partition_csv"
        return
    fi

    # Parse max app/fs partition sizes from the active partition table.
    part_values="$("$PYTHON_BIN" "$HEREDOC_TEMPLATES_DIR/esp32/parse_partition_sizes.py" "$partition_csv")" || fail "Failed parsing partition CSV: $partition_csv"

    read -r app_max fs_size <<<"$part_values"

    if [ -z "${app_max:-}" ] || [ "$app_max" -le 0 ]; then
        warn "Could not determine app partition size from: $partition_csv"
        return
    fi

    fw_size="$(stat -c %s "$app_bin" 2>/dev/null || echo 0)"
    if [ -z "$fw_size" ] || [ "$fw_size" -le 0 ]; then
        warn "Could not determine firmware size: $app_bin"
        return
    fi

    local fw_kb=$((fw_size / 1024))
    local max_kb=$((app_max / 1024))
    local margin_kb=$(((app_max - fw_size) / 1024))

    info "Firmware (micropython.bin): ${fw_kb} KB"
    info "App max partition:          ${max_kb} KB"
    if [ -n "${fs_size:-}" ] && [ "$fs_size" -gt 0 ]; then
        info "Filesystem partition:       $((fs_size / 1024)) KB"
    fi
    info "Margin:                     ${margin_kb} KB"

    if [ "$fw_size" -gt "$app_max" ]; then
        local overflow_kb=$(((fw_size - app_max) / 1024))
        fail "FIRMWARE TOO LARGE: exceeds app partition by ${overflow_kb} KB"
    fi

    ok "Firmware fits in app partition (${fw_kb}/${max_kb} KB)"
}

# Locate produced .bin firmware and copy a stable artifact in workspace root.
locate_firmware() {
    print_step "STEP 8: Locate firmware"

    local bin_file bin_name bin_size bin_kb

    bin_file="$(find "$LVGL_DIR/build" -maxdepth 1 -type f -name "lvgl_micropy_${BOARD}*.bin" | head -n 1 || true)"
    if [ -z "$bin_file" ]; then
        bin_file="$(find "$LVGL_DIR/build" -type f -name "*.bin" | head -n 1 || true)"
    fi

    if [ -n "$bin_file" ]; then
        bin_name="${bin_file##*/}"
        cp "$bin_file" "$WORKING_DIR/firmware_esp32.bin"
        bin_size="$(stat -c %s "$bin_file" 2>/dev/null || echo 0)"
        bin_kb=$((bin_size / 1024))

        ok "Firmware found (${bin_kb} KB): $bin_file"
        ok "Copied to: $WORKING_DIR/$bin_name"
        echo ""
        info "Flash command (adjust port if needed):"
        echo "  esptool.py --chip $ESP_CHIP --port $ESPTOOL_PORT --baud $ESPTOOL_BAUD write_flash -z 0x0 \"$WORKING_DIR/$bin_name\""
        echo "  or"
        echo "  esptool.py --chip $ESP_CHIP --port $ESPTOOL_PORT --baud $ESPTOOL_BAUD write_flash -z 0x0 \"$WORKING_DIR/firmware_esp32.bin\""
    else
        warn "No .bin firmware found under $LVGL_DIR/build"
    fi
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
