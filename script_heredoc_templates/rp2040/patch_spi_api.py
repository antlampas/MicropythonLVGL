#!/usr/bin/env python3
# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
"""Patch rp2 machine_spi.c to new mp_spi_common.h API."""

import os
import re
import sys


def main() -> int:
    """Patch one machine_spi.c file and keep operation idempotent."""
    if len(sys.argv) < 2:
        print("ERROR: missing path")
        return 1

    # File path is supplied by caller (repo script or CMake hook).
    spi_path = sys.argv[1]
    if not os.path.exists(spi_path):
        print("SKIP: " + spi_path)
        return 0

    with open(spi_path, "r", encoding="utf-8") as fh:
        content = fh.read()

    if (
        "mp_machine_hw_spi_device_obj_t" in content
        and "machine_hw_spi_obj_t" not in content
        and ".data1 =" in content
    ):
        # Nothing to do if the new API symbols are already in place.
        print("already patched")
        return 0

    # Drop obsolete struct definition and translate old field names.
    pat = re.compile(
        r"typedef\s+struct\s+_machine_hw_spi_obj_t\s*\{.*?\}\s*machine_hw_spi_obj_t\s*;",
        re.DOTALL,
    )
    content = pat.sub("", content)

    # Symbol-level replacements from old API to mp_spi_common.h API.
    pairs = [
        ("machine_hw_spi_obj_t", "mp_machine_hw_spi_device_obj_t"),
        (".mosi =", ".data1 ="),
        (".miso =", ".data0 ="),
        (".active_devices =", ".device_count ="),
        ("spi_bus->mosi", "spi_bus->data1"),
        ("spi_bus->miso", "spi_bus->data0"),
        ("spi_bus->active_devices", "spi_bus->device_count"),
        ("self->baudrate", "self->freq"),
        ("self->mosi", "self->data1"),
        ("self->miso", "self->data0"),
    ]

    for old, new in pairs:
        content = content.replace(old, new)

    with open(spi_path, "w", encoding="utf-8") as fh:
        fh.write(content)

    print("patched OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
