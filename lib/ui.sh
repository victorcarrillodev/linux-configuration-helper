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
# Línea horizontal con degradado naranja→azul que ocupa TODO el ancho de la terminal.
# En truecolor cada columna tiene su propio color (degradado suave); si no, por tramos.
hr() {
    local ch="${1:-─}" width="${3:-}" out="" i run seg pm blanks last r g b t prev="" esc
    case "$width" in ''|*[!0-9]*) width="$(ui_real_cols)" ;; esac
    [ "$width" -lt 1 ] && width=1
    if [ "$_UI_GRAD_MODE" = none ]; then
        printf -v blanks '%*s' "$width" ''
        printf '%s\n' "${blanks// /$ch}"
        return 0
    fi
    last=$(( width > 1 ? width - 1 : 1 ))
    if [ "$_UI_GRAD_MODE" = tc ]; then
        for ((i = 0; i < width; i++)); do
            t=$(( i * 255 / last ))
            r=$(( _G_R1 + (t * (_G_R2 - _G_R1) + 127) / 255 ))
            g=$(( _G_G1 + (t * (_G_G2 - _G_G1) + 127) / 255 ))
            b=$(( _G_B1 + (t * (_G_B2 - _G_B1) + 127) / 255 ))
            esc=$'\033[38;2;'"${r};${g};${b}m"
            [ "$esc" != "$prev" ] && out+="$esc" && prev="$esc"
            out+="$ch"
        done
        printf '%s\n' "${out}${RESET}"
        return 0
    fi
    run=$(( (width + _GRAD_N - 1) / _GRAD_N )); [ "$run" -lt 1 ] && run=1
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
# Fuente de bloques compacta (3 filas de texto = 5 filas de píxeles con medios bloques ▀▄█)
# Cada letra: 5 filas de píxeles separadas por '|' ('#' encendido, '.' apagado).
# ---------------------------------------------------------------------------
declare -A _PX=(
    [A]='.#.|#.#|###|#.#|#.#'     [B]='##.|#.#|##.|#.#|##.'     [C]='.##|#..|#..|#..|.##'
    [D]='##.|#.#|#.#|#.#|##.'     [E]='###|#..|##.|#..|###'     [F]='###|#..|##.|#..|#..'
    [G]='.##|#..|#.#|#.#|.##'     [H]='#.#|#.#|###|#.#|#.#'     [I]='###|.#.|.#.|.#.|###'
    [J]='..#|..#|..#|#.#|.#.'     [K]='#.#|#.#|##.|#.#|#.#'     [L]='#..|#..|#..|#..|###'
    [M]='#...#|##.##|#.#.#|#...#|#...#'                         [N]='#..#|##.#|#.##|#..#|#..#'
    [O]='.#.|#.#|#.#|#.#|.#.'     [P]='##.|#.#|##.|#..|#..'     [Q]='.#.|#.#|#.#|##.|.##'
    [R]='##.|#.#|##.|#.#|#.#'     [S]='.##|#..|.#.|..#|##.'     [T]='###|.#.|.#.|.#.|.#.'
    [U]='#.#|#.#|#.#|#.#|###'     [V]='#.#|#.#|#.#|#.#|.#.'     [W]='#...#|#...#|#.#.#|##.##|#...#'
    [X]='#.#|#.#|.#.|#.#|#.#'     [Y]='#.#|#.#|.#.|.#.|.#.'     [Z]='###|..#|.#.|#..|###'
    ['-']='...|...|###|...|...'   [' ']='..|..|..|..|..'          ['.']='.|.|.|.|#'
)

# _px_rows "TEXTO" → _ROWS (3 filas) y _ROWS_W (ancho)
_px_rows() {
    local t i ch c r top bot line
    local -a px=("" "" "" "" "") seg
    t="$(_ascii_upper "$1")"
    for ((i = 0; i < ${#t}; i++)); do
        ch="${t:i:1}"
        IFS='|' read -ra seg <<< "${_PX[$ch]:-${_PX[' ']}}"
        for r in 0 1 2 3 4; do px[r]+="${seg[r]}"; [ "$i" -lt $(( ${#t} - 1 )) ] && px[r]+="."; done
    done
    _ROWS=()
    for r in 0 2 4; do
        line=""
        for ((c = 0; c < ${#px[0]}; c++)); do
            top="${px[r]:c:1}"; bot="."; [ "$r" -lt 4 ] && bot="${px[r+1]:c:1}"
            case "$top$bot" in '##') line+='█' ;; '#.') line+='▀' ;; '.#') line+='▄' ;; *) line+=' ' ;; esac
        done
        _ROWS+=("$line")
    done
    _ROWS_W="${#px[0]}"
}

# _shadow_rows "TEXTO" → _ROWS (6 filas, fuente ANSI Shadow) y _ROWS_W
_shadow_rows() {
    local t i r ch g w=0
    local -a seg
    _ROWS=("" "" "" "" "" "")
    t="$(_ascii_upper "$1")"
    for ((i = 0; i < ${#t}; i++)); do
        ch="${t:i:1}"; g="${_GLYPH[$ch]:-${_GLYPH[' ']}}"
        IFS='|' read -ra seg <<< "$g"
        for r in 0 1 2 3 4 5; do _ROWS[r]+="${seg[r]//./ } "; done
    done
    for r in 0 1 2 3 4 5; do [ "${#_ROWS[r]}" -gt "$w" ] && w="${#_ROWS[r]}"; done
    _ROWS_W="$w"
}

_font_width() {   # _font_width <shadow|px> "TEXTO"
    if [ "$1" = shadow ]; then _shadow_rows "$2"; else _px_rows "$2"; fi
    printf '%s' "$_ROWS_W"
}

# _banner_block "TEXTO" <ancho> <máx. líneas shadow> <máx. líneas px>
# Elige la fuente MÁS GRANDE en la que el texto cabe (partiendo por palabras) y añade las filas
# resultantes a _BANNER (cada bloque separado por "\x1f<ancho>" para centrarlo como unidad).
_banner_block() {
    local text="$1" avail="$2" font max word cur lines n w ok
    local -a parts
    for font in shadow px; do
        [ "$font" = shadow ] && max="$3" || max="$4"
        [ "$max" -gt 0 ] || continue
        parts=(); cur=""; ok=1
        for word in $text; do
            if [ -n "$cur" ] && [ "$(_font_width "$font" "$cur $word")" -le "$avail" ]; then
                cur="$cur $word"
            else
                [ -n "$cur" ] && parts+=("$cur")
                cur="$word"
                [ "$(_font_width "$font" "$cur")" -le "$avail" ] || { ok=0; break; }
            fi
        done
        [ -n "$cur" ] && parts+=("$cur")
        [ "$ok" = 1 ] && [ "${#parts[@]}" -le "$max" ] || continue
        for n in "${!parts[@]}"; do
            if [ "$font" = shadow ]; then _shadow_rows "${parts[n]}"; else _px_rows "${parts[n]}"; fi
            _BANNER+=($'\x1f'"$_ROWS_W" "${_ROWS[@]}")
        done
        return 0
    done
    # Ninguna fuente cabe: texto en negrita (se marca con \x1e)
    _BANNER+=($'\x1f0' $'\x1e'"$text")
}

# _center <ancho-del-contenido> → espacios para centrarlo en la terminal
_center() {
    local cols pad
    cols="$(ui_real_cols)"
    pad=$(( (cols - $1) / 2 )); [ "$pad" -lt 0 ] && pad=0
    printf '%*s' "$pad" ''
}

# Imprime una línea de texto con códigos de color, centrada según su texto visible
_center_line() {
    local plain
    plain="$(sed 's/\x1b\[[0-9;]*m//g' <<< "$1")"
    printf '%s%s\n' "$(_center "${#plain}")" "$1"
}

show_banner() {
    [ -t 1 ] && [ "${DRY_RUN:-0}" != 1 ] && command -v clear >/dev/null 2>&1 && clear 2>/dev/null || true
    local cols avail total=0 i n=0 pm row bw=0 pad=""
    cols="$(ui_real_cols)"
    avail=$(( cols - 4 ))

    # 1) Componer: «VIC-DEV PRO» (máx. 1 línea) y «LINUX CONFIGURATION SYSTEM» (fuente compacta
    #    hasta 3 líneas, o grande si cabe en 2). Cada parte usa la fuente más grande que quepa.
    _BANNER=()
    _banner_block "VIC-DEV PRO" "$avail" 1 2
    _BANNER+=($'\x1f0' "")
    _banner_block "LINUX CONFIGURATION SYSTEM" "$avail" 2 3

    for row in "${_BANNER[@]}"; do [[ "$row" == $'\x1f'* ]] || total=$((total + 1)); done
    [ "$total" -lt 2 ] && total=2

    # 2) Pintar centrado, con degradado vertical naranja→azul
    echo
    for row in "${_BANNER[@]}"; do
        if [[ "$row" == $'\x1f'* ]]; then bw="${row#?}"; pad="$(_center "$bw")"; continue; fi
        pm=$(( n * 1000 / (total - 1) )); n=$((n + 1))
        if [[ "$row" == $'\x1e'* ]]; then
            _center_line "${BOLD}$(_grad_at "$pm")${row#?}${RESET}"
        elif [ -z "$row" ]; then
            echo
        else
            printf '%s%s\n' "$pad" "$(_grad_at "$pm")${row}${RESET}"
        fi
    done
    echo
    _center_line "${BOLD}${WHITE}Instalador y configurador automático de Linux${RESET}"
    if [ "$cols" -ge 76 ]; then
        _center_line "${BOLD}${CYAN}Ubuntu (linux conf)  ·  Manjaro (manjaro conf)${RESET}  ${DIM}— Escritorio o USB${RESET}"
    else
        _center_line "${BOLD}${CYAN}Ubuntu (linux conf)${RESET}"
        _center_line "${BOLD}${CYAN}Manjaro (manjaro conf)${RESET}"
        _center_line "${DIM}Escritorio o USB${RESET}"
    fi
    _center_line "${DIM}Por Victor Carrillo${RESET}"
    echo
    hr '█'
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
