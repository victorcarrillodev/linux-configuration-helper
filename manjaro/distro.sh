#!/usr/bin/env bash
# manjaro/distro.sh — Adaptador de Manjaro (pacman + yay/AUR).

DISTRO_LABEL="Manjaro (manjaro conf)"
ZRAM_PKG="zram-generator"   # paquete que usa el modo USB

# Opciones para que yay no se detenga en menús interactivos
YAY_OPTS=(--needed --noconfirm --answerdiff None --answerclean None --removemake --sudoloop)

pkg_installed() { pacman -Q "$1" >/dev/null 2>&1; }
pkg_install()   { sudo pacman -S --needed --noconfirm "$@"; }

# Paquetes de AUR (requiere yay, que instala el módulo 01)
aur_install() {
    has_cmd yay || { error "yay no está disponible: no se pueden instalar paquetes de AUR."; return 1; }
    yay -S "${YAY_OPTS[@]}" "$@"
}

pkg_refresh()   { sudo pacman -Syu --noconfirm; }
pkg_upgrade()   { sudo pacman -Syu --noconfirm; }
pkg_clean()     { sudo pacman -Sc --noconfirm; }

pkg_lock_busy() { pgrep -x pacman >/dev/null 2>&1 || pgrep -x yay >/dev/null 2>&1 || pgrep -x makepkg >/dev/null 2>&1; }

# Quita un db.lck huérfano (solo si no hay ningún pacman/yay en marcha)
pkg_unlock() {
    if [ -e /var/lib/pacman/db.lck ] && ! pkg_lock_busy; then
        warn "Eliminando bloqueo huérfano de pacman (db.lck)…"
        sudo rm -f /var/lib/pacman/db.lck
    fi
    return 0
}

pkg_repair() { pkg_unlock; pkg_refresh; }

# Firmas/claves caducadas: reinicializar el llavero
pkg_fix_keys() {
    pkg_unlock
    sudo pacman-key --init
    sudo pacman-key --populate archlinux manjaro
    sudo pacman -Sy --noconfirm --needed archlinux-keyring manjaro-keyring
}
