#!/usr/bin/env bash
# lib/checklist.sh — Lista interactiva de casillas en la terminal (bash puro, sin dependencias).
#
#   ↑/↓ o k/j     mover el cursor          RePág/AvPág  saltar una página
#   Espacio       marcar / desmarcar       Inicio/Fin   primero / último
#   a             marcar todo              n            desmarcar todo
#   Enter         confirmar                q / Esc      cancelar
#
# Las filas de GRUPO (cabeceras) también se marcan con Espacio: marcan o desmarcan todo su grupo.
#
# Uso:
#   cl_reset
#   cl_add_header "03 · DESARROLLO" "Node, Rust…"
#   cl_add_item nodejs "Node.js LTS" 1 "ya instalado" "Entorno de ejecución de JavaScript"
#   CL_HOOK=mi_funcion        # opcional: se llama como «mi_funcion <índice> <0|1>» al cambiar un ítem
#   checklist "Título" "Subtítulo" <mínimo>  || echo "cancelado"
#   cl_selected               # imprime las claves marcadas, separadas por espacios

[ -n "${CHECKLIST_LOADED:-}" ] && return 0
CHECKLIST_LOADED=1

CL_KEYS=()   # clave de cada fila ("" en las cabeceras)
CL_TEXT=()   # texto visible
CL_HINT=()   # nota tenue a la derecha
CL_ON=()     # 1 marcado · 0 sin marcar (en cabeceras no se usa)
CL_HDR=()    # 0 ítem · 1 cabecera de sección · 2 separador (línea en blanco, el cursor lo salta)
CL_DESC=()   # descripción larga (se muestra en el pie cuando el cursor está en la fila)
CL_MSG=""    # mensaje informativo que se muestra en el pie (lo pueden fijar los ganchos)
CL_HOOK="${CL_HOOK:-}"
declare -A CL_INDEX   # clave → índice de fila
CL_SEC=()    # índice de la cabecera a la que pertenece cada fila (-1 si ninguna)
CL_SCOLOR=() # color de cada cabecera (por índice de fila)

# Paleta de colores de sección: se reparte en orden, uno distinto por sección.
# 256 colores: azul, rosa, dorado, verde, naranja, violeta, turquesa, salmón, lima, celeste
_CL_PAL256=(39 213 220 84 208 141 51 203 118 75)

cl_reset() { CL_KEYS=(); CL_TEXT=(); CL_HINT=(); CL_ON=(); CL_HDR=(); CL_DESC=(); CL_MSG=""; CL_INDEX=(); }

# _cl_push <clave> <texto> <on> <nota> <tipo> <descripción>
_cl_push() { CL_KEYS+=("$1"); CL_TEXT+=("$2"); CL_ON+=("$3"); CL_HINT+=("$4"); CL_HDR+=("$5"); CL_DESC+=("$6"); }

# cl_add_header <texto> [descripción] — a partir de la segunda sección deja una línea de separación
cl_add_header() {
    [ "${#CL_KEYS[@]}" -gt 0 ] && _cl_push "" "" 0 "" 2 ""
    _cl_push "" "$1" 0 "" 1 "${2:-}"
}

# cl_add_item <clave> <texto> [0|1] [nota] [descripción]
cl_add_item() {
    CL_INDEX[$1]="${#CL_KEYS[@]}"
    _cl_push "$1" "$2" "${3:-1}" "${4:-}" 0 "${5:-}"
}

# ¿Se puede mostrar la lista? (entrada y salida son una terminal)
cl_interactive() { [ -t 0 ] && [ -t 1 ]; }

cl_selected() {
    local i out=""
    for i in "${!CL_KEYS[@]}"; do
        [ "${CL_HDR[$i]}" = 0 ] && [ "${CL_ON[$i]}" = 1 ] && out+="${CL_KEYS[$i]} "
    done
    printf '%s' "${out% }"
}

cl_count() {   # cl_count → "<marcados> <total>"
    local i on=0 tot=0
    for i in "${!CL_KEYS[@]}"; do
        [ "${CL_HDR[$i]}" = 0 ] || continue
        tot=$((tot + 1)); [ "${CL_ON[$i]}" = 1 ] && on=$((on + 1))
    done
    printf '%s %s' "$on" "$tot"
}

# cl_set <índice> <0|1> — cambia un ítem y avisa al gancho (solo si de verdad cambia)
cl_set() {
    local i="$1" v="$2"
    [ "${CL_HDR[$i]}" = 0 ] || return 0
    [ "${CL_ON[$i]}" = "$v" ] && return 0
    CL_ON[$i]="$v"
    if [ -n "$CL_HOOK" ] && declare -F "$CL_HOOK" >/dev/null; then "$CL_HOOK" "$i" "$v"; fi
    return 0
}

# _cl_group <índice-cabecera> → fija _CL_A.._CL_B (ítems del grupo) y _CL_ON/_CL_TOT
_cl_group() {
    local h="$1" i n="${#CL_KEYS[@]}"
    _CL_A=$((h + 1)); _CL_B="$h"; _CL_ON=0; _CL_TOT=0
    for ((i = h + 1; i < n; i++)); do
        [ "${CL_HDR[$i]}" = 0 ] || break
        _CL_B="$i"; _CL_TOT=$((_CL_TOT + 1))
        [ "${CL_ON[$i]}" = 1 ] && _CL_ON=$((_CL_ON + 1))
    done
}

_cl_toggle() {
    local i="$1" j v
    if [ "${CL_HDR[$i]}" = 1 ]; then
        _cl_group "$i"
        [ "$_CL_TOT" -gt 0 ] || return 0
        # Todo marcado → desmarcar el grupo; si no → marcarlo entero
        [ "$_CL_ON" -eq "$_CL_TOT" ] && v=0 || v=1
        for ((j = _CL_A; j <= _CL_B; j++)); do cl_set "$j" "$v"; done
    else
        [ "${CL_ON[$i]}" = 1 ] && cl_set "$i" 0 || cl_set "$i" 1
    fi
}

_cl_all() {
    local i
    for i in "${!CL_KEYS[@]}"; do [ "${CL_HDR[$i]}" = 0 ] && CL_ON[$i]="$1"; done
}

# _cl_fit <texto> <ancho> — recorta con «…» si no cabe
_cl_fit() {
    local s="$1" w="$2"
    [ "$w" -lt 1 ] && { printf ''; return; }
    if [ "${#s}" -gt "$w" ]; then printf '%s…' "${s:0:$((w - 1))}"; else printf '%s' "$s"; fi
}

# _cl_wrap2 <texto> <ancho> — parte el texto en 2 líneas como máximo (por palabras) → _CL_W1/_CL_W2
_cl_wrap2() {
    local s="$1" w="$2" cut
    _CL_W1="$s"; _CL_W2=""
    [ "${#s}" -le "$w" ] && return 0
    cut="${s:0:$w}"; cut="${cut% *}"
    [ "${#cut}" -lt $((w / 2)) ] && cut="${s:0:$w}"
    _CL_W1="$cut"
    _CL_W2="$(_cl_fit "${s:${#cut}}" "$w")"; _CL_W2="${_CL_W2# }"
}

# _cl_color <n> — color en negrita para la sección número n (0, 1, 2…)
_cl_color() {
    local n="$1" basic=("$CYAN" "$MAGENTA" "$YELLOW" "$GREEN" "$BLUE" "$RED")
    [ -z "$RESET" ] && { printf ''; return; }
    case "${_UI_GRAD_MODE:-basic}" in
        tc|256) printf '\033[1;38;5;%sm' "${_CL_PAL256[$((n % ${#_CL_PAL256[@]}))]}" ;;
        *)      printf '%s%s' "$BOLD" "${basic[$((n % ${#basic[@]}))]}" ;;
    esac
}

# Calcula a qué sección pertenece cada fila y el color de cada sección
_cl_prepare() {
    local i h=-1 s=0
    CL_SEC=(); CL_SCOLOR=()
    for i in "${!CL_KEYS[@]}"; do
        if [ "${CL_HDR[$i]}" = 1 ]; then
            h="$i"; CL_SCOLOR[$i]="$(_cl_color "$s")"; s=$((s + 1))
        elif [ "${CL_HDR[$i]}" = 2 ]; then
            h=-1
        fi
        CL_SEC[$i]="$h"
    done
}

# _cl_move <paso> — mueve el cursor saltando los separadores
_cl_move() {
    local step="$1" n="${#CL_KEYS[@]}" c="$_cl_cur" dir=1
    [ "$step" -lt 0 ] && dir=-1
    c=$((c + step))
    [ "$c" -lt 0 ] && c=0
    [ "$c" -ge "$n" ] && c=$((n - 1))
    while [ "${CL_HDR[$c]}" = 2 ]; do
        c=$((c + dir))
        if [ "$c" -lt 0 ] || [ "$c" -ge "$n" ]; then c="$_cl_cur"; break; fi
    done
    _cl_cur="$c"
}

_cl_size() {
    local s
    s="$(stty size 2>/dev/null)"
    _CL_LINES="${s% *}"; _CL_COLS="${s#* }"
    case "$_CL_LINES" in ''|*[!0-9]*) _CL_LINES=24 ;; esac
    case "$_CL_COLS"  in ''|*[!0-9]*) _CL_COLS=80 ;; esac
    [ "$_CL_LINES" -lt 10 ] && _CL_LINES=10
    [ "$_CL_COLS" -lt 30 ] && _CL_COLS=30
}

_cl_draw() {
    local title="$1" sub="$2" n="${#CL_KEYS[@]}" i vh row text hint w mark ptr col on tot more help h scol cnt rule line under bar
    _cl_size
    vh=$((_CL_LINES - 8))
    [ "$vh" -lt 3 ] && vh=3
    [ "$_cl_cur" -lt "$_cl_top" ] && _cl_top="$_cl_cur"
    if [ "$_cl_cur" -eq "$_cl_top" ] && [ "$_cl_top" -gt 0 ] && [ "${CL_HDR[$((_cl_top - 1))]}" = 2 ]; then
        _cl_top=$((_cl_top - 1))
    fi
    [ "$_cl_cur" -ge $((_cl_top + vh)) ] && _cl_top=$((_cl_cur - vh + 1))
    _CL_VH="$vh"

    local buf=$'\033[H'
    buf+="${BOLD}${WHITE}  $(_cl_fit "$title" $((_CL_COLS - 3)))${RESET}"$'\033[K\n'
    buf+="${DIM}  $(_cl_fit "$sub" $((_CL_COLS - 3)))${RESET}"$'\033[K\n\033[K\n'

    for ((row = 0; row < vh; row++)); do
        i=$((_cl_top + row))
        if [ "$i" -ge "$n" ]; then buf+=$'\033[K\n'; continue; fi
        # Separador entre secciones: línea vacía
        if [ "${CL_HDR[$i]}" = 2 ]; then buf+=$'\033[K\n'; continue; fi
        if [ "$i" -eq "$_cl_cur" ]; then ptr="${CYAN}${BOLD}❯${RESET}"; col="${CYAN}${BOLD}"; else ptr=" "; col=""; fi
        h="${CL_SEC[$i]:--1}"
        scol=""; [ "$h" -ge 0 ] && scol="${CL_SCOLOR[$h]}"

        if [ "${CL_HDR[$i]}" = 1 ]; then
            # Cabecera: casilla del grupo + título en negrita y color propio + regla hasta el borde
            _cl_group "$i"
            if   [ "$_CL_ON" -eq 0 ];          then mark="${DIM}[ ]${RESET}"
            elif [ "$_CL_ON" -eq "$_CL_TOT" ]; then mark="${GREEN}[✔]${RESET}"
            else                                    mark="${YELLOW}[~]${RESET}"; fi
            text="$(_cl_fit "■ ${CL_TEXT[$i]}" $((_CL_COLS - 18)))"
            cnt=" ${_CL_ON}/${_CL_TOT} "
            rule=$((_CL_COLS - 9 - ${#text} - ${#cnt}))
            [ "$rule" -lt 0 ] && rule=0
            printf -v line '%*s' "$rule" ''
            under=""; [ "$i" -eq "$_cl_cur" ] && [ -n "$RESET" ] && under=$'\033[4m'
            buf+=" ${ptr} ${mark} ${BOLD}${scol}${under}${text}${RESET}${scol}${cnt}${line// /━}${RESET}"$'\033[K\n'
        else
            # Ítem: barra del color de su sección, para ver a qué bloque pertenece
            [ "${CL_ON[$i]}" = 1 ] && mark="${GREEN}[✔]${RESET}" || mark="${DIM}[ ]${RESET}"
            bar="  "; [ "$h" -ge 0 ] && bar="${scol}┃${RESET} "
            w=$((_CL_COLS - 12))
            text="$(_cl_fit "${CL_TEXT[$i]}" "$w")"
            hint=""
            if [ -n "${CL_HINT[$i]}" ] && [ $((w - ${#text} - 3)) -gt 6 ]; then
                hint="  ${DIM}$(_cl_fit "${CL_HINT[$i]}" $((w - ${#text} - 3)))${RESET}"
            fi
            buf+=" ${ptr}   ${bar}${mark} ${col}${text}${RESET}${hint}"$'\033[K\n'
        fi
    done

    read -r on tot <<< "$(cl_count)"
    more=""
    [ "$_cl_top" -gt 0 ] && more+="↑ hay más arriba  "
    [ $((_cl_top + vh)) -lt "$n" ] && more+="↓ hay más abajo"
    buf+="${DIM}  ${more}${RESET}"$'\033[K\n'
    # Descripción de la fila actual (hasta 2 líneas)
    _cl_wrap2 "${CL_DESC[$_cl_cur]:-}" $((_CL_COLS - 6))
    if [ -n "$_CL_W1" ]; then
        buf+="  ${MAGENTA}ℹ${RESET} ${_CL_W1}"$'\033[K\n'"    ${_CL_W2}"$'\033[K\n'
    else
        buf+=$'\033[K\n\033[K\n'
    fi
    if [ -n "$CL_MSG" ]; then
        buf+="  ${BOLD}${on}/${tot}${RESET} marcados  ${YELLOW}$(_cl_fit "$CL_MSG" $((_CL_COLS - 20)))${RESET}"$'\033[K\n'
    else
        buf+="  ${BOLD}${on}/${tot}${RESET} marcados"$'\033[K\n'
    fi
    if [ "$_CL_COLS" -ge 100 ]; then
        help="↑/↓ mover · Espacio marcar/desmarcar · a todo · n nada · Enter confirmar · q salir"
    else
        help="↑↓ mover · Espacio marcar · a/n todo/nada · Enter ok · q salir"
    fi
    buf+="${CYAN}  $(_cl_fit "$help" $((_CL_COLS - 3)))${RESET}"$'\033[K\033[J'
    printf '%s' "$buf"
}

_cl_restore() {
    printf '\033[?25h\033[?1049l'
    [ -n "${_CL_STTY:-}" ] && stty "$_CL_STTY" 2>/dev/null
    _CL_STTY=""
}

# checklist <título> <subtítulo> [mínimo] — 0 confirmado · 1 cancelado
checklist() {
    local title="$1" sub="$2" min="${3:-0}" n="${#CL_KEYS[@]}" key k2 k3 on tot rc
    _cl_cur=0; _cl_top=0; CL_MSG=""
    [ "$n" -gt 0 ] || return 0
    _cl_prepare

    _CL_STTY="$(stty -g 2>/dev/null)"
    stty -echo 2>/dev/null
    printf '\033[?1049h\033[?25l\033[H\033[2J'       # pantalla alternativa + cursor oculto
    trap '_cl_restore; echo; warn "Interrumpido por el usuario."; exit 130' INT TERM
    trap '_cl_draw "$title" "$sub"' WINCH

    while true; do
        _cl_draw "$title" "$sub"
        if ! IFS= read -rsn1 key; then rc=1; break; fi
        CL_MSG=""
        if [ "$key" = $'\e' ]; then
            k2=""; IFS= read -rsn1 -t 0.05 k2
            if [ "$k2" = "[" ] || [ "$k2" = "O" ]; then
                k3=""; IFS= read -rsn1 -t 0.05 k3
                case "$k3" in
                    A) key=UP ;; B) key=DOWN ;; H) key=HOME ;; F) key=END ;;
                    5) IFS= read -rsn1 -t 0.05 _; key=PGUP ;;
                    6) IFS= read -rsn1 -t 0.05 _; key=PGDN ;;
                    1|7) IFS= read -rsn1 -t 0.05 _; key=HOME ;;
                    4|8) IFS= read -rsn1 -t 0.05 _; key=END ;;
                    *) key=NOOP ;;
                esac
            elif [ -z "$k2" ]; then
                key=ESC
            else
                key=NOOP
            fi
        fi
        case "$key" in
            UP|k|K)   _cl_move -1 ;;
            DOWN|j|J) _cl_move 1 ;;
            PGUP)     _cl_move "-$_CL_VH" ;;
            PGDN)     _cl_move "$_CL_VH" ;;
            HOME|g)   _cl_move "-$n" ;;
            END|G)    _cl_move "$n" ;;
            " ")      _cl_toggle "$_cl_cur" ;;
            a|A)      _cl_all 1; CL_MSG="Todo marcado." ;;
            n|N)      _cl_all 0; CL_MSG="Todo desmarcado." ;;
            "")       read -r on tot <<< "$(cl_count)"
                      if [ "$on" -lt "$min" ]; then
                          CL_MSG="Debes marcar al menos ${min}."
                      else
                          rc=0; break
                      fi ;;
            q|Q|ESC)  rc=1; break ;;
        esac
    done

    trap - INT TERM WINCH
    _cl_restore
    return "$rc"
}
