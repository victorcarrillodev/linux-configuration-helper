#!/usr/bin/env bash
# lib/menu.sh — Preguntas al usuario: sistema operativo, destino (Escritorio/USB) y confirmaciones.

[ -n "${MENU_LOADED:-}" ] && return 0
MENU_LOADED=1

DISTRO_ID="${DISTRO_ID:-}"          # ubuntu | manjaro
INSTALL_TARGET="${INSTALL_TARGET:-}" # escritorio | usb
EDITORS_SELECTED=""                  # ids elegidos: antigravity cursor vscode (nunca vacío)

# ---------------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------------
# ask_choice "texto" <defecto|""> <máximo> — resultado en $CHOICE
ask_choice() {
    local prompt="$1" def="$2" max="$3" ans
    while true; do
        printf '%s' "${BOLD}${prompt}${RESET} "
        if ! read -r ans; then
            echo
            if [ -z "$def" ]; then
                error "No hay entrada interactiva. Usa --sistema y --destino."
                exit 1
            fi
            ans=""
        fi
        [ -z "$ans" ] && ans="$def"
        if [[ "$ans" =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le "$max" ]; then
            CHOICE="$ans"
            return 0
        fi
        warn "Opción no válida. Escribe un número del 1 al ${max}."
    done
}

# ask_yes_no "texto" [S|N] — con --yes se acepta el valor por defecto
ask_yes_no() {
    local text="$1" def="${2:-N}" ans hint
    [ "$def" = "S" ] && hint="[S/n]" || hint="[s/N]"
    if [ "${ASSUME_YES:-0}" = 1 ]; then
        [ "$def" = "S" ]
        return
    fi
    while true; do
        printf '%s' "${BOLD}${text} ${hint}: ${RESET}"
        if ! read -r ans; then echo; ans=""; fi
        ans="${ans,,}"
        case "$ans" in
            s|si|sí|y|yes) return 0 ;;
            n|no) return 1 ;;
            "") [ "$def" = "S" ]; return ;;
        esac
        warn "Responde con 's' o 'n'."
    done
}

# ---------------------------------------------------------------------------
# Detección del entorno
# ---------------------------------------------------------------------------
# ubuntu | manjaro | "" (según /etc/os-release)
detect_distro() {
    local info id like
    info="$( ( . /etc/os-release 2>/dev/null; echo "${ID:-}|${ID_LIKE:-}" ) 2>/dev/null )"
    id="${info%%|*}"; like="${info#*|}"
    case " ${id} ${like} " in
        *" manjaro "*|*" arch "*)  echo manjaro ;;
        *" ubuntu "*|*" debian "*) echo ubuntu ;;
        *) echo "" ;;
    esac
}

# ¿El sistema raíz está en un disco USB?
detect_usb_root() {
    local src disk
    has_cmd findmnt && has_cmd lsblk && has_cmd udevadm || return 1
    src="$(findmnt -no SOURCE / 2>/dev/null | sed 's/\[.*//')"
    [ -b "$src" ] || return 1
    disk="$(lsblk -no PKNAME "$src" 2>/dev/null | head -1)"
    [ -n "$disk" ] || disk="$(basename "$src")"
    udevadm info --query=property --name="/dev/${disk}" 2>/dev/null | grep -q '^ID_BUS=usb'
}

distro_pkg_manager() {
    case "$1" in ubuntu) echo "apt" ;; manjaro) echo "pacman" ;; *) echo "?" ;; esac
}

distro_label() {
    case "$1" in
        ubuntu)  echo "Ubuntu (linux conf)" ;;
        manjaro) echo "Manjaro (manjaro conf)" ;;
        *)       echo "$1" ;;
    esac
}

# ---------------------------------------------------------------------------
# Menús
# ---------------------------------------------------------------------------
choose_distro() {
    local detected def="" hint="" label
    detected="$(detect_distro)"
    if [ -n "$DISTRO_ID" ]; then return 0; fi   # ya viene por --sistema

    case "$detected" in ubuntu) def=1 ;; manjaro) def=2 ;; esac
    if [ -n "$detected" ]; then
        label="$(distro_label "$detected")"
        hint="${DIM}(se detectó ${label}; Enter = ${def})${RESET}"
    fi

    printf '%s\n' "${BOLD}${WHITE}  PASO 1 · ¿Para qué sistema es esta configuración?${RESET}"
    echo
    printf '%s\n' "     ${CYAN}1)${RESET} Ubuntu    ${DIM}— linux conf   · apt, snap y repositorios externos${RESET}"
    printf '%s\n' "     ${CYAN}2)${RESET} Manjaro   ${DIM}— manjaro conf · pacman y AUR (yay)${RESET}"
    echo
    [ -n "$hint" ] && printf '     %s\n' "$hint"
    ask_choice "  Elige [1-2]:" "$def" 2
    case "$CHOICE" in 1) DISTRO_ID=ubuntu ;; 2) DISTRO_ID=manjaro ;; esac
    success "Sistema: $(distro_label "$DISTRO_ID")"
    echo
}

choose_target() {
    local def=1 hint=""
    if [ -n "$INSTALL_TARGET" ]; then return 0; fi   # ya viene por --destino

    if detect_usb_root; then
        def=2
        hint="${DIM}(el sistema actual parece estar en una USB; Enter = 2)${RESET}"
    fi

    printf '%s\n' "${BOLD}${WHITE}  PASO 2 · ¿Dónde vas a instalar?${RESET}"
    echo
    printf '%s\n' "     ${CYAN}1)${RESET} Escritorio  ${DIM}— PC o portátil con disco interno (sin optimizaciones USB)${RESET}"
    printf '%s\n' "     ${CYAN}2)${RESET} USB         ${DIM}— sistema portable: menos escrituras (zram, noatime, logs en RAM…)${RESET}"
    echo
    [ -n "$hint" ] && printf '     %s\n' "$hint"
    ask_choice "  Elige [1-2]:" "$def" 2
    case "$CHOICE" in 1) INSTALL_TARGET=escritorio ;; 2) INSTALL_TARGET=usb ;; esac
    success "Destino: ${INSTALL_TARGET}"
    echo
}

# parse_editor_choice <texto> — imprime los ids elegidos (o devuelve 1 si no hay ninguno válido)
# Acepta números sueltos, unidos o con comas: "1 3", "1,3", "13", "todos"…
parse_editor_choice() {
    local ans="${1,,}" out c d
    case "$ans" in
        *todos*|*todas*) printf '%s' "antigravity cursor vscode"; return 0 ;;
    esac
    local -a pick=()
    for ((c = 0; c < ${#ans}; c++)); do
        d="${ans:c:1}"
        case "$d" in
            ' '|',') continue ;;
            1|2|3) case ":${pick[*]:-}:" in *":$d:"*) ;; *) pick+=("$d") ;; esac ;;
            *) return 1 ;;
        esac
    done
    [ "${#pick[@]}" -gt 0 ] || return 1
    for d in "${pick[@]}"; do
        case "$d" in 1) out+='antigravity ' ;; 2) out+='cursor ' ;; 3) out+='vscode ' ;; esac
    done
    printf '%s' "${out% }"
}

# Paso 3 del menú: qué editores de código instalar (uno o varios; nunca 0)
choose_editors() {
    local ans
    if [ -n "$EDITORS_SELECTED" ]; then return 0; fi   # ya viene elegido
    if [ "$ASSUME_YES" = 1 ]; then
        EDITORS_SELECTED="antigravity cursor vscode"
        success "Editores (por --yes): $(editors_pretty_list antigravity cursor vscode)"
        echo
        return 0
    fi

    printf '%s\n' "${BOLD}${WHITE}  PASO 3 · ¿Qué editores de código quieres instalar?${RESET}"
    echo
    printf '%s\n' "     ${CYAN}1)${RESET} Antigravity IDE  ${DIM}— IDE con IA de Google${RESET}"
    printf '%s\n' "     ${CYAN}2)${RESET} Cursor           ${DIM}— editor con IA (basado en VS Code)${RESET}"
    printf '%s\n' "     ${CYAN}3)${RESET} VS Code          ${DIM}— Visual Studio Code de Microsoft${RESET}"
    echo
    printf '%s\n' "     ${DIM}Puedes elegir varios: p. ej. 1 3 · 1,3 · 13 · o «todos». Debe quedar al menos uno.${RESET}"
    while true; do
        printf '%s' "  ${BOLD}Elige [1-3]: ${RESET}"
        if ! read -r ans; then
            echo
            error "No hay entrada interactiva. Usa --yes para instalar los tres editores."
            exit 1
        fi
        if [ -z "${ans//[ ,]/}" ]; then
            warn "Debes elegir al menos un editor."
            continue
        fi
        if EDITORS_SELECTED="$(parse_editor_choice "$ans")" && [ -n "$EDITORS_SELECTED" ]; then
            break
        fi
        warn "Opción no válida. Escribe números del 1 al 3 (p. ej. 1 3), o «todos»."
    done
    success "Editores elegidos: $(editors_pretty_list $EDITORS_SELECTED)"
    echo
}

# Comprueba que el gestor de paquetes corresponde a la distro elegida
validate_distro_tools() {
    local ok=1
    case "$DISTRO_ID" in
        ubuntu)  has_cmd apt-get && has_cmd dpkg || ok=0 ;;
        manjaro) has_cmd pacman || ok=0 ;;
    esac
    [ "$ok" = 1 ] && return 0
    if [ "${DRY_RUN:-0}" = 1 ]; then
        warn "Este equipo no tiene el gestor de paquetes de $(distro_label "$DISTRO_ID") (se sigue por ser una simulación)."
        return 0
    fi
    error "Elegiste $(distro_label "$DISTRO_ID"), pero este equipo no tiene su gestor de paquetes ($(distro_pkg_manager "$DISTRO_ID"))."
    return 1
}
