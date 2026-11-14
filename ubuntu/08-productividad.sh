#!/usr/bin/env bash
# ubuntu/08-productividad.sh — Espanso (expansor de texto, .deb oficial de GitHub).

section 08 "PRODUCTIVIDAD" "Espanso (expansor de texto)"

# .deb oficial de la última versión, variante Wayland o X11 según la sesión (solo amd64)
i_espanso() {
    local flavor dir
    flavor="$(espanso_flavor)"
    if [ "$(dpkg --print-architecture)" != amd64 ]; then
        warn "Espanso solo publica .deb para amd64 (este equipo es $(dpkg --print-architecture))."
        return "$RC_SKIP"
    fi
    dir="$(mktemp -d)"; chmod 755 "$dir"; trap 'rm -rf "$dir"' EXIT
    info "Sesión ${flavor}: se instala espanso-debian-${flavor}."
    download "https://github.com/espanso/espanso/releases/latest/download/espanso-debian-${flavor}-amd64.deb" "${dir}/espanso.deb"
    pkg_install "${dir}/espanso.deb"
    espanso_setup
}
register_item espanso "Espanso (expansor de texto)" v_espanso i_espanso utilidades-base
describe_espanso
