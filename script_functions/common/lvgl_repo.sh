# Author: antlampas
# Created: 2026-02-21
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Apply the requested LVGL font matrix to lib/lv_conf.h.
configure_lvgl_fonts() {
    print_step "${LVGL_FONTS_STEP_LABEL:-STEP: Configure LVGL fonts}"

    local lv_conf_file="$LVGL_DIR/lib/lv_conf.h"
    [ -f "$lv_conf_file" ] || fail "Missing lv_conf.h: $lv_conf_file"

    "$PYTHON_BIN" "$HEREDOC_TEMPLATES_DIR/common/configure_lvgl_fonts.py" "$lv_conf_file" \
        "$LVGL_MONTSERRAT_FONTS" \
        "$LVGL_FONT_DEFAULT_SIZE" \
        "$LVGL_FONT_MONTSERRAT_28_COMPRESSED" \
        "$LVGL_FONT_DEJAVU_16_PERSIAN_HEBREW" \
        "$LVGL_FONT_SIMSUN_14_CJK" \
        "$LVGL_FONT_SIMSUN_16_CJK" \
        "$LVGL_FONT_UNSCII_8" \
        "$LVGL_FONT_UNSCII_16" || fail "Failed configuring LVGL fonts"

    ok "LVGL font configuration applied"
}

# Treat common truthy values as "enabled".
_is_truthy() {
    case "${1:-}" in
        1|y|Y|yes|YES|true|TRUE|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

# Clone or reuse lvgl_micropython according to RECLONE policy.
ensure_repo_common() {
    local step_label="${1:-STEP 1: Prepare repository}"
    print_step "$step_label"

    # Resolve what to do when the target directory already exists.
    if [ -d "$LVGL_DIR" ]; then
        case "${RECLONE:-0}" in
            ask|ASK|Ask)
                warn "Directory $LVGL_DIR already exists"
                if [ -t 0 ]; then
                    read -rp "Delete it and reclone? [y/N] " _answer
                    if _is_truthy "$_answer"; then
                        info "Removing existing $LVGL_DIR"
                        rm -rf "$LVGL_DIR"
                    else
                        info "Using existing directory"
                    fi
                else
                    warn "RECLONE=ask but no interactive terminal detected. Using existing directory."
                fi
                ;;
            1|y|Y|yes|YES|true|TRUE|on|ON)
                info "Removing existing $LVGL_DIR"
                rm -rf "$LVGL_DIR"
                ;;
            0|n|N|no|NO|false|FALSE|off|OFF|'')
                info "Using existing directory"
                ;;
            *)
                fail "Invalid RECLONE='${RECLONE}'. Use ask|0|1"
                ;;
        esac
    fi

    # Refuse non-git folders because the workflow expects a repository layout.
    if [ -d "$LVGL_DIR" ] && [ ! -d "$LVGL_DIR/.git" ]; then
        fail "$LVGL_DIR exists but is not a git repository"
    fi

    # Clone only when needed; otherwise keep the local checkout.
    if [ ! -d "$LVGL_DIR/.git" ]; then
        info "Cloning from $REPO_URL ..."
        git clone "$REPO_URL" "$LVGL_DIR" || fail "Clone failed"
        ok "Repository cloned"
    else
        ok "Using existing repository: $LVGL_DIR"
    fi

    cd "$LVGL_DIR"
}

# Run platform-specific builder patch scripts with shared validation/error handling.
patch_builder_space_paths_common() {
    local patch_script="$1"
    shift

    [ -f "$patch_script" ] || fail "Missing patch script: $patch_script"
    [ "$#" -gt 0 ] || fail "No files provided for builder patching"

    print_step "${PATCH_BUILDER_STEP_LABEL:-STEP 3: Patch builder for paths with spaces}"

    local file
    for file in "$@"; do
        [ -f "$file" ] || fail "Missing builder file: $file"
    done

    "$PYTHON_BIN" "$patch_script" "$@" || fail "Failed patching builder path handling"
    ok "Builder path patch check completed"
}

# Initialize a selected list of submodules.
init_submodules_common() {
    [ "$#" -gt 0 ] || fail "No submodules provided"

    local submodule
    for submodule in "$@"; do
        git submodule update --init --recursive "$submodule" || fail "$submodule initialization failed"
    done

    ok "Submodules initialized"
}
