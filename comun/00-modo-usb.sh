#!/usr/bin/env bash
# comun/00-modo-usb.sh — Destino: USB (optimiza) o Escritorio (revierte lo de USB). Común a Ubuntu y Manjaro.
#
# Este archivo solo REGISTRA ítems; el motor (lib/core.sh) los verifica y ejecuta.

USB_MARK="Generado por new-linux-conf (modo USB)"
USB_MARK_OLD="Generado por config.sh"      # marca de la versión antigua de Manjaro
USB_SYSCTL_CONF="/etc/sysctl.d/99-usb-optimize.conf"
USB_JOURNALD_CONF="/etc/systemd/journald.conf.d/99-usb-optimize.conf"
USB_UDEV_RULE="/etc/udev/rules.d/60-usb-ioscheduler.rules"
USB_ZRAM_CONF="/etc/systemd/zram-generator.conf"
USB_FSTAB="${USB_FSTAB:-/etc/fstab}"
USB_FSTAB_RE='^[^#[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+(ext4|btrfs|xfs|f2fs)[[:space:]]'

# El archivo existe y lo creó este instalador (o la versión antigua)
usb_file_ours() { [ -f "$1" ] && grep -qE "${USB_MARK}|${USB_MARK_OLD}" "$1" 2>/dev/null; }

if [ "$INSTALL_TARGET" = "usb" ]; then

section 00 "USB" "Optimizaciones para sistema portable: menos escrituras y más respuesta"

# 1) sysctl: poco swap y escrituras agrupadas con límite bajo de datos pendientes
v_usb_sysctl() { usb_file_ours "$USB_SYSCTL_CONF" && [ "$(sysctl -n vm.swappiness 2>/dev/null)" = "10" ]; }
i_usb_sysctl() {
    sudo tee "$USB_SYSCTL_CONF" >/dev/null <<EOF
# ${USB_MARK}
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_background_bytes = 16777216
vm.dirty_bytes = 50331648
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000
EOF
    sudo sysctl -p "$USB_SYSCTL_CONF" >/dev/null
}
register_item usb-sysctl "Ajustes de memoria y escritura (sysctl)" v_usb_sysctl i_usb_sysctl

# 2) journald en RAM: los logs no se escriben en la USB (se pierden al reiniciar)
v_usb_journald() { usb_file_ours "$USB_JOURNALD_CONF"; }
i_usb_journald() {
    sudo mkdir -p "$(dirname "$USB_JOURNALD_CONF")"
    sudo tee "$USB_JOURNALD_CONF" >/dev/null <<EOF
# ${USB_MARK}
[Journal]
Storage=volatile
RuntimeMaxUse=64M
EOF
    sudo systemctl restart systemd-journald
}
register_item usb-journald "Logs del sistema en RAM (journald)" v_usb_journald i_usb_journald

# 3) Planificador de E/S BFQ para discos USB (mejor respuesta bajo escritura)
v_usb_bfq() { usb_file_ours "$USB_UDEV_RULE"; }
i_usb_bfq() {
    sudo tee "$USB_UDEV_RULE" >/dev/null <<EOF
# ${USB_MARK}
ACTION=="add|change", KERNEL=="sd[a-z]", ENV{ID_BUS}=="usb", ATTR{queue/scheduler}="bfq"
EOF
    sudo modprobe bfq 2>/dev/null || true
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=block --action=change
}
register_item usb-bfq "Planificador de disco BFQ para USB" v_usb_bfq i_usb_bfq

# 4) zram: swap comprimido en RAM (tiene prioridad sobre cualquier swap en la USB)
v_usb_zram() { usb_file_ours "$USB_ZRAM_CONF" && pkg_installed "$ZRAM_PKG"; }
i_usb_zram() {
    pkg_install "$ZRAM_PKG"
    sudo tee "$USB_ZRAM_CONF" >/dev/null <<EOF
# ${USB_MARK}
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
    sudo systemctl daemon-reload
    sudo systemctl start systemd-zram-setup@zram0.service || warn "zram se activará en el próximo reinicio."
}
register_item usb-zram "Swap comprimido en RAM (zram)" v_usb_zram i_usb_zram

# 5) noatime: evita una escritura por cada lectura (ext4/btrfs/xfs/f2fs de fstab, incluidos subvolúmenes)
v_usb_noatime() {
    ! awk -v re="$USB_FSTAB_RE" '$0 ~ re && $0 !~ /noatime/ {found=1} END{exit !found}' "$USB_FSTAB" 2>/dev/null
}
i_usb_noatime() {
    local mp bak="${USB_FSTAB}.bak-new-linux-conf"
    sudo cp "$USB_FSTAB" "$bak"
    sudo sed -i -E "/${USB_FSTAB_RE}/ {
        /noatime/ b
        s/(^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+)([^[:space:]]+)/\1\2,noatime/
        s/,(relatime|atime|strictatime)//g
        s/[[:space:]](relatime|atime|strictatime),/ /
    }" "$USB_FSTAB"
    if sudo findmnt --verify --tab-file "$USB_FSTAB" >/dev/null 2>&1; then
        for mp in $(awk -v re="$USB_FSTAB_RE" '$0 ~ re {print $2}' "$USB_FSTAB"); do
            mountpoint -q "$mp" && sudo mount -o remount,noatime "$mp" || true
        done
        info "noatime aplicado (respaldo: ${bak})"
    else
        sudo cp "$bak" "$USB_FSTAB"
        error "fstab no pasó la verificación: se restauró el original."
        return 1
    fi
}
register_item usb-noatime "Montajes sin registro de acceso (noatime)" v_usb_noatime i_usb_noatime

# 6) /tmp en RAM (se activa en el próximo arranque para no tapar archivos abiertos ahora)
v_usb_tmp() {
    [ "$(findmnt -no FSTYPE /tmp 2>/dev/null)" = "tmpfs" ] || systemctl is-enabled --quiet tmp.mount 2>/dev/null
}
i_usb_tmp() {
    if ! systemctl cat tmp.mount >/dev/null 2>&1 && [ -f /usr/share/systemd/tmp.mount ]; then
        sudo cp /usr/share/systemd/tmp.mount /etc/systemd/system/tmp.mount
    fi
    sudo systemctl enable tmp.mount
}
register_item usb-tmp "/tmp en RAM" v_usb_tmp i_usb_tmp

# 7) Perfiles de navegador en RAM (se sincronizan a disco periódicamente)
v_usb_psd() {
    pkg_installed profile-sync-daemon && {
        systemctl --user is-enabled --quiet psd.service 2>/dev/null \
            || [ -e "$HOME/.config/systemd/user/default.target.wants/psd.service" ]
    }
}
i_usb_psd() {
    pkg_install profile-sync-daemon
    if ! systemctl --user enable psd.service 2>/dev/null; then
        # Sin bus de usuario (p. ej. por SSH): se crea el enlace que haría 'enable'
        mkdir -p "$HOME/.config/systemd/user/default.target.wants"
        ln -sf /usr/lib/systemd/user/psd.service "$HOME/.config/systemd/user/default.target.wants/psd.service"
    fi
}
register_item usb-psd "Perfiles de navegador en RAM (profile-sync-daemon)" v_usb_psd i_usb_psd

else

section 00 "ESCRITORIO" "Sin optimizaciones USB (se revierten las que hubiera de una instalación anterior)"

v_usb_revertir() {
    local f
    for f in "$USB_SYSCTL_CONF" "$USB_JOURNALD_CONF" "$USB_UDEV_RULE" "$USB_ZRAM_CONF"; do
        usb_file_ours "$f" && return 1
    done
    return 0
}
i_usb_revertir() {
    local f
    for f in "$USB_SYSCTL_CONF" "$USB_JOURNALD_CONF" "$USB_UDEV_RULE" "$USB_ZRAM_CONF"; do
        usb_file_ours "$f" && sudo rm -f "$f"
    done
    sudo sysctl --system >/dev/null || true
    sudo systemctl restart systemd-journald || true
    sudo udevadm control --reload || true
    sudo systemctl daemon-reload
    info "Optimizaciones USB revertidas (zram se desactiva al reiniciar)."
}
register_item usb-revertir "Revertir optimizaciones USB anteriores (si las hubiera)" v_usb_revertir i_usb_revertir

fi
