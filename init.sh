#!/usr/bin/env bash
# =============================================================================
#  LINUX CONF — instalador unificado
#  Ubuntu (linux conf) · Manjaro (manjaro conf) — Escritorio o USB
#
#  Uso:  ./init.sh            (menú interactivo)
#        ./init.sh --ayuda    (todas las opciones)
# =============================================================================
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

# shellcheck source=lib/ui.sh
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/checks.sh"
source "${SCRIPT_DIR}/lib/shellrc.sh"
source "${SCRIPT_DIR}/lib/core.sh"
source "${SCRIPT_DIR}/lib/menu.sh"

ONLY=()
SKIP=()
PURGE_IDS=()
LIST_ONLY=0
DISTRO_FROM_FLAG=0

print_help() {
    cat <<EOF
Uso: ./init.sh [OPCIONES]

Sin opciones se muestra un menú que pregunta:
  1) el sistema:  Ubuntu (linux conf)  o  Manjaro (manjaro conf)
  2) el destino:  Escritorio  o  USB (portable, con optimizaciones)
  3) los editores de código: Antigravity IDE, Cursor y/o VS Code (al menos uno)

Opciones:
  --sistema ubuntu|manjaro     Elige el sistema sin preguntar
  --destino escritorio|usb     Elige el destino sin preguntar
  --solo <n|id>                Ejecuta solo ese módulo (ej: 03) o ítem (ej: docker). Repetible
  --omitir <n|id>              Salta ese módulo o ítem. Repetible
  --solo-usb                   Solo aplica las optimizaciones para USB y termina
  --listar                     Muestra los módulos e ítems del sistema elegido
  --simular                    No instala nada: muestra lo que haría
  --sin-pausa                  No espera 2 s entre instalaciones
  --yes, -y                    Acepta las respuestas por defecto (editores: los tres;
                               nunca borra el instalador ni editores ya instalados)
  --ayuda, -h                  Muestra esta ayuda

Ejemplos:
  ./init.sh                                   # menú interactivo
  ./init.sh --sistema manjaro --destino usb   # sin preguntas
  ./init.sh --solo docker --solo 06           # solo Docker y el módulo 06
  ./init.sh --simular                         # ver el plan sin tocar nada
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --ayuda|--help|-h) print_help; exit 0 ;;
            --sistema|--distro)
                shift; DISTRO_ID="${1:-}"; DISTRO_FROM_FLAG=1
                case "$DISTRO_ID" in ubuntu|manjaro) ;; *) error "--sistema debe ser ubuntu o manjaro"; exit 1 ;; esac ;;
            --destino)
                shift; INSTALL_TARGET="${1:-}"
                case "$INSTALL_TARGET" in
                    escritorio|desktop) INSTALL_TARGET=escritorio ;;
                    usb) ;;
                    *) error "--destino debe ser escritorio o usb"; exit 1 ;;
                esac ;;
            --solo|--only)   shift; ONLY+=("${1:-}") ;;
            --omitir|--skip) shift; SKIP+=("${1:-}") ;;
            --solo-usb|--only-optimize) INSTALL_TARGET=usb; ONLY+=("00") ;;
            --listar|--list|-l) LIST_ONLY=1 ;;
            --simular|--dry-run) DRY_RUN=1 ;;
            --sin-pausa) PAUSE_SECONDS=0 ;;
            --yes|-y|--si) ASSUME_YES=1 ;;
            *) error "Opción desconocida: $1"; echo; print_help; exit 1 ;;
        esac
        shift
    done
}

in_list() {
    local needle="$1" x
    shift
    for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
    return 1
}

# "3" → "03" para que --solo 3 y --solo 03 sean lo mismo
normalize_sections() {
    local -n arr="$1"
    local i
    for i in "${!arr[@]}"; do
        [[ "${arr[$i]}" =~ ^[0-9]$ ]] && arr[$i]="0${arr[$i]}"
    done
}

load_catalog() {
    local f
    # shellcheck disable=SC1090
    source "${SCRIPT_DIR}/${DISTRO_ID}/distro.sh"
    for f in "${SCRIPT_DIR}"/comun/[0-9]*.sh "${SCRIPT_DIR}/${DISTRO_ID}"/[0-9]*.sh; do
        # shellcheck disable=SC1090
        [ -f "$f" ] && source "$f"
    done
}

build_active() {
    local id sec
    ACTIVE_IDS=()
    for id in "${ITEM_IDS[@]}"; do
        sec="${ITEM_SECTION[$id]}"
        if [ "${#ONLY[@]}" -gt 0 ] && ! in_list "$id" "${ONLY[@]}" && ! in_list "$sec" "${ONLY[@]}"; then continue; fi
        if [ "${#SKIP[@]}" -gt 0 ] && { in_list "$id" "${SKIP[@]}" || in_list "$sec" "${SKIP[@]}"; }; then continue; fi
        # Editores: solo los elegidos en el PASO 3 quedan en el plan
        if in_list "$id" "${EDITOR_ITEMS[@]}" && ! in_list "$id" ${EDITORS_SELECTED:-}; then continue; fi
        ACTIVE_IDS+=("$id")
    done
}

# ¿El plan incluye módulos de EDITORES? (--solo/--omitir pueden excluirlos; si no, no se pregunta)
editors_needed_for_plan() {
    if [ "${#ONLY[@]}" -gt 0 ]; then
        in_list "05" "${ONLY[@]}" || in_list antigravity "${ONLY[@]}" \
            || in_list cursor "${ONLY[@]}" || in_list vscode "${ONLY[@]}" || return 1
    fi
    if [ "${#SKIP[@]}" -gt 0 ]; then
        if in_list "05" "${SKIP[@]}"; then return 1; fi
        if in_list antigravity "${SKIP[@]}" && in_list cursor "${SKIP[@]}" && in_list vscode "${SKIP[@]}"; then return 1; fi
    fi
    return 0
}

# Detecta editores instalados que NO se eligieron y pregunta: conservarlos o desinstalarlos.
# Si se desinstalan, registra ítems \"purga-<id>\" que entran al plan antes de la limpieza.
resolve_unselected_editors() {
    local e
    for e in "${EDITOR_ITEMS[@]}"; do
        [ -n "${ITEM_LABEL[$e]:-}" ] || continue          # esta distro no registra ese editor
        if in_list "$e" ${EDITORS_SELECTED:-}; then continue; fi
        if in_list "$e" "${SKIP[@]}"; then continue; fi   # el usuario pidió omitirlo: no se toca
        editor_installed "$e" || continue                 # no está instalado: nada que preguntar
        if [ "$DRY_RUN" = 1 ]; then
            info "[simulación] «${ITEM_LABEL[$e]}» está instalado y no lo elegiste: aquí se preguntaría si conservarlo."
            continue
        fi
        echo
        warn "«${ITEM_LABEL[$e]}» está instalado, pero no lo elegiste."
        if ask_yes_no "¿Conservarlo además de los elegidos?" S; then
            success "Se conserva también ${ITEM_LABEL[$e]}."
        else
            register_purge_item "$e" "${ITEM_SECTION[${ACTIVE_IDS[-1]}]:-}"
            PURGE_IDS+=("purga-$e")
            info "Se desinstalará ${ITEM_LABEL[$e]} junto con las demás tareas."
        fi
    done
    insert_purges_into_plan
}

# Coloca los ítems de desinstalación antes de la sección de LIMPIEZA (si hay)
insert_purges_into_plan() {
    [ "${#PURGE_IDS[@]}" -gt 0 ] || return 0
    local i idx="${#ACTIVE_IDS[@]}" secname
    for i in "${!ACTIVE_IDS[@]}"; do
        secname="${SECTION_NAME[${ITEM_SECTION[${ACTIVE_IDS[$i]}]}]:-}"
        if [[ "$secname" == *LIMPIEZA* ]]; then idx="$i"; break; fi
    done
    ACTIVE_IDS=( "${ACTIVE_IDS[@]:0:$idx}" "${PURGE_IDS[@]}" "${ACTIVE_IDS[@]:$idx}" )
}

list_catalog() {
    local sec id
    printf '%s\n' "${BOLD}Sistema: $(distro_label "$DISTRO_ID") · destino: ${INSTALL_TARGET}${RESET}"
    [ -n "$EDITORS_SELECTED" ] && printf '%s\n' "${BOLD}Editores: ${RESET}$(editors_pretty_list $EDITORS_SELECTED)"
    echo
    for sec in "${SECTION_IDS[@]}"; do
        printf '%s\n' "${BOLD}${WHITE}${sec} · ${SECTION_NAME[$sec]}${RESET} ${DIM}— ${SECTION_DESC[$sec]}${RESET}"
        for id in "${ITEM_IDS[@]}"; do
            [ "${ITEM_SECTION[$id]}" = "$sec" ] && printf '     %-22s %s\n' "$id" "${ITEM_LABEL[$id]}"
        done
        echo
    done
}

on_interrupt() {
    echo
    warn "Interrumpido por el usuario. Puedes volver a ejecutar ./init.sh: lo ya instalado se omite."
    exit 130
}

main() {
    parse_args "$@"
    normalize_sections ONLY
    normalize_sections SKIP
    USER="${USER:-$(id -un)}"
    export USER

    if [ "$(id -u)" -eq 0 ]; then
        error "No ejecutes este script como root ni con 'sudo ./init.sh'."
        echo "  Ejecútalo con tu usuario normal: ${BOLD}./init.sh${RESET}"
        echo "  (pedirá la contraseña de sudo cuando haga falta; yay/AUR, NVM y Oh My Zsh fallan como root)."
        exit 1
    fi

    if [ "$LIST_ONLY" = 1 ]; then
        [ -z "$DISTRO_ID" ] && DISTRO_ID="$(detect_distro)"
        [ -z "$DISTRO_ID" ] && DISTRO_ID=ubuntu
        [ -z "$INSTALL_TARGET" ] && INSTALL_TARGET=escritorio
        load_catalog
        list_catalog
        exit 0
    fi

    show_banner
    # Pregunta qué distro configurar; si no corresponde a este equipo, vuelve a preguntar
    while true; do
        choose_distro
        validate_distro_tools && break
        if [ "$DISTRO_FROM_FLAG" = 1 ]; then
            error "Corrige la opción --sistema."
            exit 1
        fi
        warn "Elige otro sistema."
        echo
        DISTRO_ID=""
    done
    choose_target
    if editors_needed_for_plan; then choose_editors; else EDITORS_SELECTED=""; fi

    load_catalog
    build_active
    if [ "${#ACTIVE_IDS[@]}" -eq 0 ]; then
        warn "Con las opciones indicadas no hay nada que ejecutar. Usa --listar para ver los módulos."
        exit 0
    fi

    # Editores instalados que no se eligieron: preguntar si se conservan o se desinstalan
    if editors_needed_for_plan; then resolve_unselected_editors; fi

    init_log
    trap stop_sudo EXIT
    trap on_interrupt INT TERM

    hr '─'
    printf '%s\n' "  ${BOLD}Sistema:${RESET} $(distro_label "$DISTRO_ID")    ${BOLD}Destino:${RESET} ${INSTALL_TARGET}    ${BOLD}Ítems:${RESET} ${#ACTIVE_IDS[@]}"
    [ "$DRY_RUN" = 1 ] && printf '%s\n' "  ${YELLOW}${BOLD}MODO SIMULACIÓN: no se instalará nada.${RESET}"
    hr '─'

    refresh_env
    audit_items          # solo lectura: no hace falta sudo para ver qué hay y qué falta
    echo
    if ! ask_yes_no "¿Continuar con la instalación?" S; then
        info "Cancelado. No se ha modificado nada."
        exit 0
    fi

    start_sudo
    if [ "$DRY_RUN" != 1 ] && ! net_ok; then
        warn "No hay conexión a internet."
        wait_for_network 30 || { error "Sin internet no se puede instalar. Conéctate y vuelve a ejecutar."; exit 1; }
    fi

    execute_plan
    print_summary
    local rc=$?
    offer_delete_installer
    exit "$rc"
}

main "$@"
