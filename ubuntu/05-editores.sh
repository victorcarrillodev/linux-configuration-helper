#!/usr/bin/env bash
# ubuntu/05-editores.sh — Visual Studio Code y Antigravity (repositorios oficiales).
# El usuario elige en el PASO 3 del menú entre Antigravity, Cursor y VS Code (uno o varios);
# aquí se definen los ítems, el motor del instalador filtra los que no se eligieron.

section 05 "EDITORES" "Editores elegidos en el menú: Antigravity IDE, Cursor y VS Code"

# --- Visual Studio Code ---
v_vscode() { has_cmd code && pkg_installed code; }
i_vscode() {
    sudo mkdir -p /etc/apt/keyrings
    # Quitar fuentes duplicadas de Microsoft (el paquete 'code' crea las suyas y chocan en Signed-By)
    local f
    for f in /etc/apt/sources.list.d/*; do
        [ -f "$f" ] && [ "$f" != /etc/apt/sources.list.d/vscode.list ] \
            && grep -qs "packages.microsoft.com/repos/code" "$f" && sudo rm -f "$f"
    done
    local tmp; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    download https://packages.microsoft.com/keys/microsoft.asc "$tmp"
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/packages.microsoft.gpg "$tmp"
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    pkg_refresh
    pkg_install code
    # Si el paquete creó su propia fuente (vscode.sources), la nuestra sobra y provocaría conflicto
    if [ -f /etc/apt/sources.list.d/vscode.sources ]; then
        sudo rm -f /etc/apt/sources.list.d/vscode.list
        pkg_refresh
    fi
}
register_item vscode "Visual Studio Code" v_vscode i_vscode utilidades-base
set_editor_packages vscode code

# --- Antigravity ---
v_antigravity() { has_cmd antigravity || pkg_installed antigravity; }
i_antigravity() {
    sudo mkdir -p /etc/apt/keyrings
    sudo rm -f /etc/apt/keyrings/antigravity-repo-key.gpg /etc/apt/sources.list.d/antigravity.list /etc/apt/sources.list.d/antigravity.sources
    local tmp; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    download https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg "$tmp"
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg "$tmp"
    sudo chmod a+r /etc/apt/keyrings/antigravity-repo-key.gpg
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" \
        | sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
    pkg_refresh
    pkg_install antigravity
}
register_item antigravity "Antigravity" v_antigravity i_antigravity utilidades-base
set_editor_packages antigravity antigravity

# --- Cursor (importable .deb oficial; solo amd64 como el resto de sus paquetes) ---
v_cursor() { has_cmd cursor || pkg_installed cursor; }
i_cursor() {
    if [ "$(dpkg --print-architecture)" != "amd64" ]; then
        warn "Cursor publica .deb solo para amd64 (este equipo es $(dpkg --print-architecture))."
        return "$RC_SKIP"
    fi
    local dir
    dir="$(mktemp -d)"; chmod 755 "$dir"
    trap 'rm -rf "$dir"' EXIT
    download https://downloader.cursor.sh/deb/x64 "${dir}/cursor.deb"
    pkg_install "${dir}/cursor.deb"
}
register_item cursor "Cursor" v_cursor i_cursor utilidades-base
set_editor_packages cursor cursor
