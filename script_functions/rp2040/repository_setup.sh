# Author: antlampas
# Created: 2026-02-20
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Patch upstream builder files so paths containing spaces keep working.
patch_builder_space_paths() {
    local init_file="$LVGL_DIR/builder/__init__.py"
    local rp2_makefile="$LVGL_DIR/lib/micropython/ports/rp2/Makefile"
    patch_builder_space_paths_common \
        "$HEREDOC_TEMPLATES_DIR/rp2040/patch_builder_space_paths.py" \
        "$init_file" \
        "$rp2_makefile"
}

# Verify/install toolchain dependencies required by RP2040 builds.
install_dependencies() {
    print_step "STEP 0: Check and install dependencies"

    declare -A dep_map
    dep_map["git"]="git"
    dep_map["python3"]="python3"
    dep_map["make"]="make"
    dep_map["cmake"]="cmake"
    dep_map["ninja"]="ninja-build"
    dep_map["arm-none-eabi-gcc"]="arm-none-eabi-gcc arm-none-eabi-newlib arm-none-eabi-binutils"

    local -a missing_pkgs=()
    local bin pkg

    for bin in "${!dep_map[@]}"; do
        if ! command -v "$bin" &>/dev/null; then
            warn "Missing: $bin"
            for pkg in ${dep_map[$bin]}; do
                printf '%s\n' "${missing_pkgs[@]}" | grep -qx "$pkg" || missing_pkgs+=("$pkg")
            done
        else
            ok "$bin: $(command -v "$bin")"
        fi
    done

    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        ok "All dependencies already present"
        return
    fi

    if [ "$INSTALL_DEPS" != "1" ]; then
        warn "INSTALL_DEPS=0. Install manually: ${missing_pkgs[*]}"
        return
    fi

    if ! command -v dnf &>/dev/null; then
        warn "dnf not available. Install manually: ${missing_pkgs[*]}"
        return
    fi

    info "Installing with dnf: ${missing_pkgs[*]}"
    sudo -v &>/dev/null || fail "sudo not available"
    sudo dnf install -y "${missing_pkgs[@]}" || fail "Dependency installation failed"
    ok "Dependencies installed"
}

# Delegate repository preparation to the shared helper.
ensure_repo() {
    ensure_repo_common "STEP 1: Prepare repository"
}

# Initialize only the submodules required by RP2040 builds.
init_submodules() {
    if [ "$UPDATE_SUBMODULES" != "1" ]; then
        warn "UPDATE_SUBMODULES=0 -> skipping submodule update"
        return
    fi

    print_step "STEP 2: Submodule initialization"
    init_submodules_common ext_mod/ lib/lvgl lib/micropython
}

# RP2040 currently needs no extra per-port setup beyond dependencies.
prepare_port_toolchain() {
    print_step "STEP 4: Prepare RP2040 toolchain"
    info "No extra toolchain setup required beyond system dependencies"
}
