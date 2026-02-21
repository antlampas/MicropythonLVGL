# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Expand a named board profile into concrete pin/bus defaults.
apply_board_profile_defaults() {
    case "$BOARD_PROFILE" in
        waveshare_esp32s3_lcd128)
            : "${PIN_LCD_BL:=2}"
            : "${PIN_TP_INT:=5}"
            : "${PIN_TP_SDA:=6}"
            : "${PIN_TP_SCL:=7}"
            : "${PIN_LCD_DC:=8}"
            : "${PIN_LCD_CS:=9}"
            : "${PIN_LCD_CLK:=10}"
            : "${PIN_LCD_MOSI:=11}"
            : "${PIN_LCD_MISO:=12}"
            : "${PIN_TP_RST:=13}"
            : "${PIN_LCD_RST:=14}"
            : "${DISPLAY_WIDTH:=240}"
            : "${DISPLAY_HEIGHT:=240}"
            : "${SPI_HOST:=1}"
            : "${SPI_FREQ:=40000000}"
            : "${I2C_HOST:=0}"
            : "${I2C_FREQ:=100000}"
            ;;
        custom)
            # Keep values from env as-is (all required values must be provided).
            ;;
        *)
            fail "Unsupported BOARD_PROFILE='$BOARD_PROFILE'. Use waveshare_esp32s3_lcd128 or custom"
            ;;
    esac
}

# Generate and export a frozen Python board helper module for firmware build.
create_frozen_board_module() {
    print_step "STEP 5g: Generate frozen board module ($BOARD_MODULE_NAME)"

    [ "$FREEZE_BOARD_MODULE" = "1" ] || fail "create_frozen_board_module called with FREEZE_BOARD_MODULE=$FREEZE_BOARD_MODULE"
    [ -n "$BOARD_MODULE_NAME" ] || fail "BOARD_MODULE_NAME cannot be empty"

    # Fill missing values before generating the Python helper source.
    apply_board_profile_defaults

    FROZEN_BOARD_PY="$LVGL_DIR/build/${BOARD_MODULE_NAME}.py"
    FROZEN_BOARD_MANIFEST="$LVGL_DIR/build/manifest_${BOARD_MODULE_NAME}.py"
    export FROZEN_BOARD_PY
    export FROZEN_BOARD_MANIFEST
    export BOARD_MODULE_NAME
    export PIN_LCD_BL PIN_TP_INT PIN_TP_SDA PIN_TP_SCL
    export PIN_LCD_DC PIN_LCD_CS PIN_LCD_CLK PIN_LCD_MOSI PIN_LCD_MISO PIN_TP_RST PIN_LCD_RST
    export DISPLAY_WIDTH DISPLAY_HEIGHT SPI_HOST SPI_FREQ I2C_HOST I2C_FREQ

    # The Python generator reads settings directly from exported environment vars.
    "$PYTHON_BIN" "$HEREDOC_TEMPLATES_DIR/esp32/generate_frozen_board_module.py" || fail "Failed generating frozen board module"

    ok "Frozen board module prepared: $BOARD_MODULE_NAME"
}
