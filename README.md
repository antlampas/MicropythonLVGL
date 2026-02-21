<!-- Author: antlampas -->
<!-- Created: 2026-02-21 -->
<!-- License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0). See LICENSE.md -->

# MicropythonLVGL

MicropythonLVGL is a build-and-automation workspace for generating custom
`lvgl_micropython` firmware for two Waveshare touch display boards:

- Waveshare ESP32-S3-Touch-LCD-1.28
- Waveshare RP2040-Touch-LCD-1.28

The project provides aligned build workflows so both targets expose the same
high-level features (LVGL fonts, board helper module support, path-safe
builder patching, firmware size checks, and artifact export), while preserving
hardware-specific differences required by each architecture.

## Repository Layout

- `compile_esp32.sh`: top-level entrypoint for ESP32 builds.
- `compile_rp2040.sh`: top-level entrypoint for RP2040 builds.
- `script_functions/`: modular shell functions used by both entrypoints.
  - `common/`: shared logging/repository/font helpers.
  - `esp32/`: ESP32-specific setup/build logic.
  - `rp2040/`: RP2040-specific setup/build logic.
- `script_heredoc_templates/`: Python/template assets used to patch source
  trees, generate board modules, and apply build-time configuration.

## Build Modes

Both compile entrypoints support the same modes:

- `all`: bootstrap + build.
- `bootstrap`: dependencies/repository/patch/context preparation.
- `build`: build from prepared repository.

## Artifacts

- ESP32 output is copied to `firmware_esp32.bin`.
- RP2040 output is copied to `firmware_rp2040.uf2`.

## License

This repository is licensed under **Creative Commons Attribution-ShareAlike
4.0 International (CC BY-SA 4.0)**.

See `LICENSE.md` for details.
