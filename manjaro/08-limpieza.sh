#!/usr/bin/env bash
# manjaro/08-limpieza.sh — Caché de pacman/yay y paquetes huérfanos.
# (El borrado del instalador es opcional: al final se pregunta.)

section 08 "LIMPIEZA" "Caché de pacman y yay, y paquetes huérfanos"

i_limpieza() {
    pkg_clean
    if has_cmd yay; then yay -Sc --noconfirm || true; fi
    local orphans
    orphans="$(pacman -Qtdq 2>/dev/null || true)"
    if [ -n "$orphans" ]; then
        # shellcheck disable=SC2086
        sudo pacman -Rns --noconfirm $orphans
    else
        info "No hay paquetes huérfanos."
    fi
}
register_item limpieza "Limpiar caché y paquetes huérfanos" - i_limpieza
