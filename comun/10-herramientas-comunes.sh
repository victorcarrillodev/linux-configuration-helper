#!/usr/bin/env bash
# comun/10-herramientas-comunes.sh — Funciones de herramientas que se instalan IGUAL en Ubuntu y Manjaro.
#
# Aquí solo se DEFINEN las funciones de verificación/instalación. Cada distro registra el ítem
# en su propio módulo (así se ejecuta en el orden correcto y con las dependencias de esa distro).

# --- herdr: multiplexor de terminal para agentes de IA (binario estático, instalador oficial) ---
# El instalador oficial descarga el binario a ~/.local/bin y verifica su SHA-256.
v_herdr() { cmd_works herdr --version; }
i_herdr() { run_remote_script https://herdr.dev/install.sh sh; }

# --- Respaldo semanal de AppFlowy a GitHub: appflowy-data-backup.sh + daemon (servicio de usuario) ---
# Se COPIA a ~/.local/bin (no un enlace) para que siga funcionando si luego borras esta carpeta.
AFB_INSTALLED="${HOME}/.local/bin/appflowy-data-backup.sh"
v_appflowy_backup() {
    [ -x "$AFB_INSTALLED" ] && cmp -s "${SCRIPT_DIR}/appflowy-data-backup.sh" "$AFB_INSTALLED" \
        && has_cmd git && has_cmd sqlite3 && "$AFB_INSTALLED" --daemon-installed
}
i_appflowy_backup() {
    case "$DISTRO_ID" in
        ubuntu)  pkg_install git sqlite3 ;;   # sqlite3: copia consistente de las bases de datos de AppFlowy
        manjaro) pkg_install git sqlite ;;
    esac
    mkdir -p "${HOME}/.local/bin"
    install -m 755 "${SCRIPT_DIR}/appflowy-data-backup.sh" "$AFB_INSTALLED"
    "$AFB_INSTALLED" --install-daemon
}

