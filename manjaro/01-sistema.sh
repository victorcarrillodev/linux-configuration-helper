#!/usr/bin/env bash
# manjaro/01-sistema.sh — Actualización del sistema, base-devel/git y yay (ayudante de AUR).

section 01 "SISTEMA" "Actualización del sistema, herramientas de compilación y yay (AUR)"

i_actualizar() { pkg_refresh; }   # pacman -Syu
register_item actualizar "Actualizar el sistema (pacman -Syu)" - i_actualizar

register_pkg base-devel "Herramientas de compilación (base-devel) y git" repo "" base-devel git

v_yay() { cmd_works yay --version; }
i_yay() {
    if ! pkg_install yay; then
        warn "yay no se pudo instalar desde los repositorios; se compila desde AUR (yay-bin)…"
        local dir; dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
        git clone https://aur.archlinux.org/yay-bin.git "${dir}/yay-bin"
        ( cd "${dir}/yay-bin" && makepkg -si --noconfirm )
    fi
}
register_item yay "yay (ayudante de AUR)" v_yay i_yay base-devel
