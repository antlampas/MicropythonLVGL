# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
"""Extract max app and filesystem partition sizes from an ESP32 partition CSV."""

import csv
import sys
from pathlib import Path

csv_path = Path(sys.argv[1])
# Collect all candidate sizes and return max values.
app_sizes = []
fs_sizes = []

for row in csv.reader(csv_path.read_text(encoding="utf-8").splitlines()):
    # Skip blank/comment/malformed rows.
    if not row:
        continue
    if row[0].strip().startswith("#"):
        continue
    if len(row) < 5:
        continue

    p_type = row[1].strip()
    p_subtype = row[2].strip().lower()
    size_raw = row[4].strip()

    try:
        size = int(size_raw, 0)
    except ValueError:
        # Ignore non-numeric size expressions.
        continue

    # Keep app partitions separate from filesystem-like data partitions.
    if p_type == "app":
        app_sizes.append(size)
    elif p_type == "data" and p_subtype in {"fat", "spiffs", "littlefs"}:
        fs_sizes.append(size)

app_max = max(app_sizes) if app_sizes else 0
fs_max = max(fs_sizes) if fs_sizes else 0
print(f"{app_max} {fs_max}")
