# Author: antlampas
# Created: 2026-02-21
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Centralize all ESP32 defaults so compile_esp32.sh can stay minimal.
init_esp32_defaults() {
    # Build target selection.
    TARGET_PORT="${TARGET_PORT:-esp32}"
    BOARD="${BOARD:-ESP32_GENERIC_S3}"
    BOARD_VARIANT="${BOARD_VARIANT:-SPIRAM_OCT}"

    DISPLAY_DRIVER="${DISPLAY_DRIVER:-${LVGL_DISPLAY:-}}"
    # Backward compatibility: accept legacy DISPLAY override only if it does not
    # look like an X11 display spec.
    if [ -z "$DISPLAY_DRIVER" ]; then
        if [ -n "${DISPLAY:-}" ] && [[ "${DISPLAY}" != *:* ]]; then
            DISPLAY_DRIVER="$DISPLAY"
        else
            DISPLAY_DRIVER="gc9a01"
        fi
    fi

    # Guard against X11-like values such as ":0" or "localhost:10.0".
    if [[ "$DISPLAY_DRIVER" == *:* ]]; then
        fail "Invalid DISPLAY_DRIVER='$DISPLAY_DRIVER' (looks like X11 DISPLAY). Use DISPLAY_DRIVER=gc9a01"
    fi

    # Default display and input drivers for Waveshare ESP32-S3 Touch LCD 1.28.
    INDEV="${INDEV:-cst816s}"
    ESP_CHIP="${ESP_CHIP:-esp32s3}"

    # Board helper module (frozen into firmware, no external prova*.py needed)
    # - BOARD_PROFILE: waveshare_esp32s3_lcd128 | custom
    # - FREEZE_BOARD_MODULE: 1 to include board module, 0 to disable
    # - BOARD_MODULE_NAME: import name used by application code (default = profile)
    BOARD_PROFILE="${BOARD_PROFILE:-waveshare_esp32s3_lcd128}"
    FREEZE_BOARD_MODULE="${FREEZE_BOARD_MODULE:-1}"
    BOARD_MODULE_NAME="${BOARD_MODULE_NAME:-$BOARD_PROFILE}"

    # Optional overrides (especially useful with BOARD_PROFILE=custom)
    PIN_LCD_BL="${PIN_LCD_BL:-}"
    PIN_TP_INT="${PIN_TP_INT:-}"
    PIN_TP_SDA="${PIN_TP_SDA:-}"
    PIN_TP_SCL="${PIN_TP_SCL:-}"
    PIN_LCD_DC="${PIN_LCD_DC:-}"
    PIN_LCD_CS="${PIN_LCD_CS:-}"
    PIN_LCD_CLK="${PIN_LCD_CLK:-}"
    PIN_LCD_MOSI="${PIN_LCD_MOSI:-}"
    PIN_LCD_MISO="${PIN_LCD_MISO:-}"
    PIN_TP_RST="${PIN_TP_RST:-}"
    PIN_LCD_RST="${PIN_LCD_RST:-}"
    DISPLAY_WIDTH="${DISPLAY_WIDTH:-}"
    DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-}"
    SPI_HOST="${SPI_HOST:-}"
    SPI_FREQ="${SPI_FREQ:-}"
    I2C_HOST="${I2C_HOST:-}"
    I2C_FREQ="${I2C_FREQ:-}"

    # LVGL font config:
    #   LVGL_MONTSERRAT_FONTS="12 14 16 28"
    #   LVGL_FONT_DEFAULT_SIZE=28
    # Optional binary toggles (0/1): compressed/cjk/unscii below.
    LVGL_MONTSERRAT_FONTS="${LVGL_MONTSERRAT_FONTS:-12 14 16}"
    LVGL_FONT_DEFAULT_SIZE="${LVGL_FONT_DEFAULT_SIZE:-14}"
    LVGL_FONT_MONTSERRAT_28_COMPRESSED="${LVGL_FONT_MONTSERRAT_28_COMPRESSED:-0}"
    LVGL_FONT_DEJAVU_16_PERSIAN_HEBREW="${LVGL_FONT_DEJAVU_16_PERSIAN_HEBREW:-0}"
    LVGL_FONT_SIMSUN_14_CJK="${LVGL_FONT_SIMSUN_14_CJK:-0}"
    LVGL_FONT_SIMSUN_16_CJK="${LVGL_FONT_SIMSUN_16_CJK:-0}"
    LVGL_FONT_UNSCII_8="${LVGL_FONT_UNSCII_8:-0}"
    LVGL_FONT_UNSCII_16="${LVGL_FONT_UNSCII_16:-0}"

    LVGL_FONTS_STEP_LABEL="${LVGL_FONTS_STEP_LABEL:-STEP 5f: Configure LVGL fonts}"
    PATCH_BUILDER_STEP_LABEL="${PATCH_BUILDER_STEP_LABEL:-STEP 3: Patch builder for paths with spaces}"

    # Generic workflow toggles shared with other platforms.
    INSTALL_DEPS="${INSTALL_DEPS:-1}"
    UPDATE_SUBMODULES="${UPDATE_SUBMODULES:-1}"
    RECLONE="${RECLONE:-ask}" # ask|1|0
    CLEAN_BUILD="${CLEAN_BUILD:-0}"
    CLEAN_REPO="${CLEAN_REPO:-0}"
    PYTHON_BIN="${PYTHON_BIN:-python3}"
    LV_CFLAGS_EXTRA="${LV_CFLAGS_EXTRA:-}"

    # Flash helper defaults used in final user instructions.
    ESPTOOL_PORT="${ESPTOOL_PORT:-/dev/ttyACM0}"
    ESPTOOL_BAUD="${ESPTOOL_BAUD:-921600}"
}
