#!/usr/bin/env bash
# lib/shellrc.sh — Edición idempotente de ~/.profile, ~/.bashrc y ~/.zshrc.

[ -n "${SHELLRC_LOADED:-}" ] && return 0
SHELLRC_LOADED=1

# Añade un bloque al final de ~/.zshrc si el marcador no está
append_zshrc_block() {
    local marker="$1" block="$2"
    if ! grep -qF -- "${marker}" "${HOME}/.zshrc" 2>/dev/null; then
        printf '\n%s\n' "${block}" >> "${HOME}/.zshrc"
    fi
}

# Añade una línea a ~/.zshrc y ~/.bashrc (los que existan) si no está
add_to_shell_rc() {
    local line="$1" rc
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        [ -f "$rc" ] || continue
        grep -qxF -- "$line" "$rc" || printf '%s\n' "$line" >> "$rc"
    done
}

# Bloque canónico de PATH para un directorio (usa $PATH real, no una copia)
_path_block() {
    local dir="$1" shown="$1"
    case "$dir" in "$HOME"/*) shown="\$HOME/${dir#"$HOME"/}" ;; esac
    printf '%s\n' "# >>> linux-conf PATH ${dir} >>>"
    printf '%s\n' 'case ":$PATH:" in'
    printf '  *":%s:"*) ;;\n' "$shown"
    printf '  *) export PATH="%s:$PATH" ;;\n' "$shown"
    printf '%s\n' 'esac'
    printf '%s\n' "# <<< linux-conf PATH ${dir} <<<"
}

# path_entry_ok <dir> <rc> — el bloque correcto ya está en el archivo
path_entry_ok() {
    local dir="$1" rc="$2" have
    [ -f "$rc" ] || return 1
    have="$(awk -v s="# >>> linux-conf PATH ${dir} >>>" -v e="# <<< linux-conf PATH ${dir} <<<" \
        '$0==s{f=1} f{print} $0==e{f=0}' "$rc")"
    [ "$have" = "$(_path_block "$dir")" ]
}

# ensure_path_entry <dir> [rc] — deja el bloque de PATH correcto (reemplaza uno antiguo/erróneo)
ensure_path_entry() {
    local dir="$1" rc="${2:-$HOME/.profile}" tmp
    mkdir -p "$dir"
    path_entry_ok "$dir" "$rc" && return 0
    [ -f "$rc" ] || touch "$rc"
    tmp="$(mktemp)"
    awk -v s="# >>> linux-conf PATH ${dir} >>>" -v e="# <<< linux-conf PATH ${dir} <<<" \
        '$0==s{skip=1} !skip{print} $0==e{skip=0}' "$rc" > "$tmp"
    cat "$tmp" > "$rc"
    rm -f "$tmp"
    { echo; _path_block "$dir"; } >> "$rc"
}

# Directorios que siempre deben estar en el PATH del usuario
PATH_DIRS=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.bun/bin" "$HOME/.local/share/pnpm")

# path_entries_ok <rc…> / ensure_path_entries <rc…> — para todos los PATH_DIRS
path_entries_ok() {
    local rc d
    for rc in "$@"; do
        for d in "${PATH_DIRS[@]}"; do path_entry_ok "$d" "$rc" || return 1; done
    done
}
ensure_path_entries() {
    local rc d
    for rc in "$@"; do
        for d in "${PATH_DIRS[@]}"; do ensure_path_entry "$d" "$rc"; done
    done
}
