# Author: antlampas
# Created: 2026-02-21
# License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# See: ./LICENSE.md
# Print a success message.
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
# Print an informational message.
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
# Print a warning message.
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
# Print an error and stop execution.
fail() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Render a visible section header in logs.
print_step() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Write stdin to file only when content changed.
# This keeps regeneration idempotent and avoids unnecessary rebuilds.
write_file() {
    local target="$1"
    local tmp
    tmp="$(mktemp)"

    cat > "$tmp"
    mkdir -p "$(dirname "$target")"

    if [ ! -f "$target" ] || ! cmp -s "$tmp" "$target"; then
        mv "$tmp" "$target"
        info "Updated: $target"
    else
        rm -f "$tmp"
    fi
}
