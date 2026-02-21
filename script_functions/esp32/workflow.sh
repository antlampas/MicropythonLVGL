# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Print effective runtime configuration for troubleshooting/reproducibility.
print_config() {
    print_step "Configuration"
    echo "MODE=$MODE"
    echo "WORKING_DIR=$WORKING_DIR"
    echo "LVGL_DIR=$LVGL_DIR"
    echo "TARGET_PORT=$TARGET_PORT"
    echo "BOARD=$BOARD"
    echo "BOARD_VARIANT=$BOARD_VARIANT"
    echo "DISPLAY_DRIVER=$DISPLAY_DRIVER"
    echo "INDEV=$INDEV"
    echo "ESP_CHIP=$ESP_CHIP"
    echo "BOARD_PROFILE=$BOARD_PROFILE"
    echo "FREEZE_BOARD_MODULE=$FREEZE_BOARD_MODULE"
    echo "BOARD_MODULE_NAME=$BOARD_MODULE_NAME"
    echo "INSTALL_DEPS=$INSTALL_DEPS"
    echo "UPDATE_SUBMODULES=$UPDATE_SUBMODULES"
    echo "RECLONE=$RECLONE"
    echo "CLEAN_BUILD=$CLEAN_BUILD"
    echo "CLEAN_REPO=$CLEAN_REPO"
    echo "PYTHON_BIN=$PYTHON_BIN"
    echo "LV_CFLAGS_EXTRA=$LV_CFLAGS_EXTRA"
    echo "LVGL_MONTSERRAT_FONTS=$LVGL_MONTSERRAT_FONTS"
    echo "LVGL_FONT_DEFAULT_SIZE=$LVGL_FONT_DEFAULT_SIZE"
    echo "LVGL_FONT_MONTSERRAT_28_COMPRESSED=$LVGL_FONT_MONTSERRAT_28_COMPRESSED"
    echo "LVGL_FONT_DEJAVU_16_PERSIAN_HEBREW=$LVGL_FONT_DEJAVU_16_PERSIAN_HEBREW"
    echo "LVGL_FONT_SIMSUN_14_CJK=$LVGL_FONT_SIMSUN_14_CJK"
    echo "LVGL_FONT_SIMSUN_16_CJK=$LVGL_FONT_SIMSUN_16_CJK"
    echo "LVGL_FONT_UNSCII_8=$LVGL_FONT_UNSCII_8"
    echo "LVGL_FONT_UNSCII_16=$LVGL_FONT_UNSCII_16"
    echo "ESPTOOL_PORT=$ESPTOOL_PORT"
    echo "ESPTOOL_BAUD=$ESPTOOL_BAUD"
}

# Bootstrap sequence: dependencies + repository + patching + context preparation.
bootstrap_flow() {
    install_dependencies
    ensure_repo
    init_submodules
    patch_builder_space_paths
    prepare_port_toolchain
    prepare_build_context
}

# Build sequence for an already prepared checkout.
build_flow() {
    ensure_repo
    init_submodules
    patch_builder_space_paths
    prepare_port_toolchain
    prepare_build_context
    build_firmware
    check_firmware_size
    locate_firmware
    cleanup_repo
}

# Main command dispatcher for all/bootstap/build modes.
main() {
    case "$MODE" in
        all)
            print_config
            bootstrap_flow
            build_firmware
            check_firmware_size
            locate_firmware
            cleanup_repo
            ;;
        bootstrap)
            print_config
            bootstrap_flow
            ;;
        build)
            print_config
            build_flow
            ;;
        *)
            echo "Usage: $0 [all|bootstrap|build]"
            echo ""
            echo "Env toggles:"
            echo "  INSTALL_DEPS=0|1      (default: 1)"
            echo "  UPDATE_SUBMODULES=0|1 (default: 1)"
            echo "  RECLONE=ask|0|1       (default: ask)"
            echo "  CLEAN_BUILD=0|1       (default: 0)"
            echo "  CLEAN_REPO=0|1        (default: 0)"
            echo "  TARGET_PORT=esp32"
            echo "  BOARD=ESP32_GENERIC_S3"
            echo "  BOARD_VARIANT=SPIRAM_OCT"
            echo "  ESP_CHIP=esp32s3"
            echo "  BOARD_PROFILE=waveshare_esp32s3_lcd128|custom"
            echo "  FREEZE_BOARD_MODULE=0|1"
            echo "  BOARD_MODULE_NAME=waveshare_esp32s3_lcd128"
            echo "  LV_CFLAGS_EXTRA='...'"
            echo "  DISPLAY_DRIVER=gc9a01"
            echo "  INDEV=cst816s"
            echo "  LVGL_MONTSERRAT_FONTS=\"12 14 16 28\""
            echo "  LVGL_FONT_DEFAULT_SIZE=28"
            echo ""
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}=== Script completed ===${NC}"
}
