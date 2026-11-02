#!/usr/bin/env bash
# lib/ui.sh — Interfaz: colores, banner, títulos grandes, mensajes y pausas.

[ -n "${UI_LOADED:-}" ] && return 0
UI_LOADED=1

# Colores solo si la salida es una terminal (y NO_COLOR no está definido)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
    RED=$'\033[1;31m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'
    BLUE=$'\033[1;34m'; MAGENTA=$'\033[1;35m'; CYAN=$'\033[1;36m'; WHITE=$'\033[1;37m'
    BG_BLUE=$'\033[44m'; BG_GREEN=$'\033[42m'
else
    BOLD=''; DIM=''; RESET=''; RED=''; GREEN=''; YELLOW=''
    BLUE=''; MAGENTA=''; CYAN=''; WHITE=''; BG_BLUE=''; BG_GREEN=''
fi

PAUSE_SECONDS="${PAUSE_SECONDS:-2}"

# ---------------------------------------------------------------------------
# Degradado naranja → azul (TrueColor, con respaldos de 256 colores y básicos)
# ---------------------------------------------------------------------------
_G_R1=255; _G_G1=146; _G_B1=49     # naranja
_G_R2=64;  _G_G2=106; _G_B2=255    # azul
_GRAD_N=24

# Construye la escala de colores (interpolación lineal en RGB)
ui_build_gradient() {
    local n="${1:-$_GRAD_N}" i t r g b
    _GRAD_STOPS=()
    [ "$n" -lt 2 ] && n=2
    for ((i = 0; i < n; i++)); do
        t=$(( (i * 255) / (n - 1) ))
        r=$(( _G_R1 + (t * (_G_R2 - _G_R1) + 127) / 255 ))
        g=$(( _G_G1 + (t * (_G_G2 - _G_G1) + 127) / 255 ))
        b=$(( _G_B1 + (t * (_G_B2 - _G_B1) + 127) / 255 ))
        _GRAD_STOPS+=($'\033[38;2;'"${r};${g};${b}"'m')
    done
    _GRAD_N="$n"
}

# Anclas para terminales que no anuncian truecolor
readonly -a _GRAD_256=( '208' '205' '198' '129' '57' '33' )
readonly -a _GRAD_BASIC=( "$YELLOW" "$RED" "$MAGENTA" "$MAGENTA" "$CYAN" "$BLUE" )

# Escala de colores precalculada
ui_build_gradient

# _UI_GRAD_MODE: tc | 256 | basic | none (se fija al cargar, según la terminal)
_ui_gradient_mode() {
    if [ -z "$RESET" ]; then printf 'none'; return; fi
    case "${COLORTERM:-}" in *truecolor*|*24bit*) printf 'tc'; return ;; esac
    case "${TERM:-}"     in *truecolor*|*direct*) printf 'tc'; return ;; esac
    case "${COLORTERM:-}${TERM:-}" in *256*|*256color*) printf '256'; return ;; esac
    printf 'basic'
}
_UI_GRAD_MODE="$(_ui_gradient_mode)"

# _grad_at <permil 0..1000> — color del degradado en ese punto según el modo
_grad_at() {
    local pm="$1" n i a
    (( pm < 0 )) && pm=0; (( pm > 1000 )) && pm=1000
    case "$_UI_GRAD_MODE" in
        tc)
            n="${#_GRAD_STOPS[@]}"; (( n < 2 )) && n=2
            i=$(( (pm * (n - 1) + 500) / 1000 ))
            (( i >= n )) && i=$(( n - 1 ))
            printf '%s' "${_GRAD_STOPS[i]}"
            ;;
        256)
            a="${#_GRAD_256[@]}"
            i=$(( (pm * (a - 1) + 500) / 1000 ))
            (( i >= a )) && i=$(( a - 1 ))
            printf $'\033[38;5;%sm' "${_GRAD_256[i]}"
            ;;
        basic)
            a="${#_GRAD_BASIC[@]}"
            i=$(( (pm * (a - 1) + 500) / 1000 ))
            (( i >= a )) && i=$(( a - 1 ))
            printf '%s' "${_GRAD_BASIC[i]}"
            ;;
        *) printf '' ;;
    esac
}

# Ancho real de la terminal (sin recortar), con 80 como valor seguro.
ui_real_cols() {
    local c="${COLUMNS:-}"
    if [ -z "$c" ] || [ "$c" = 0 ]; then
        c="$(tput cols 2>/dev/null || true)"
    fi
    case "$c" in ''|*[!0-9]*) c=80 ;; esac
    [ "$c" -le 0 ] && c=80
    echo "$c"
}

ui_cols() {
    local c
    c="$(ui_real_cols)"
    [ "$c" -gt 100 ] && c=100
    echo "$c"
}

# ---------------------------------------------------------------------------
# Mensajes
# ---------------------------------------------------------------------------
info()    { printf '%s\n' "${CYAN}ℹ  $*${RESET}"; }
success() { printf '%s\n' "${GREEN}✔  $*${RESET}"; }
warn()    { printf '%s\n' "${YELLOW}⚠  $*${RESET}" >&2; }
error()   { printf '%s\n' "${RED}✘  $*${RESET}" >&2; }
dim()     { printf '%s\n' "${DIM}$*${RESET}"; }

# hr [caracter] [color(obsoleto, se ignora)] [ancho]
# Línea horizontal con degradado naranja→azul a lo ancho de la terminal.
hr() {
    local ch="${1:-─}" width="${3:-}" out="" i run seg pm blanks
    case "$width" in ''|*[!0-9]*) width="$(ui_cols)" ;; esac
    [ "$width" -lt 1 ] && width=1
    if [ "$_UI_GRAD_MODE" = none ]; then
        printf -v blanks '%*s' "$width" ''
        printf '%s\n' "${blanks// /$ch}"
        return 0
    fi
    run=$((( width + _GRAD_N - 1) / _GRAD_N)); [ "$run" -lt 1 ] && run=1
    local last=$(( width > 1 ? width - 1 : 1 ))
    for ((i = 0; i < width; i += run)); do
        if [ $(( i + run )) -gt "$width" ]; then seg=$(( width - i )); else seg="$run"; fi
        pm=$(( i * 1000 / last )); [ "$pm" -gt 1000 ] && pm=1000
        printf -v blanks '%*s' "$seg" ''
        out+="$(_grad_at "$pm")${blanks// /$ch}${RESET}"
    done
    printf '%s\n' "$out"
}

# ---------------------------------------------------------------------------
# Letras grandes (fuente ANSI Shadow de 6 filas, sin depender de figlet)
# Cada letra: filas separadas por '|'; todas las filas del ancho del glifo.
# ---------------------------------------------------------------------------
declare -A _GLYPH=(
    [A]=' █████╗ |██╔══██╗|███████║|██╔══██║|██║  ██║|╚═╝  ╚═╝'
    [B]='██████╗ |██╔══██╗|██████╔╝|██╔══██╗|██████╔╝|╚═════╝ '
    [C]=' ██████╗|██╔════╝|██║     |██║     |╚██████╗| ╚═════╝'
    [D]='██████╗ |██╔══██╗|██║  ██║|██║  ██║|██████╔╝|╚═════╝ '
    [E]='███████╗|██╔════╝|█████╗  |██╔══╝  |███████║|╚══════╝'
    [F]='███████╗|██╔════╝|█████╗  |██╔══╝  |██║     |╚═╝     '
    [G]=' ██████╗ |██╔════╝ |██║      |██║  ███╗|╚██████╔╝| ╚═════╝ '
    [H]='██╗   ██╗|██║   ██║|███████║ |██╔══██║ |██║   ██║|╚═╝   ╚═╝'
    [I]='██╗|██║|██║|██║|██║|╚═╝'
    [J]='    ██╗ |    ██║ |    ██║ |██   ██║|╚████╔╝ |  ╚═══╝ '
    [K]='██╗  ██╗|██║ ██╔╝|█████╔╝ |██╔═██╗ |██║  ██╗|╚═╝  ╚═╝'
    [L]='██╗     |██║     |██║     |██║     |███████╗|╚══════╝'
    [M]='███╗   ███╗|████╗ ████║|██╔████╔██║|██║╚██╔╝██║|██║ ╚═╝ ██║|╚═╝     ╚═╝'
    [N]='███╗   ██╗|████╗  ██║|██╔██╗ ██║|██║╚██╗██║|██║ ╚████║|╚═╝  ╚═══╝'
    [O]=' ██████╗ |██╔═══██╗|██║   ██║|██║   ██║|╚██████╔╝| ╚═════╝ '
    [P]='██████╗ |██╔══██╗|██████╔╝|██╔═══╝ |██║     |╚═╝     '
    [Q]=' ██████╗ |██╔═══██╗|██║   ██║|██║▄▄ ██║|╚██████╔╝| ╚══▄▄═╝ '
    [R]='██████╗ |██╔══██╗|██████╔╝|██╔══██╗|██║  ██║|╚═╝  ╚═╝'
    [S]='███████╗|██╔════╝|███████╗|╚════██║|███████║|╚══════╝'
    [T]='████████╗|╚══██╔══╝|   ██║   |   ██║   |   ██║   |   ╚═╝   '
    [U]='██╗   ██╗|██║   ██║|██║   ██║|██║   ██║|╚██████╔╝| ╚═════╝ '
    [V]='██╗   ██╗|██║   ██║|██║   ██║|╚██╗ ██╔╝| ╚████╔╝ |  ╚═══╝  '
    [W]='██╗    ██╗|██║    ██║|██║ █╗ ██║|██║███╗██║|╚████╔╝██║| ╚═══╝ ╚═╝'
    [X]='██╗  ██╗|╚██╗██╔╝| ╚███╔╝ | ██╔██╗ |██╔╝ ██╗|╚═╝  ╚═╝'
    [Y]='██╗  ██╗|╚██╗██╔╝| ╚███╔╝ |  ██╔╝  |  ██╔╝  |  ╚═╝   '
    [Z]='███████╗|   ╚██╗ |   ██╔╝ |  ██╔═╝ |███████╗|╚══════╝'
    [0]=' ██████╗ |██╔═══██╗|██║   ██║|██║   ██║|╚██████╔╝| ╚═════╝ '
    [1]=' ██╗ |███║ | ██║ | ██║ | ██║ | ╚═╝ '
    [2]=' ██████╗ |██╔════╝ |███████╗ |╚════██║ |██████╔╝ | ╚═════╝ '
    [3]='██████╗ |╚════██╗|    ██║ |    ██║ |██████╔╝|╚═════╝ '
    [4]=' ██╗  ██╗| ██║  ██║|███████║ |╚════██║ |     ██║ |     ╚═╝ '
    [5]='███████╗|██╔════╝|███████╗|╚════██║|███████║|╚══════╝'
    [6]=' ██████╗ |██╔════╝ |███████╗ |██╔══██║ |╚██████╔╝| ╚═════╝ '
    [7]='███████╗|     ██║|    ██║ |   ██║  |  ██║   |  ╚═╝   '
    [8]=' ██████╗ |██╔═══██╗|╚██████╔╝| ██████╗ |██╔═══██╗|╚█████╔╝ '
    [9]=' ██████╗ |██╔═══██╗|╚██████╔╝| ╚════██║|██████╔╝ |╚═════╝  '
    [' ']='..|..|..|..|..|..'
    ['-']='        |        |███████╗|        |        |        '
    ['+']='  ███  |  ███  |███████|  ███  |  ███  |       '
    ['.']='   |   |   |   |   |██╗'
    ['/']='    ██╗|   ██║ |  ██║  | ██║   |██║    |╚═╝    '
)

# Quita tildes/ñ y pasa a mayúsculas (la fuente grande es solo ASCII)
_ascii_upper() {
    local t="${1^^}"
    t="${t//Á/A}"; t="${t//É/E}"; t="${t//Í/I}"; t="${t//Ó/O}"; t="${t//Ú/U}"; t="${t//Ü/U}"; t="${t//Ñ/N}"
    printf '%s' "$t"
}

# ancho en columnas que ocuparía un texto con la fuente grande
big_width() {
    local t w=0 i ch g first
    t="$(_ascii_upper "$1")"
    for ((i = 0; i < ${#t}; i++)); do
        ch="${t:i:1}"; g="${_GLYPH[$ch]:-${_GLYPH[' ']}}"; first="${g%%|*}"
        w=$((w + ${#first} + 1))
    done
    echo "$w"
}

# big_text "TEXTO" [color] — imprime el texto en letras grandes.
# Con «gradient» cada fila toma un punto del degradado naranja→azul.
big_text() {
    local text mode="${2:-gradient}" i r ch g pm nr
    local -a rows=() seg
    text="$(_ascii_upper "$1")"
    for ((i = 0; i < ${#text}; i++)); do
        ch="${text:i:1}"; g="${_GLYPH[$ch]:-${_GLYPH[' ']}}"
        IFS='|' read -ra seg <<< "$g"
        for r in "${!seg[@]}"; do rows[r]+="${seg[r]}."; done
    done
    nr="${#rows[@]}"
    for r in "${!rows[@]}"; do
        local line="${rows[r]//#/█}"; line="${line//./ }"
        if [ "$nr" -gt 1 ]; then pm=$(( r * 1000 / (nr - 1) )); else pm=500; fi
        if [ "$mode" = "gradient" ]; then
            printf '%s\n' "  $(_grad_at "$pm")${line}${RESET}"
        else
            printf '%s\n' "  ${mode}${line}${RESET}"
        fi
    done
}

# ---------------------------------------------------------------------------
# Banner de presentación
# ---------------------------------------------------------------------------
# Bloque 1: «VIC DEV PRO» (fuente ANSI Shadow). Se muestra completo si cabe
# en la terminal; si no, se usa una versión compacta con la fuente 5x5.
readarray -t _BANNER_VIC <<'ART'
██╗   ██╗██╗ ██████╗              ██████╗ ███████╗██╗   ██╗    ██████╗ ██████╗  ██████╗
██║   ██║██║██╔════╝              ██╔══██╗██╔════╝██║   ██║    ██╔══██╗██╔══██╗██╔═══██╗
██║   ██║██║██║         █████╗    ██║  ██║█████╗  ██║   ██║    ██████╔╝██████╔╝██║   ██║
╚██╗ ██╔╝██║██║         ╚════╝    ██║  ██║██╔══╝  ╚██╗ ██╔╝    ██╔═══╝ ██╔══██╗██║   ██║
 ╚████╔╝ ██║╚██████╗              ██████╔╝███████╗ ╚████╔╝     ██║     ██║  ██║╚██████╔╝
  ╚═══╝  ╚═╝ ╚═════╝              ╚═════╝ ╚══════╝  ╚═══╝      ╚═╝     ╚═╝  ╚═╝ ╚═════╝
ART

# Bloque 2: «linux conf» (fuente 3D) con degradado vertical truecolor.
readarray -t _BANNER_CONF <<'ART'
___                                ____                    __  _
  / (_)__  __ ____ __  _______  ___  / _(_)__ ___ _________ _/ /_(_)__  ___
 / / / _ \/ // /\ \ / / __/ _ \/ _ \/ _/ / _ `/ // / __/ _ `/ __/ / _ \/ _ \
/_/_/_//_/\_,_//_\_\  \__/\___/_//_/_//_/\_, /\_,_/_/  \_,_/\__/_/\___/_//_/
                                        /___/
                                        __
                          ___ __ _____ / /____ __ _
                         (_-</ // (_-</ __/ -_)  ' \
                        /___/\_, /___/\__/\__/_/_/_/
                            /___/
ART

# Degradado del banner: 16 filas (6 de VIC + 10 de linux conf) repartidas
# a lo largo del degradado naranja→azul, de arriba abajo.
_banner_row_pm() {  # <fila 0..15> → permil del degradado
    printf '%s' "$(( $1 * 1000 / 15 ))"
}

_banner_art_width() {
    local line w=0
    for line in "${_BANNER_VIC[@]}" "${_BANNER_CONF[@]}"; do
        [ "${#line}" -gt "$w" ] && w="${#line}"
    done
    printf '%s' "$w"
}

banner_vic_art() {
    local i line pm
    for i in "${!_BANNER_VIC[@]}"; do
        pm="$(_banner_row_pm "$i")"
        line="${_BANNER_VIC[i]}"
        printf '%s\n' "  $(_grad_at "$pm")${line}${RESET}"
    done
}

banner_conf_art() {
    local i line pm
    for i in "${!_BANNER_CONF[@]}"; do
        pm="$(_banner_row_pm $(( i + 6 )))"
        line="${_BANNER_CONF[i]}"
        printf '%s\n' "  $(_grad_at "$pm")${line}${RESET}"
    done
}

show_banner() {
    [ -t 1 ] && [ "${DRY_RUN:-0}" != 1 ] && command -v clear >/dev/null 2>&1 && clear 2>/dev/null || true
    local cols art_w width
    cols="$(ui_real_cols)"
    art_w="$(( $(_banner_art_width) + 2 ))"
    if [ "$cols" -ge "$art_w" ]; then
        width="$art_w"
    else
        width="$(ui_cols)"
    fi
    echo
    if [ "$cols" -ge "$art_w" ]; then
        banner_vic_art
        echo
        banner_conf_art
    else
        big_text "VIC"
        printf '%s\n' "  ${BOLD}${WHITE}LINUX CONF${RESET}"
    fi
    echo
    printf '%s\n' "  ${BOLD}${WHITE}Instalador y configurador automático de Linux${RESET}"
    printf '%s\n' "  ${BOLD}${CYAN}Ubuntu (linux conf)  ·  Manjaro (manjaro conf)${RESET}   ${BOLD}${DIM}— Escritorio o USB${RESET}"
    printf '%s\n' "  ${DIM}Por Victor Carrillo${RESET}"
    echo
    hr '█' "$MAGENTA" "$width"
    echo
}

# ---------------------------------------------------------------------------
# Títulos de sección (grandes) y de cada instalación
# ---------------------------------------------------------------------------
# section_title "NOMBRE" "descripción"
section_title() {
    local name="$1" desc="${2:-}" w
    w="$(big_width "$name")"
    echo
    if [ "$w" -le "$(ui_cols)" ]; then
        big_text "$name" gradient
    else
        printf '%s\n' "  ${BOLD}${WHITE}$(_ascii_upper "$name")${RESET}"
    fi
    [ -n "$desc" ] && printf '%s\n' "  ${BOLD}${DIM}${desc}${RESET}"
    hr '█'
    echo
}

# item_title <n> <total> "etiqueta" — cabecera de cada instalación
item_title() {
    local n="$1" total="$2" label="$3"
    echo
    printf '%s\n' "${BOLD}${WHITE}  ▶ [${n}/${total}]  ${label}  ${RESET}"
    hr '─' "$BLUE"
}

# item_end — cierre de cada paso: línea de guiones
item_end() {
    hr '-' "$BLUE"
}

# Pausa tras cada instalación (para que el resultado quede visible)
pause_after_item() {
    [ "${DRY_RUN:-0}" = 1 ] && return 0
    [ "${PAUSE_SECONDS:-0}" -gt 0 ] 2>/dev/null || return 0
    printf '%s\n' "${DIM}   … esperando ${PAUSE_SECONDS} s antes del siguiente paso${RESET}"
    sleep "$PAUSE_SECONDS"
}
