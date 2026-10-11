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

ui_cols() {
    local c="${COLUMNS:-}"
    [ -z "$c" ] && [ -t 1 ] && c="$(tput cols 2>/dev/null || true)"
    case "$c" in ''|*[!0-9]*) c=80 ;; esac
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

# hr [caracter] [color] — línea horizontal del ancho de la terminal
hr() {
    local ch="${1:-─}" color="${2:-$DIM}" line
    printf -v line '%*s' "$(ui_cols)" ''
    printf '%s\n' "${color}${line// /$ch}${RESET}"
}

# ---------------------------------------------------------------------------
# Letras grandes (fuente de bloques 5x5 propia, sin depender de figlet)
# '#' = bloque, '.' = vacío. Cada letra: 5 filas separadas por '|'.
# ---------------------------------------------------------------------------
declare -A _GLYPH=(
    [A]='.###.|#...#|#####|#...#|#...#'   [B]='####.|#...#|####.|#...#|####.'
    [C]='.####|#....|#....|#....|.####'   [D]='####.|#...#|#...#|#...#|####.'
    [E]='#####|#....|####.|#....|#####'   [F]='#####|#....|####.|#....|#....'
    [G]='.####|#....|#.###|#...#|.####'   [H]='#...#|#...#|#####|#...#|#...#'
    [I]='#####|..#..|..#..|..#..|#####'   [J]='..###|...#.|...#.|#..#.|.##..'
    [K]='#...#|#..#.|###..|#..#.|#...#'   [L]='#....|#....|#....|#....|#####'
    [M]='#...#|##.##|#.#.#|#...#|#...#'   [N]='#...#|##..#|#.#.#|#..##|#...#'
    [O]='.###.|#...#|#...#|#...#|.###.'   [P]='####.|#...#|####.|#....|#....'
    [Q]='.###.|#...#|#.#.#|#..#.|.##.#'   [R]='####.|#...#|####.|#..#.|#...#'
    [S]='.####|#....|.###.|....#|####.'   [T]='#####|..#..|..#..|..#..|..#..'
    [U]='#...#|#...#|#...#|#...#|.###.'   [V]='#...#|#...#|#...#|.#.#.|..#..'
    [W]='#...#|#...#|#.#.#|##.##|#...#'   [X]='#...#|.#.#.|..#..|.#.#.|#...#'
    [Y]='#...#|.#.#.|..#..|..#..|..#..'   [Z]='#####|...#.|..#..|.#...|#####'
    [0]='.###.|#..##|#.#.#|##..#|.###.'   [1]='..#..|.##..|..#..|..#..|.###.'
    [2]='.###.|#...#|..##.|.#...|#####'   [3]='####.|....#|.###.|....#|####.'
    [4]='#..#.|#..#.|#####|...#.|...#.'   [5]='#####|#....|####.|....#|####.'
    [6]='.###.|#....|####.|#...#|.###.'   [7]='#####|....#|...#.|..#..|..#..'
    [8]='.###.|#...#|.###.|#...#|.###.'   [9]='.###.|#...#|.####|....#|.###.'
    [' ']='..|..|..|..|..'                ['-']='.....|.....|#####|.....|.....'
    ['+']='..#..|..#..|#####|..#..|..#..' ['/']='....#|...#.|..#..|.#...|#....'
    ['&']='.##..|#..#.|.##.#|#..#.|.##.#' ['.']='..|..|..|..|#.'
)

# Quita tildes/ñ y pasa a mayúsculas (la fuente grande es solo ASCII)
_ascii_upper() {
    local t="${1^^}"
    t="${t//Á/A}"; t="${t//É/E}"; t="${t//Í/I}"; t="${t//Ó/O}"; t="${t//Ú/U}"; t="${t//Ü/U}"; t="${t//Ñ/N}"
    printf '%s' "$t"
}

# Ancho en columnas que ocuparía un texto con la fuente grande
big_width() {
    local t w=0 i ch g first
    t="$(_ascii_upper "$1")"
    for ((i = 0; i < ${#t}; i++)); do
        ch="${t:i:1}"; g="${_GLYPH[$ch]:-${_GLYPH[' ']}}"; first="${g%%|*}"
        w=$((w + ${#first} + 1))
    done
    echo "$w"
}

# big_text "TEXTO" [color|rainbow] — imprime el texto en letras grandes
big_text() {
    local text color="${2:-$CYAN}" i r ch g
    local -a rows=("" "" "" "" "") parts
    local -a rainbow=("$RED" "$YELLOW" "$GREEN" "$CYAN" "$MAGENTA")
    text="$(_ascii_upper "$1")"
    for ((i = 0; i < ${#text}; i++)); do
        ch="${text:i:1}"; g="${_GLYPH[$ch]:-${_GLYPH[' ']}}"
        IFS='|' read -ra parts <<< "$g"
        for r in 0 1 2 3 4; do rows[r]+="${parts[r]}."; done
    done
    for r in 0 1 2 3 4; do
        local line="${rows[r]//#/█}"; line="${line//./ }"
        if [ "$color" = "rainbow" ]; then
            printf '%s\n' "  ${rainbow[r]}${line}${RESET}"
        else
            printf '%s\n' "  ${color}${line}${RESET}"
        fi
    done
}

# ---------------------------------------------------------------------------
# Banner de presentación
# ---------------------------------------------------------------------------
show_banner() {
    [ -t 1 ] && [ "${DRY_RUN:-0}" != 1 ] && command -v clear >/dev/null 2>&1 && clear 2>/dev/null || true
    echo
    hr '═' "$MAGENTA"
    echo
    big_text "LINUX CONF" rainbow
    echo
    printf '%s\n' "  ${BOLD}${WHITE}Instalador y configurador automático de Linux${RESET}"
    printf '%s\n' "  ${CYAN}Ubuntu (linux conf)  ·  Manjaro (manjaro conf)${RESET}   ${DIM}— Escritorio o USB${RESET}"
    printf '%s\n' "  ${DIM}Por Victor Carrillo${RESET}"
    echo
    hr '═' "$MAGENTA"
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
    hr '█' "$BLUE"
    if [ "$w" -le "$(ui_cols)" ]; then
        big_text "$name" "$MAGENTA"
    else
        printf '%s\n' "  ${BOLD}${MAGENTA}$(_ascii_upper "$name")${RESET}"
    fi
    [ -n "$desc" ] && printf '%s\n' "  ${DIM}${desc}${RESET}"
    hr '█' "$BLUE"
    echo
}

# item_title <n> <total> "etiqueta" — cabecera de cada instalación
item_title() {
    local n="$1" total="$2" label="$3"
    echo
    printf '%s\n' "${BG_BLUE}${BOLD}${WHITE}  ▶ [${n}/${total}]  ${label}  ${RESET}"
    hr '─' "$BLUE"
}

# Pausa tras cada instalación (para que el resultado quede visible)
pause_after_item() {
    [ "${DRY_RUN:-0}" = 1 ] && return 0
    [ "${PAUSE_SECONDS:-0}" -gt 0 ] 2>/dev/null || return 0
    printf '%s\n' "${DIM}   … esperando ${PAUSE_SECONDS} s antes del siguiente paso${RESET}"
    sleep "$PAUSE_SECONDS"
}
