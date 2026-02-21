# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
"""Runtime board helper for Waveshare RP2040 Touch LCD 1.28 (display + touch)."""

import time
import lvgl as lv
from machine import Pin, SPI, I2C
import lcd_bus
import gc9a01
import cst816s

DISPLAY_WIDTH = 240
DISPLAY_HEIGHT = 240
SPI_FREQ = 10_000_000
I2C_FREQ = 400_000
TOUCH_I2C_ADDR = getattr(cst816s, "I2C_ADDR", 0x15)


class _CompatI2CDevice:
    """Adapter that exposes the minimal I2C Device API expected by cst816s driver."""

    def __init__(self, bus, addr):
        self._bus = bus
        self._addr = addr

    def write(self, buf):
        self._bus.writeto(self._addr, buf)

    def read(self, nbytes, write=0x00):
        wr = bytes([write & 0xFF]) if isinstance(write, int) else write
        self._bus.writeto(self._addr, wr, False)
        return self._bus.readfrom(self._addr, nbytes)

    def write_readinto(self, wr_buf, rd_buf):
        self._bus.writeto(self._addr, wr_buf, False)
        self._bus.readfrom_into(self._addr, rd_buf)


def _pin(name):
    """Return a board pin alias and fail with a clear error when missing."""
    if not hasattr(Pin.board, name):
        raise RuntimeError("Missing board pin alias in firmware: %s" % name)
    return getattr(Pin.board, name)


def _gpio_num(pin_obj):
    """Normalize Pin/int/string-like identifiers to a numeric GPIO index."""
    if isinstance(pin_obj, int):
        return pin_obj

    try:
        return int(pin_obj)
    except Exception:
        pass

    pin_id = getattr(pin_obj, "id", None)
    if callable(pin_id):
        try:
            pin_id = pin_id()
        except Exception:
            pin_id = None

    if isinstance(pin_id, int):
        return pin_id

    if isinstance(pin_id, str):
        if pin_id.startswith("GPIO"):
            return int(pin_id[4:])
        if pin_id.startswith("GP"):
            return int(pin_id[2:])
        if pin_id.isdigit():
            return int(pin_id)

    pin_str = str(pin_obj)
    for prefix in ("GPIO", "GP"):
        idx = pin_str.find(prefix)
        if idx >= 0:
            idx += len(prefix)
            digits = ""
            while idx < len(pin_str) and pin_str[idx].isdigit():
                digits += pin_str[idx]
                idx += 1
            if digits:
                return int(digits)

    raise RuntimeError("Cannot resolve pin alias to GPIO number: %s" % pin_obj)


def _pin_num(name):
    """Resolve a board alias directly to GPIO number."""
    return _gpio_num(_pin(name))


def _touch_xy(sample):
    """Convert touch sample to clamped (x, y) tuple or None when invalid."""
    if not sample:
        return None

    try:
        x, y = int(sample[0]), int(sample[1])
    except Exception:
        try:
            x, y = int(sample.x), int(sample.y)
        except Exception:
            return None

    if x < 0:
        x = 0
    elif x >= DISPLAY_WIDTH:
        x = DISPLAY_WIDTH - 1

    if y < 0:
        y = 0
    elif y >= DISPLAY_HEIGHT:
        y = DISPLAY_HEIGHT - 1

    return (x, y)


def init_display():
    """Initialize LVGL + GC9A01 display and return display object."""
    lcd_rst = _pin_num("LCD_RST")
    rst = Pin(lcd_rst, Pin.OUT)
    rst.value(1)
    time.sleep_ms(10)
    rst.value(0)
    time.sleep_ms(20)
    rst.value(1)
    time.sleep_ms(120)

    spi = SPI(
        1,
        baudrate=SPI_FREQ,
        sck=_pin_num("LCD_CLK"),
        mosi=_pin_num("LCD_MOSI"),
        miso=_pin_num("LCD_MISO"),
    )

    bus = lcd_bus.SPIBus(
        spi_bus=spi,
        dc=_pin_num("LCD_DC"),
        cs=_pin_num("LCD_CS"),
        freq=SPI_FREQ,
        spi_mode=3,
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
        reset_pin=lcd_rst,
        reset_state=gc9a01.STATE_LOW,
        backlight_pin=_pin_num("LCD_BL"),
        backlight_on_state=gc9a01.STATE_HIGH,
        color_space=lv.COLOR_FORMAT.RGB565,
        color_byte_order=gc9a01.BYTE_ORDER_RGB,
        rgb565_byte_swap=False,
        _init_bus=True,
    )

    display._disp_drv.set_default()
    display.init()
    display.set_backlight(100)
    return display


def init_touch():
    """Initialize touch driver and bind it to an LVGL pointer input device."""
    i2c = I2C(
        1,
        scl=Pin(_pin_num("TP_SCL")),
        sda=Pin(_pin_num("TP_SDA")),
        freq=I2C_FREQ,
    )
    touch = cst816s.CST816S(_CompatI2CDevice(i2c, TOUCH_I2C_ADDR), _pin_num("TP_RST"))

    indev = lv.indev_create()
    indev.set_type(lv.INDEV_TYPE.POINTER)

    def _read_cb(_, data):
        """Poll touch controller and feed LVGL pointer state."""
        try:
            xy = _touch_xy(touch.read())
        except OSError:
            xy = None

        if xy:
            data.point.x, data.point.y = xy
            data.state = lv.INDEV_STATE.PRESSED
        else:
            data.state = lv.INDEV_STATE.RELEASED

    indev.set_read_cb(_read_cb)
    return indev


def init(touch=True):
    """Initialize display and optional touch, returning (display, indev)."""
    display = init_display()
    indev = init_touch() if touch else None
    return display, indev
