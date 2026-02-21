# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
"""Generate an ESP32 frozen board helper module and its manifest file."""

import os
import re
from pathlib import Path

# Validate module import name used inside frozen firmware.
module_name = os.environ["BOARD_MODULE_NAME"]
if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", module_name):
    raise SystemExit(f"Invalid BOARD_MODULE_NAME: {module_name!r}")

# Environment keys required to render board helper source.
required = [
    "PIN_LCD_BL", "PIN_TP_INT", "PIN_TP_SDA", "PIN_TP_SCL",
    "PIN_LCD_DC", "PIN_LCD_CS", "PIN_LCD_CLK", "PIN_LCD_MOSI",
    "PIN_LCD_MISO", "PIN_TP_RST", "PIN_LCD_RST",
    "DISPLAY_WIDTH", "DISPLAY_HEIGHT",
    "SPI_HOST", "SPI_FREQ", "I2C_HOST", "I2C_FREQ",
]

# Parse every required value as integer (supports decimal/hex input).
values = {}
for key in required:
    raw = os.environ.get(key, "").strip()
    if raw == "":
        raise SystemExit(
            f"Missing required value for {key}. "
            "Set it in environment (BOARD_PROFILE=custom) or use a supported BOARD_PROFILE."
        )
    try:
        values[key] = int(raw, 0)
    except ValueError as exc:
        raise SystemExit(f"Invalid integer for {key}: {raw!r}") from exc

out_py = Path(os.environ["FROZEN_BOARD_PY"])
out_manifest = Path(os.environ["FROZEN_BOARD_MANIFEST"])
out_py.parent.mkdir(parents=True, exist_ok=True)

# Emit ready-to-freeze helper source with all selected pin/bus settings.
helper_src = f"""import time
import lvgl as lv
from machine import Pin, SPI
import lcd_bus
import gc9a01
import cst816s
import i2c

PIN_LCD_BL = {values["PIN_LCD_BL"]}
PIN_TP_INT = {values["PIN_TP_INT"]}
PIN_TP_SDA = {values["PIN_TP_SDA"]}
PIN_TP_SCL = {values["PIN_TP_SCL"]}
PIN_LCD_DC = {values["PIN_LCD_DC"]}
PIN_LCD_CS = {values["PIN_LCD_CS"]}
PIN_LCD_CLK = {values["PIN_LCD_CLK"]}
PIN_LCD_MOSI = {values["PIN_LCD_MOSI"]}
PIN_LCD_MISO = {values["PIN_LCD_MISO"]}
PIN_TP_RST = {values["PIN_TP_RST"]}
PIN_LCD_RST = {values["PIN_LCD_RST"]}

DISPLAY_WIDTH = {values["DISPLAY_WIDTH"]}
DISPLAY_HEIGHT = {values["DISPLAY_HEIGHT"]}
SPI_HOST = {values["SPI_HOST"]}
SPI_FREQ = {values["SPI_FREQ"]}
I2C_HOST = {values["I2C_HOST"]}
I2C_FREQ = {values["I2C_FREQ"]}


def _create_spi_bus():
    if hasattr(SPI, "Bus"):
        return SPI.Bus(
            host=SPI_HOST,
            sck=PIN_LCD_CLK,
            mosi=PIN_LCD_MOSI,
            miso=PIN_LCD_MISO,
        )

    return SPI(
        SPI_HOST,
        baudrate=SPI_FREQ,
        sck=Pin(PIN_LCD_CLK),
        mosi=Pin(PIN_LCD_MOSI),
        miso=Pin(PIN_LCD_MISO),
    )


def init_display():
    rst = Pin(PIN_LCD_RST, Pin.OUT)
    rst.value(1)
    time.sleep_ms(10)
    rst.value(0)
    time.sleep_ms(20)
    rst.value(1)
    time.sleep_ms(120)

    spi_bus = _create_spi_bus()
    bus = lcd_bus.SPIBus(
        spi_bus=spi_bus,
        freq=SPI_FREQ,
        dc=PIN_LCD_DC,
        cs=PIN_LCD_CS,
        spi_mode=0,
        lsb_first=False,
        dc_low_on_data=False,
        cs_high_active=False,
    )

    if not lv.is_initialized():
        lv.init()

    display = gc9a01.GC9A01(
        data_bus=bus,
        display_width=DISPLAY_WIDTH,
        display_height=DISPLAY_HEIGHT,
        reset_pin=PIN_LCD_RST,
        reset_state=gc9a01.STATE_LOW,
        backlight_pin=PIN_LCD_BL,
        backlight_on_state=gc9a01.STATE_HIGH,
        color_space=lv.COLOR_FORMAT.RGB565,
        color_byte_order=gc9a01.BYTE_ORDER_RGB,
        rgb565_byte_swap=False,
    )

    display.set_power(True)
    display.init()
    display.set_backlight(100)
    return display


def init_touch():
    i2c_bus = i2c.I2C.Bus(
        host=I2C_HOST,
        scl=PIN_TP_SCL,
        sda=PIN_TP_SDA,
        freq=I2C_FREQ,
        use_locks=False,
    )
    touch_dev = i2c.I2C.Device(
        bus=i2c_bus,
        dev_id=getattr(cst816s, "I2C_ADDR", 0x15),
        reg_bits=getattr(cst816s, "BITS", 8),
    )

    return cst816s.CST816S(
        touch_dev,
        reset_pin=PIN_TP_RST,
    )


def init(touch=True):
    display = init_display()
    indev = init_touch() if touch else None
    return display, indev
"""

out_py.write_text(helper_src, encoding="utf-8")
# Freeze exactly the generated helper file from its directory.
out_manifest.write_text(
    "freeze(%r, %r)\n" % (str(out_py.parent), out_py.name),
    encoding="utf-8",
)

print(f"OK: board module generated -> {out_py}")
print(f"OK: board manifest generated -> {out_manifest}")
print(f"OK: import name in firmware -> {module_name}")
