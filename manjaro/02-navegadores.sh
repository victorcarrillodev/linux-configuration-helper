#!/usr/bin/env bash
# manjaro/02-navegadores.sh — Brave Nightly y Google Chrome (AUR); fuera Firefox.

section 02 "NAVEGADORES" "Brave Nightly y Google Chrome; se elimina Firefox"

register_aur brave  "Brave Nightly"  brave-nightly        brave-nightly-bin
register_aur chrome "Google Chrome"  google-chrome-stable google-chrome

v_sin_firefox() { ! pkg_installed firefox; }
i_sin_firefox() {
    if ! sudo pacman -Rns --noconfirm firefox; then
        warn "No se pudo eliminar Firefox (otro paquete depende de él)."
        return "$RC_SKIP"
    fi
}
register_item sin-firefox "Eliminar Firefox" v_sin_firefox i_sin_firefox
