#!/usr/bin/env bash
# ubuntu/distro.sh — Adaptador de Ubuntu (apt). Define cómo se instalan/verifican paquetes.

DISTRO_LABEL="Ubuntu (linux conf)"
ZRAM_PKG="systemd-zram-generator"   # paquete que usa el modo USB

APT_OPTS=(-y -o DPkg::Lock::Timeout=300 -o Acquire::Retries=3
          -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

# apt-get no interactivo (espera si otro proceso tiene el bloqueo de dpkg)
apt_get() { sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" "$@"; }

pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }
pkg_install()   { apt_get install "$@"; }
pkg_refresh()   { sudo apt-get -o DPkg::Lock::Timeout=300 -o Acquire::Retries=3 update; }
pkg_upgrade()   { pkg_refresh && apt_get upgrade; }
pkg_clean()     { apt_get autoremove; sudo apt-get autoclean -y; sudo apt-get clean; }

# Reparación general: terminar instalaciones a medias, arreglar dependencias, refrescar índices
pkg_repair()    { sudo dpkg --configure -a; apt_get -f install; pkg_refresh; }
pkg_fix_keys()  { pkg_refresh; }

pkg_lock_busy() {
    has_cmd fuser || return 1
    sudo -n fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1
}
