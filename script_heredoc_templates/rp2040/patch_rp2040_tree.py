#!/usr/bin/env python3
# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
"""Apply rp2040 build patches required by lvgl_micropython."""

from __future__ import annotations

import argparse
import os
import re
import sys


def read_text(path: str) -> str:
    """Read UTF-8 text file."""
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def write_text(path: str, content: str) -> None:
    """Write UTF-8 text file."""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


def patch_micropython_cmake(path: str) -> bool:
    """Patch ext_mod/lvgl/micropython.cmake for RP2040 build compatibility."""
    content = read_text(path)
    changed = False

    # Inject robust GEN_SCRIPT/LV_PORT resolution once.
    if "_GEN_SCRIPT_VAL" not in content:
        block = (
            "# --- Robust GEN_SCRIPT (cmake > env > default python) ---\n"
            "if(DEFINED GEN_SCRIPT AND NOT \"${GEN_SCRIPT}\" STREQUAL \"\")\n"
            "    set(_GEN_SCRIPT_VAL \"${GEN_SCRIPT}\")\n"
            "elseif(NOT \"$ENV{GEN_SCRIPT}\" STREQUAL \"\")\n"
            "    set(_GEN_SCRIPT_VAL \"$ENV{GEN_SCRIPT}\")\n"
            "else()\n"
            "    set(_GEN_SCRIPT_VAL \"python\")\n"
            "endif()\n"
            "# --- Robust LV_PORT (cmake > env > default rp2) ---\n"
            "if(DEFINED LV_PORT AND NOT \"${LV_PORT}\" STREQUAL \"\")\n"
            "    set(_LV_PORT_VAL \"${LV_PORT}\")\n"
            "elseif(NOT \"$ENV{LV_PORT}\" STREQUAL \"\")\n"
            "    set(_LV_PORT_VAL \"$ENV{LV_PORT}\")\n"
            "else()\n"
            "    set(_LV_PORT_VAL \"rp2\")\n"
            "endif()\n"
            "\n"
        )

        anchor = "set(LVGL_DIR "
        if anchor not in content:
            raise RuntimeError("set(LVGL_DIR anchor not found")

        content = content.replace(anchor, block + anchor, 1)
        content = content.replace(
            "$ENV{GEN_SCRIPT}_api_gen_mpy.py",
            "${_GEN_SCRIPT_VAL}_api_gen_mpy.py",
        )
        content = content.replace("--board=$ENV{LV_PORT}", "--board=${_LV_PORT_VAL}")
        changed = True

    # Replace fragile LV_CFLAGS/SECOND_BUILD env handling with explicit fallback logic.
    if "_SECOND_BUILD_VAL" not in content:
        pat = re.compile(
            r"separate_arguments\s*\(\s*LV_CFLAGS_ENV\s+UNIX_COMMAND\s+\$ENV\{LV_CFLAGS\}\s*\)"
            r".*?"
            r"separate_arguments\s*\(\s*SECOND_BUILD_ENV\s+UNIX_COMMAND\s+\$ENV\{SECOND_BUILD\}\s*\)",
            re.DOTALL,
        )

        new_block = (
            "# --- Robust SECOND_BUILD (cmake > env > default 0) ---\n"
            "if(DEFINED SECOND_BUILD AND NOT \"${SECOND_BUILD}\" STREQUAL \"\")\n"
            "    set(_SECOND_BUILD_VAL \"${SECOND_BUILD}\")\n"
            "elseif(NOT \"$ENV{SECOND_BUILD}\" STREQUAL \"\")\n"
            "    set(_SECOND_BUILD_VAL \"$ENV{SECOND_BUILD}\")\n"
            "else()\n"
            "    set(_SECOND_BUILD_VAL \"0\")\n"
            "endif()\n"
            "separate_arguments(SECOND_BUILD_ENV UNIX_COMMAND ${_SECOND_BUILD_VAL})\n"
            "# --- Robust LV_CFLAGS (cmake > env > default empty) ---\n"
            "if(DEFINED LV_CFLAGS_EXTRA AND NOT \"${LV_CFLAGS_EXTRA}\" STREQUAL \"\")\n"
            "    separate_arguments(LV_CFLAGS_ENV UNIX_COMMAND ${LV_CFLAGS_EXTRA})\n"
            "elseif(NOT \"$ENV{LV_CFLAGS}\" STREQUAL \"\")\n"
            "    separate_arguments(LV_CFLAGS_ENV UNIX_COMMAND $ENV{LV_CFLAGS})\n"
            "else()\n"
            "    set(LV_CFLAGS_ENV \"\")\n"
            "endif()\n"
            "list(APPEND LV_CFLAGS\n"
            "    ${LV_CFLAGS_ENV}\n"
            "    -Wno-unused-function\n"
            "    -DMICROPY_FLOAT=1\n"
            ")\n"
        )

        m = pat.search(content)
        if not m:
            raise RuntimeError("LV_CFLAGS/SECOND_BUILD block not found")

        content = content[: m.start()] + new_block + content[m.end() :]
        changed = True

    # Ensure machine_spi patch script is executed from CMake configure step.
    if "patch_spi_api.py" not in content:
        cmake_patch = (
            "\n"
            "# --- Patch machine_spi.c after git submodule reset ---\n"
            "execute_process(\n"
            "    COMMAND\n"
            "        ${Python3_EXECUTABLE}\n"
            "        ${BINDING_DIR}/gen/patch_spi_api.py\n"
            "        ${BINDING_DIR}/lib/micropython/ports/rp2/machine_spi.c\n"
            "    RESULT_VARIABLE _spi_result\n"
            "    OUTPUT_VARIABLE _spi_output\n"
            "    OUTPUT_STRIP_TRAILING_WHITESPACE\n"
            ")\n"
            "if(NOT \"${_spi_output}\" STREQUAL \"\")\n"
            "    message(STATUS \"SPI patch: ${_spi_output}\")\n"
            "endif()\n"
            "\n"
        )

        anchor = "set(LVGL_DIR "
        if anchor not in content:
            raise RuntimeError("set(LVGL_DIR anchor not found")

        pos = content.find("\n", content.find(anchor)) + 1
        content = content[:pos] + cmake_patch + content[pos:]
        changed = True

    if changed:
        write_text(path, content)

    return changed


def patch_lvgl_api_gen(path: str) -> bool:
    """Patch LVGL API generator call signature expected by current codebase."""
    content = read_text(path)
    old = "stub_gen.run(args.metadata)"
    new = "stub_gen.run(args.metadata, args.metadata)"

    if new in content:
        return False

    if old not in content:
        raise RuntimeError("stub_gen.run pattern not found")

    write_text(path, content.replace(old, new))
    return True


def patch_lcd_bus(base: str, enable_debug: bool) -> bool:
    """Apply lcd_bus C/C header compatibility patches for RP2040 integration."""
    changed = False

    # Paths touched inside ext_mod/lcd_bus.
    spi_h = os.path.join(base, "common_include", "spi_bus.h")
    spi_c = os.path.join(base, "common_src", "spi_bus.c")
    i80_h = os.path.join(base, "common_include", "i80_bus.h")
    lcd_types_c = os.path.join(base, "lcd_types.c")

    h = read_text(spi_h)
    old_h = h
    h = h.replace("mp_mp_machine_hw_spi_device_obj_t", "mp_machine_hw_spi_device_obj_t")
    h = re.sub(r"(?<!mp_)machine_hw_spi_device_obj_t", "mp_machine_hw_spi_device_obj_t", h)

    modmachine_inc = '#include "extmod/modmachine.h"'
    if modmachine_inc not in h:
        first_inc = h.find("#include")
        if first_inc == -1:
            raise RuntimeError("No #include found in spi_bus.h")
        eol = h.find("\n", first_inc) + 1
        h = h[:eol] + modmachine_inc + "\n" + h[eol:]

    old_layout = "void *buf2;\n\n            bool trans_done;"
    new_layout = "void *buf2;\n            uint32_t buffer_flags;\n\n            bool trans_done;"
    h = h.replace(old_layout, new_layout)

    if h != old_h:
        write_text(spi_h, h)
        changed = True

    # Keep i80 header layout aligned when present.
    if os.path.exists(i80_h):
        i80 = read_text(i80_h)
        i80_new = i80.replace(old_layout, new_layout)
        if i80_new != i80:
            write_text(i80_h, i80_new)
            changed = True

    c = read_text(spi_c)
    old_c = c

    c = c.replace("mp_mp_machine_hw_spi_device_obj_t", "mp_machine_hw_spi_device_obj_t")
    c = re.sub(r"(?<!mp_)machine_hw_spi_device_obj_t", "mp_machine_hw_spi_device_obj_t", c)
    c = c.replace("->spi_bus->mosi", "->spi_bus->data1")
    c = c.replace("->spi_bus->miso", "->spi_bus->data0")

    if modmachine_inc not in c:
        first_inc = c.find("#include")
        if first_inc == -1:
            raise RuntimeError("No #include found in spi_bus.c")
        eol = c.find("\n", first_inc) + 1
        c = c[:eol] + modmachine_inc + "\n" + c[eol:]

    init_marker = "self->panel_io_handle.del = s_spi_del;"
    extra_init = (
        "self->buf1 = NULL;\n"
        "        self->buf2 = NULL;\n"
        "        self->buffer_flags = 0;\n"
        "        self->trans_done = false;\n"
        "        self->rgb565_byte_swap = false;\n"
        "        self->panel_io_handle.allocate_framebuffer = NULL;\n"
        "        self->panel_io_handle.free_framebuffer = NULL;\n\n"
        "        "
    )

    if "self->buf1 = NULL;" not in c:
        if init_marker not in c:
            raise RuntimeError("spi_bus.c init marker not found")
        c = c.replace(init_marker, extra_init + init_marker)

    old_firstbit = (
        "if (args[ARG_lsb_first].u_bool) {\n"
        "            self->firstbit = 1;\n"
        "        } else {\n"
        "            self->firstbit = 0;\n"
        "        }"
    )
    new_firstbit = (
        "if (args[ARG_lsb_first].u_bool) {\n"
        "            self->firstbit = 0;  // SPI_LSB_FIRST\n"
        "        } else {\n"
        "            self->firstbit = 1;  // SPI_MSB_FIRST\n"
        "        }"
    )
    c = c.replace(old_firstbit, new_firstbit)

    # Optional debug print injection for patch troubleshooting.
    if enable_debug:
        debug_marker = (
            "mp_lcd_err_t s_spi_init(mp_obj_t obj, uint16_t width, uint16_t height, uint8_t bpp, uint32_t buffer_size, bool rgb565_byte_swap, uint8_t cmd_bits, uint8_t param_bits)\n"
            "    {"
        )
        debug_body = (
            "mp_lcd_err_t s_spi_init(mp_obj_t obj, uint16_t width, uint16_t height, uint8_t bpp, uint32_t buffer_size, bool rgb565_byte_swap, uint8_t cmd_bits, uint8_t param_bits)\n"
            "    {\n"
            "        mp_printf(&mp_plat_print, \"  [DBG] s_spi_init ENTER\\n\");"
        )
        if "DBG] s_spi_init" not in c and debug_marker in c:
            c = c.replace(debug_marker, debug_body)

        make_new_line = "spi = MP_OBJ_TO_PTR(MP_OBJ_TYPE_GET_SLOT(&machine_spi_type, make_new)"
        if "DBG] before make_new" not in c and make_new_line in c:
            idx = c.find(make_new_line)
            c = c[:idx] + 'mp_printf(&mp_plat_print, "  [DBG] before make_new\\n");\n        ' + c[idx:]
            idx2 = c.find(";", c.find(make_new_line)) + 1
            c = c[:idx2] + '\n        mp_printf(&mp_plat_print, "  [DBG] after make_new\\n");' + c[idx2:]

    if c != old_c:
        write_text(spi_c, c)
        changed = True

    # Optional debug for panel IO init path.
    if enable_debug:
        tc = read_text(lcd_types_c)
        old_init = (
            "mp_lcd_err_t lcd_panel_io_init(mp_obj_t obj, uint16_t width, uint16_t height, uint8_t bpp, uint32_t buffer_size, bool rgb565_byte_swap, uint8_t cmd_bits, uint8_t param_bits)\n"
            "{\n"
            "    mp_lcd_bus_obj_t *self = (mp_lcd_bus_obj_t *)obj;\n\n"
            "    return self->panel_io_handle.init"
        )
        new_init = (
            "mp_lcd_err_t lcd_panel_io_init(mp_obj_t obj, uint16_t width, uint16_t height, uint8_t bpp, uint32_t buffer_size, bool rgb565_byte_swap, uint8_t cmd_bits, uint8_t param_bits)\n"
            "{\n"
            "    mp_lcd_bus_obj_t *self = (mp_lcd_bus_obj_t *)obj;\n"
            "    mp_printf(&mp_plat_print, \"  [DBG] lcd_panel_io_init: init_fn=%p\\n\", self->panel_io_handle.init);\n\n"
            "    return self->panel_io_handle.init"
        )
        if "[DBG] lcd_panel_io_init" not in tc and old_init in tc:
            write_text(lcd_types_c, tc.replace(old_init, new_init))
            changed = True

    return changed


def main() -> int:
    """CLI entrypoint: validate paths, apply patches, and print summary."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".", help="lvgl_micropython root")
    parser.add_argument("--enable-debug", action="store_true")
    args = parser.parse_args()

    root = os.path.abspath(args.root)
    cmake_path = os.path.join(root, "ext_mod", "lvgl", "micropython.cmake")
    gen_path = os.path.join(root, "gen", "lvgl_api_gen_mpy.py")
    lcd_base = os.path.join(root, "ext_mod", "lcd_bus")

    # Fail fast when required files are missing.
    for required in (cmake_path, gen_path, lcd_base):
        if not os.path.exists(required):
            print(f"ERROR: missing required path: {required}")
            return 1

    changed_any = False
    try:
        changed_any |= patch_micropython_cmake(cmake_path)
        changed_any |= patch_lvgl_api_gen(gen_path)
        changed_any |= patch_lcd_bus(lcd_base, args.enable_debug)
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        return 1

    if changed_any:
        print("OK: tree patches applied")
    else:
        print("OK: tree already patched")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
