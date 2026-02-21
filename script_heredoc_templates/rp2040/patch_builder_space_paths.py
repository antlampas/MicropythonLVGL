# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
"""Patch RP2040 builder files to behave correctly when paths contain spaces."""

from pathlib import Path
import sys

# Files to patch are passed explicitly by caller.
init_path = Path(sys.argv[1])
makefile_path = Path(sys.argv[2])
init_text = init_path.read_text(encoding="utf-8")
makefile_text = makefile_path.read_text(encoding="utf-8")
changed = False

# Ensure shlex is available for safe quoting logic.
if "import shlex" not in init_text:
    init_text = init_text.replace("import queue\n", "import queue\nimport shlex\n")
    changed = True

old_spawn = "    cmd_ = list(' '.join(c) for c in cmd_)\n"
# Replace fragile join logic with token-aware command formatting.
new_spawn = """    shell_operators = {\n        '|', '||', '&&', ';',\n        '>', '>>', '<', '<<',\n        '1>', '1>>', '2>', '2>>',\n        '&>', '2>&1', '1>&2'\n    }\n\n    def format_cmd(cmd):\n        if isinstance(cmd, str):\n            return cmd\n\n        if len(cmd) == 1:\n            return cmd[0]\n\n        parts = []\n        for token in cmd:\n            if token in shell_operators:\n                parts.append(token)\n                continue\n\n            if '\"' in token or \"'\" in token:\n                parts.append(token)\n                continue\n\n            if token.startswith('$') and token[1:].replace('_', '').isalnum():\n                parts.append(token)\n                continue\n\n            if (\n                any(char.isspace() for char in token) and\n                ('/' in token or '\\\\' in token)\n            ):\n                parts.append(shlex.quote(token))\n                continue\n\n            parts.append(token)\n\n        return ' '.join(parts)\n\n    cmd_ = [format_cmd(c) for c in cmd_]\n"""

if old_spawn in init_text:
    init_text = init_text.replace(old_spawn, new_spawn, 1)
    changed = True

# Quote frozen manifest when forwarded to CMake, otherwise paths containing
# spaces are split by the shell and CMake sees broken -D arguments.
old_mk = 'CMAKE_ARGS += -DMICROPY_FROZEN_MANIFEST=${FROZEN_MANIFEST}'
new_mk = 'CMAKE_ARGS += -DMICROPY_FROZEN_MANIFEST="${FROZEN_MANIFEST}"'
if old_mk in makefile_text:
    makefile_text = makefile_text.replace(old_mk, new_mk)
    changed = True

# Write back only when something changed.
if changed:
    init_path.write_text(init_text, encoding="utf-8")
    makefile_path.write_text(makefile_text, encoding="utf-8")
    print("Applied builder patch for space-safe paths")
else:
    print("Builder patch already present")
