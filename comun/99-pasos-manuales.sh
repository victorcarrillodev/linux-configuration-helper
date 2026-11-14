#!/usr/bin/env bash
# comun/99-pasos-manuales.sh — Calcula, al terminar, lo que el usuario debe hacer a mano.
#
# No registra ítems: registra un "gancho" que el motor ejecuta tras el resumen.
# Usa el estado REAL del sistema (no solo lo que se instaló ahora), así que sirve
# también al volver a ejecutar el instalador.

join_by() { local sep="$1" out="" x; shift; for x in "$@"; do out+="${out:+$sep}$x"; done; printf '%s' "$out"; }

post_comun() {
    local id failed=() apps=() ai=() label

    # 1) Lo que falló
    for id in "${ACTIVE_IDS[@]}"; do
        [ "${ITEM_STATUS[$id]:-}" = failed ] && failed+=("${ITEM_LABEL[$id]}")
    done
    if [ "${#failed[@]}" -gt 0 ]; then
        add_manual_step "Reintentar lo que falló ($(join_by ', ' "${failed[@]}")): vuelve a ejecutar ${BOLD}./init.sh${RESET} (lo ya instalado se omite). El motivo está en el registro: ${LOG_FILE}"
    fi

    # 2) Reinicio pendiente del sistema
    if [ -f /var/run/reboot-required ] || { [ "$DISTRO_ID" = manjaro ] && [ ! -d "/usr/lib/modules/$(uname -r)" ]; }; then
        add_manual_step "${BOLD}Reinicia el equipo${RESET}: se actualizó el kernel o componentes del sistema."
    fi

    # 3) Modo USB
    if [ "$INSTALL_TARGET" = usb ]; then
        for id in usb-zram usb-noatime usb-tmp usb-psd; do
            item_new "$id" && { add_manual_step "${BOLD}Reinicia el equipo${RESET} para activar por completo las optimizaciones USB (zram, noatime, /tmp en RAM y profile-sync-daemon)."; break; }
        done
    fi

    # 4) Docker: el grupo solo se aplica en una sesión nueva
    if item_ok docker-sin-sudo && ! user_in_session_group docker; then
        add_manual_step "${BOLD}Cierra sesión y vuelve a entrar${RESET} (o ejecuta ${BOLD}newgrp docker${RESET}) para usar Docker sin sudo."
    fi

    # 5) Tailscale: autorizar el equipo
    if item_ok tailscale && ! tailscale status >/dev/null 2>&1; then
        add_manual_step "Conecta este equipo a tu red Tailscale: ${BOLD}sudo tailscale up${RESET} y autoriza la URL que muestra."
    fi

    # 6) Identidad de git
    if has_cmd git && [ -z "$(git config --global user.name 2>/dev/null)" ]; then
        add_manual_step "Configura tu identidad de git: ${BOLD}git config --global user.name \"Tu Nombre\"${RESET} y ${BOLD}git config --global user.email \"tu@correo\"${RESET}."
    fi

    # 7) Terminal nueva para cargar el PATH (NVM, pnpm, bun, cargo…)
    for id in nvm-node nodejs pnpm bun rust entorno-bash entorno-js zshrc; do
        item_new "$id" && { add_manual_step "Abre una ${BOLD}terminal nueva${RESET} (o ejecuta ${BOLD}exec $SHELL${RESET}) para cargar las rutas de Node, pnpm, bun y demás."; break; }
    done

    # 8) Iniciar sesión en CLIs de IA recién instaladas
    for id in claude-code gemini-cli codex opencode; do
        item_new "$id" && ai+=("${ITEM_LABEL[$id]%% *}")
    done
    [ "${#ai[@]}" -gt 0 ] && add_manual_step "Inicia sesión en las herramientas de IA nuevas ejecutando cada una una vez: ${BOLD}claude${RESET}, ${BOLD}gemini${RESET}, ${BOLD}codex${RESET}, ${BOLD}opencode${RESET} (las que hayas instalado)."
    item_new hermes && add_manual_step "Configura Hermes Agent: ${BOLD}hermes setup${RESET}."

    # 8b) GitHub CLI y Playwright
    item_new gh && add_manual_step "Inicia sesión en GitHub CLI: ${BOLD}gh auth login${RESET}."
    item_new playwright-cli && add_manual_step "Playwright CLI descarga su navegador la primera vez que lo usas; para dejarlo listo ya: ${BOLD}playwright-cli install-browser${RESET} (en Ubuntu añade ${BOLD}--with-deps${RESET} para las librerías del sistema)."

    # 8b2) Claude Desktop: Cowork usa una máquina virtual (QEMU/KVM) y necesita el grupo kvm
    if item_new claude-desktop && ! user_in_group_file kvm; then
        add_manual_step "Para usar ${BOLD}Cowork${RESET} en Claude Desktop: ${BOLD}sudo usermod -aG kvm \$USER${RESET} y vuelve a iniciar sesión (necesita la virtualización activada en la BIOS)."
    fi

    # 8b3) Espanso
    item_new espanso && add_manual_step "Prueba ${BOLD}Espanso${RESET}: escribe ${BOLD}:espanso${RESET} en cualquier aplicación. Tus atajos van en ${BOLD}~/.config/espanso/match/base.yml${RESET} (${BOLD}espanso edit${RESET}). En Wayland, tras actualizarlo repite: ${BOLD}sudo setcap \"cap_dac_override+p\" \$(which espanso)${RESET}."

    # 8b4) Status line de Claude Code: se ve al reabrir claude
    item_new claude-statusline && add_manual_step "La ${BOLD}status line de Claude Code${RESET} aparece al abrir ${BOLD}claude${RESET} (en una sesión ya abierta, tras el siguiente mensaje). Los límites de 5 h y semanal se muestran con una suscripción Pro/Max, tras la primera respuesta."

    # 8c) herdr App: herdr-app y hc quedan en ~/.local/bin
    item_new herdr-app && add_manual_step "Abre ${BOLD}Herdr${RESET} desde el menú de aplicaciones (o ${BOLD}herdr-app${RESET}); se mantiene actualizada sola."

    # 9) Flutter
    item_new flutter && add_manual_step "Verifica Flutter: ${BOLD}flutter doctor${RESET} (para Android: ${BOLD}flutter doctor --android-licenses${RESET})."

    # 10) Aplicaciones con cuenta
    for id in brave chrome vscode cursor antigravity claude-desktop whatsdesk wave; do
        if item_new "$id"; then label="${ITEM_LABEL[$id]}"; apps+=("${label%% (*}"); fi
    done
    [ "${#apps[@]}" -gt 0 ] && add_manual_step "Abre e inicia sesión / sincroniza en las aplicaciones nuevas: $(join_by ', ' "${apps[@]}")."
    return 0
}
register_post post_comun
