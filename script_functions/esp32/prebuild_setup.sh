# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Patch upstream builder files so paths containing spaces keep working.
patch_builder_space_paths() {
    local init_file="$LVGL_DIR/builder/__init__.py"
    local esp32_file="$LVGL_DIR/builder/esp32.py"
    local mp_makefile="$LVGL_DIR/lib/micropython/ports/esp32/Makefile"
    patch_builder_space_paths_common \
        "$HEREDOC_TEMPLATES_DIR/esp32/patch_builder_space_paths.py" \
        "$init_file" \
        "$esp32_file" \
        "$mp_makefile"
}

# Ensure user-local python tools are discoverable (pip --user installs).
export PATH="$HOME/.local/bin:$PATH"

# Verify/install build dependencies required by ESP32 + ESP-IDF pipeline.
install_dependencies() {
    print_step "STEP 0: Check and install dependencies"

    declare -A dep_map
    dep_map["git"]="git"
    dep_map["python3"]="python3"
    dep_map["python"]="python-unversioned-command"
    dep_map["make"]="make"
    dep_map["cmake"]="cmake"
    dep_map["ninja"]="ninja-build"
    dep_map["gcc"]="gcc"
    dep_map["g++"]="gcc-c++"
    dep_map["ccache"]="ccache"
    dep_map["pkg-config"]="pkgconf-pkg-config"
    dep_map["dfu-util"]="dfu-util"
    dep_map["flex"]="flex"
    dep_map["bison"]="bison"
    dep_map["gperf"]="gperf"
    dep_map["wget"]="wget"
    dep_map["tar"]="tar"

    local -a pkgs_to_install=()
    local bin pkg

    for bin in "${!dep_map[@]}"; do
        if ! command -v "$bin" &>/dev/null; then
            warn "Missing: $bin"
            for pkg in ${dep_map[$bin]}; do
                printf '%s\n' "${pkgs_to_install[@]}" | grep -qx "$pkg" || pkgs_to_install+=("$pkg")
            done
        else
            ok "$bin: $(command -v "$bin")"
        fi
    done

    if [ "$INSTALL_DEPS" = "1" ] && [ ${#pkgs_to_install[@]} -gt 0 ]; then
        if command -v dnf &>/dev/null; then
            info "Installing packages: ${pkgs_to_install[*]}"
            sudo -v &>/dev/null || fail "sudo not available"
            sudo dnf install -y "${pkgs_to_install[@]}" || fail "Dependency installation failed"
            ok "System dependencies installed"
        else
            warn "dnf not found. Install these packages manually: ${pkgs_to_install[*]}"
        fi
    elif [ ${#pkgs_to_install[@]} -gt 0 ]; then
        warn "Missing dependencies (INSTALL_DEPS=0): ${pkgs_to_install[*]}"
    else
        ok "All system dependencies already present"
    fi
}

# Delegate repository preparation to the shared helper.
ensure_repo() {
    ensure_repo_common "STEP 1: Prepare repository"
}

# Initialize only the submodules required by ESP32 builds.
init_submodules() {
    if [ "$UPDATE_SUBMODULES" != "1" ]; then
        warn "UPDATE_SUBMODULES=0 -> skipping submodule update"
        return
    fi

    print_step "STEP 2: Submodule initialization"
    init_submodules_common ext_mod/ lib/lvgl lib/micropython lib/esp-idf
}

# Install MicroPython/port Python requirements when available.
install_python_requirements() {
    print_step "STEP 4a: Install Python requirements"

    local req_file="$LVGL_DIR/lib/micropython/ports/esp32/requirements.txt"
    if [ -f "$req_file" ]; then
        "$PYTHON_BIN" -m pip install --user -r "$req_file" || fail "Python requirements installation failed"
        ok "Python requirements installed from $req_file"
    else
        warn "No port requirements file found at $req_file"
        info "Continuing: ESP-IDF install.sh will install required Python packages"
    fi
}

# Install and export ESP-IDF environment for the selected chip.
setup_esp_idf() {
    print_step "STEP 4b: Setup ESP-IDF"

    local idf_dir="$LVGL_DIR/lib/esp-idf"
    local idf_install="$idf_dir/install.sh"
    local idf_export="$idf_dir/export.sh"

    [ -f "$idf_install" ] || fail "Missing ESP-IDF install script: $idf_install"
    [ -f "$idf_export" ] || fail "Missing ESP-IDF export script: $idf_export"

    info "Installing ESP-IDF tools for target: $ESP_CHIP"
    bash "$idf_install" "$ESP_CHIP" || fail "ESP-IDF tools installation failed"

    info "Loading ESP-IDF environment"
    # shellcheck disable=SC1090
    source "$idf_export" >/dev/null || fail "Unable to source ESP-IDF environment"
    ok "ESP-IDF environment is active"
}

# Prepare toolchain/environment prerequisites for the port.
prepare_port_toolchain() {
    install_python_requirements
    setup_esp_idf
}

# Apply shared build-context changes (fonts + optional frozen board helper).
prepare_build_context() {
    configure_lvgl_fonts
    if [ "$FREEZE_BOARD_MODULE" = "1" ]; then
        create_frozen_board_module
    else
        info "Frozen board module disabled (FREEZE_BOARD_MODULE=0)"
    fi
}
