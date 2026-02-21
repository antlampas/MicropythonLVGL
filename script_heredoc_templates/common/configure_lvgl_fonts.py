# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
"""Update LVGL font-related #defines in lv_conf.h from CLI arguments."""

import re
import sys
from pathlib import Path

# Target lv_conf.h file and requested Montserrat size list.
path = Path(sys.argv[1])
enabled_raw = sys.argv[2]

try:
    default_size = int(sys.argv[3])
except ValueError as exc:
    raise SystemExit(f"Invalid LVGL_FONT_DEFAULT_SIZE: {sys.argv[3]!r}") from exc

# Optional binary toggle macros handled by this script.
toggle_names = [
    "LV_FONT_MONTSERRAT_28_COMPRESSED",
    "LV_FONT_DEJAVU_16_PERSIAN_HEBREW",
    "LV_FONT_SIMSUN_14_CJK",
    "LV_FONT_SIMSUN_16_CJK",
    "LV_FONT_UNSCII_8",
    "LV_FONT_UNSCII_16",
]

# Parse optional 0/1 toggles.
toggles = {}
for idx, name in enumerate(toggle_names, start=4):
    value = sys.argv[idx].strip()
    if value not in {"0", "1"}:
        raise SystemExit(f"Invalid value for {name}: {value!r} (expected 0 or 1)")
    toggles[name] = value

# Supported LVGL Montserrat macro sizes.
allowed_sizes = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48]
allowed_set = set(allowed_sizes)

tokens = [tok for tok in re.split(r"[,\s]+", enabled_raw.strip()) if tok]
if not tokens:
    raise SystemExit("LVGL_MONTSERRAT_FONTS cannot be empty")

enabled_sizes = set()
for tok in tokens:
    if not tok.isdigit():
        raise SystemExit(f"Invalid Montserrat size: {tok!r}")
    size = int(tok)
    if size not in allowed_set:
        raise SystemExit(f"Unsupported Montserrat size: {size}")
    enabled_sizes.add(size)

if default_size not in allowed_set:
    raise SystemExit(
        f"LVGL_FONT_DEFAULT_SIZE={default_size} is not supported. "
        f"Allowed: {', '.join(map(str, allowed_sizes))}"
    )

if default_size not in enabled_sizes:
    enabled_sizes.add(default_size)

content = path.read_text(encoding="utf-8")

# Replace one #define value while preserving trailing comments and formatting.
def replace_define(text: str, name: str, value: str, expected_pattern: str = r"[01]") -> str:
    pattern = re.compile(
        rf"(^\s*#define\s+{re.escape(name)}\s+){expected_pattern}(\s*(?:/\*.*)?$)",
        re.MULTILINE,
    )
    def _repl(match):
        return f"{match.group(1)}{value}{match.group(2)}"

    new_text, count = pattern.subn(_repl, text)
    if count == 0:
        raise SystemExit(f"Define not found in lv_conf.h: {name}")
    return new_text

# Enable/disable all Montserrat sizes based on requested set.
for size in allowed_sizes:
    macro = f"LV_FONT_MONTSERRAT_{size}"
    val = "1" if size in enabled_sizes else "0"
    content = replace_define(content, macro, val)

# Apply binary toggles requested by caller.
for macro, val in toggles.items():
    content = replace_define(content, macro, val)

# Always keep image support enabled for display demos/examples.
content = replace_define(content, "LV_USE_IMAGE", "1")

content = replace_define(
    content,
    "LV_FONT_DEFAULT",
    f"&lv_font_montserrat_{default_size}",
    expected_pattern=r"&lv_font_[A-Za-z0-9_]+",
)

path.write_text(content, encoding="utf-8")

enabled_list = ", ".join(str(size) for size in sorted(enabled_sizes))
print(f"Enabled Montserrat: {enabled_list}")
print(f"Default font: lv_font_montserrat_{default_size}")
print("LV_USE_IMAGE: 1")
