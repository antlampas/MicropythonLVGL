# Author: antlampas
# Created: 2026-02-18
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
import time
import lvgl as lv

BOARD_CANDIDATES = (
    ("waveshare_esp32s3_lcd128", "ESP32-S3"),
    ("waveshare_rp2040_lcd128", "RP2040"),
)


def _is_missing_module_error(err, module_name):
    """Check whether an ImportError means the requested module is missing.

    This helps distinguish the expected case (board module not found) from
    other import failures that should still be raised.
    """
    name = getattr(err, "name", None)
    if name == module_name:
        return True

    msg = str(err).lower()
    module_lower = module_name.lower()
    if "no module named" in msg and module_lower in msg:
        return True

    return False


def _load_board_module():
    """Load the first available board module from the candidate list.

    This keeps the app compatible with multiple supported boards without
    manually changing the module name.
    """
    for module_name, board_name in BOARD_CANDIDATES:
        try:
            module = __import__(module_name)
            print(f"[OK] Board module: {module_name} ({board_name})")
            return module
        except ImportError as e:
            if _is_missing_module_error(e, module_name):
                continue
            raise

    names = ", ".join(name for name, _ in BOARD_CANDIDATES)
    raise RuntimeError(
        f"No board module found. Expected: {names}. "
        "Rebuild/flash the correct firmware."
    )


def _init_board(board):
    """Initialize display and touch using the API exposed by board module.

    This provides a uniform flow for boards exposing either
    `init_display`/`init_touch` or a single `init` method.
    """
    if hasattr(board, "init_display"):
        display = board.init_display()
        try:
            indev = board.init_touch()
            print("[OK] Touch initialized.")
        except Exception as e:
            print(f"[WARN] Touch init failed: {e}")
            indev = None
        return display, indev

    if hasattr(board, "init"):
        try:
            display, indev = board.init(touch=True)
        except TypeError:
            display, indev = board.init()
        return display, indev

    raise RuntimeError("The board module does not expose init_display/init.")


def _font(size):
    """Return the LVGL Montserrat font for the requested size.

    The lookup is dynamic and returns `None` when that size is not built
    into the firmware.
    """
    return getattr(lv, f"font_montserrat_{size}", None)


def _pick_font(*sizes):
    """Pick the first available font from the provided size list.

    This creates an ordered fallback when a specific size is not included
    in the LVGL build.
    """
    for size in sizes:
        fnt = _font(size)
        if fnt is not None:
            return fnt, size
    return None, None

def create_ui(indev):
    """Build the UI and connect touch-related event handlers.

    It creates screen widgets and interactive elements while adapting to
    whether an input device is available.
    """
    def onButtonPressed(e):
        if label.get_text() == "AAAH":
            label.set_text("PRESS ME!")
        else:
            label.set_text("AAAH")
    forward = True
    def update(t):
        nonlocal forward
        if forward:
            newVal = arc1.get_value() + 1
        else:
            newVal = arc1.get_value() - 1
        arc1.set_value(newVal)
        if arc1.get_value() == 100:
            forward = False
        elif arc1.get_value() == 0:
            forward = True
    scr = lv.screen_active()
    scr.add_flag(lv.obj.FLAG.CLICKABLE)
    scr.set_style_bg_color(lv.color_hex(0x000000), lv.PART.MAIN)

    font_title, size_title = _pick_font(30, 28, 16)
    font_status, size_status = _pick_font(30, 28, 16)
    font_counter, size_counter = _pick_font(30, 28, 16)

    print(
        "[INFO] Font sizes in use: "
        f"title={size_title or 'default'} "
        f"status={size_status or 'default'} "
        f"counter={size_counter or 'default'}"
    )
    
    arc1 = lv.arc(scr)
    arc1.set_size(230, 230)
    arc1.align(lv.ALIGN.CENTER, 0, 0)
    arc1.set_range(0,100)
    arc1.set_value(0)

    button = lv.button(scr)
    button.align(lv.ALIGN.CENTER, 0, 0)
    button.add_flag(lv.obj.FLAG.CLICKABLE)
    
    label = lv.label(button)
    label.set_text("PRESS ME!")
    
    button.add_event_cb(onButtonPressed, lv.EVENT.PRESSED, None)

    timer = lv.timer_create(update,50,None)
    timer.set_repeat_count(-1)

def main():
    """Application entrypoint.

    It loads the board module, initializes hardware/UI, and keeps the main
    LVGL loop running.
    """
    board = _load_board_module()
    display, indev = _init_board(board)

    create_ui(indev)
    if hasattr(lv, "refr_now"):
        lv.refr_now(display._disp_drv)
    print("[OK] UI ready.")

    while True:
        lv.tick_inc(5)
        lv.task_handler()
        time.sleep_ms(5)


if __name__ == "__main__":
    main()
