#!/usr/bin/env bash
# ubuntu/08-productividad.sh — AppFlowy (paquete .deb oficial de GitHub).

section 08 "PRODUCTIVIDAD" "AppFlowy y su respaldo semanal a GitHub"

# dpkg registra el paquete en minúsculas ("appflowy") y deja el ejecutable en /usr/lib/AppFlowy
v_appflowy() { pkg_installed appflowy && [ -x /usr/lib/AppFlowy/AppFlowy ]; }
i_appflowy() {
    if [ "$(dpkg --print-architecture)" != "amd64" ]; then
        warn "AppFlowy solo publica .deb para amd64 (este equipo es $(dpkg --print-architecture))."
        return "$RC_SKIP"
    fi
    local dir url
    dir="$(mktemp -d)"; chmod 755 "$dir"; trap 'rm -rf "$dir"' EXIT
    download https://api.github.com/repos/AppFlowy-IO/AppFlowy/releases/latest "${dir}/release.json"
    url="$(grep -m1 -oE 'https://[^"]*AppFlowy-[0-9.]+-linux-x86_64\.deb' "${dir}/release.json" || true)"
    if [ -z "$url" ]; then
        error "No se encontró el .deb de AppFlowy en la última versión publicada."
        return 1
    fi
    download "$url" "${dir}/appflowy.deb"
    pkg_install "${dir}/appflowy.deb"
}
register_item appflowy "AppFlowy" v_appflowy i_appflowy utilidades-base
register_item appflowy-backup "Respaldo semanal de AppFlowy a GitHub (daemon)" v_appflowy_backup i_appflowy_backup utilidades-base
