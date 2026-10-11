#!/usr/bin/env bash
# ubuntu/01-sistema.sh — Actualización del sistema y utilidades base.

section 01 "SISTEMA" "Actualización del sistema y utilidades base"

i_actualizar() {
    pkg_refresh
    apt_get upgrade
}
register_item actualizar "Actualizar paquetes del sistema" - i_actualizar

# gnupg y ca-certificates hacen falta para añadir repositorios externos
UBUNTU_BASE_PKGS=(curl wget git gnupg build-essential htop net-tools software-properties-common
                  apt-transport-https ca-certificates unzip xz-utils zip libglu1-mesa)
v_utilidades_base() { pkgs_installed "${UBUNTU_BASE_PKGS[@]}"; }
i_utilidades_base() { pkg_install "${UBUNTU_BASE_PKGS[@]}"; }
register_item utilidades-base "Utilidades base (curl, git, gcc/make, unzip…)" v_utilidades_base i_utilidades_base
