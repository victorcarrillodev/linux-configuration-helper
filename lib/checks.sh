#!/usr/bin/env bash
# lib/checks.sh — Verificaciones (solo lectura) y preparación del entorno.

[ -n "${CHECKS_LOADED:-}" ] && return 0
CHECKS_LOADED=1

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# cmd_works <comando externo> [args…] — existe y se ejecuta sin error (con límite de tiempo)
cmd_works() {
    has_cmd "$1" || return 1
    timeout 25 "$@" </dev/null >/dev/null 2>&1
}

# glob_exists '/ruta/patron*' — hay al menos un archivo que coincide
glob_exists() { compgen -G "$1" >/dev/null 2>&1; }

# file_has <archivo> <texto-literal>
file_has() { grep -qF -- "$2" "$1" 2>/dev/null; }

# ¿Todos los paquetes están instalados? (usa pkg_installed de la distro)
pkgs_installed() {
    local p
    for p in "$@"; do pkg_installed "$p" || return 1; done
    return 0
}

# Usuario en el grupo (según /etc/group) y en la sesión actual
user_in_group_file()    { getent group "$1" 2>/dev/null | tr ':,' '  ' | grep -qw -- "${USER:-$(id -un)}"; }
user_in_session_group() { id -nG 2>/dev/null | tr ' ' '\n' | grep -qx -- "$1"; }

# service_enabled <unidad> — el servicio está habilitado (si no hay systemd, p. ej. en un contenedor, no se puede juzgar)
service_enabled() {
    [ -d /run/systemd/system ] || return 0
    systemctl is-enabled --quiet "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Entorno: PATH con los directorios donde se instalan las herramientas
# ---------------------------------------------------------------------------
# Carpeta bin de la versión de Node (NVM) por defecto, si existe
nvm_node_bin() {
    local base="${NVM_DIR:-$HOME/.nvm}" dir want d v best
    local -a vers
    dir="${base}/versions/node"
    [ -d "$dir" ] || return 1
    want="$(cat "${base}/alias/default" 2>/dev/null || true)"
    want="${want#v}"
    # Versiones instaladas, ordenadas (la más nueva al final)
    mapfile -t vers < <(for d in "$dir"/v*; do [ -d "$d" ] && basename "$d"; done | sort -V)
    [ "${#vers[@]}" -gt 0 ] || return 1
    best="${vers[${#vers[@]}-1]}"
    if [ -n "$want" ]; then
        for v in "${vers[@]}"; do
            case "$v" in "v${want}"|"v${want}."*) best="$v" ;; esac
        done
    fi
    printf '%s\n' "${dir}/${best}/bin"
}

# Añade al PATH de ESTE proceso lo que haya instalado (así se detecta sin abrir otra terminal)
refresh_env() {
    local d
    for d in "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.bun/bin" \
             "$HOME/.local/share/pnpm" "$HOME/.npm-global/bin" /snap/bin /usr/games; do
        [ -d "$d" ] || continue
        case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    done
    d="$(nvm_node_bin 2>/dev/null || true)"
    if [ -n "$d" ]; then
        case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    fi
    export PATH
    return 0
}

# nvm_cmd <args…> — ejecuta 'nvm' (nvm.sh no es compatible con 'set -e')
nvm_cmd() {
    local rc restore=""
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    case $- in *e*) restore=1 ;; esac
    set +e
    # shellcheck disable=SC1091
    . "${NVM_DIR}/nvm.sh"
    nvm "$@"
    rc=$?
    [ -n "$restore" ] && set -e
    return "$rc"
}

# ---------------------------------------------------------------------------
# Red
# ---------------------------------------------------------------------------
net_ok() {
    curl -fsS --max-time 8 -o /dev/null https://github.com 2>/dev/null \
        || curl -fsS --max-time 8 -o /dev/null https://www.google.com 2>/dev/null
}

# wait_for_network [segundos] — espera a que vuelva la conexión
wait_for_network() {
    local limit="${1:-60}" waited=0
    while ! net_ok; do
        [ "$waited" -ge "$limit" ] && return 1
        warn "Sin conexión a internet; reintentando en 5 s…"
        sleep 5
        waited=$((waited + 5))
    done
    return 0
}

# ---------------------------------------------------------------------------
# Descargas (siempre a un archivo: un 'curl | sh' fallido no debe pasar por éxito)
# ---------------------------------------------------------------------------
# download <url> <destino>
download() {
    curl -fsSL --retry 3 --retry-delay 2 -o "$2" "$1" || { error "No se pudo descargar $1"; return 1; }
}

# run_remote_script <url> <intérprete> [args…] — baja el script y lo ejecuta
run_remote_script() {
    local url="$1" interp="$2" tmp rc
    shift 2
    tmp="$(mktemp)" || return 1
    if ! download "$url" "$tmp"; then rm -f "$tmp"; return 1; fi
    "$interp" "$tmp" "$@"
    rc=$?
    rm -f "$tmp"
    return "$rc"
}
