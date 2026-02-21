# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Base RP2 manifest plus local board modules frozen from $(BOARD_DIR)/modules.
include("$(PORT_DIR)/boards/manifest.py")
freeze("$(BOARD_DIR)/modules")
