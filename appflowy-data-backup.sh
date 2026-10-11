#!/usr/bin/env bash
# =============================================================================
#  appflowy-data-backup.sh — Respaldo y restauración de los datos de AppFlowy en GitHub
#
#  · Menú interactivo: hacer una copia de seguridad, restaurar, ver estado, activar/desactivar el daemon.
#  · Modo daemon (--daemon): se queda en segundo plano y sube un respaldo cada 7 días.
#  · Se puede ejecutar como «appflowy-data-backup.sh» (se instala en ~/.local/bin).
#
#  SEGURIDAD: tus notas se suben a un repositorio de GitHub. El script se NIEGA a subir
#  si el repositorio es público (comprueba la visibilidad antes de cada subida).
#  No se guarda shared_preferences.json y se vacían los tokens de sesión de la copia de la base de
#  datos (el original no se toca): tras restaurar tendrás que iniciar sesión en AppFlowy otra vez.
# =============================================================================
set -uo pipefail

VERSION="1.0"
SELF_NAME="appflowy-data-backup.sh"

# ----------------------------------------------------------------------------
# Configuración (valores por defecto → ~/.config/appflowy-data-backup/config → variables AFB_*)
# ----------------------------------------------------------------------------
CONFIG_FILE="${AFB_CONFIG:-$HOME/.config/appflowy-data-backup/config}"
REPO_URL="https://github.com/victorcarrillodev/appflowy-backup.git"
DATA_DIR="$HOME/.local/share/io.appflowy.appflowy"
STATE_DIR="$HOME/.local/share/appflowy-data-backup"
BRANCH="main"
INTERVAL_DAYS=7            # cada cuántos días el daemon hace un respaldo
CHECK_SECONDS=1800         # cada cuánto el daemon mira si toca respaldar
WAIT_RUNNING_HOURS=24      # si AppFlowy está abierto, espera hasta tanto antes de copiar "en caliente"
MAX_FILE_MB=90             # GitHub rechaza archivos de más de 100 MB: los mayores se omiten
INCLUDE_PREFERENCES=0      # 1 = incluir shared_preferences.json (puede contener la sesión)
SCRUB_TOKENS=1             # 1 = vaciar los tokens de sesión (access/refresh) dentro de la COPIA de la base de datos
PROC_REGEX='(^|/)AppFlowy($| )'   # cómo reconocer a AppFlowy en ejecución
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
REPO_URL="${AFB_REPO_URL:-$REPO_URL}"
DATA_DIR="${AFB_DATA_DIR:-$DATA_DIR}"
STATE_DIR="${AFB_STATE_DIR:-$STATE_DIR}"
BRANCH="${AFB_BRANCH:-$BRANCH}"
INTERVAL_SECONDS="${AFB_INTERVAL_SECONDS:-$((INTERVAL_DAYS * 86400))}"
CHECK_SECONDS="${AFB_CHECK_SECONDS:-$CHECK_SECONDS}"
WAIT_RUNNING_SECONDS="${AFB_WAIT_RUNNING_SECONDS:-$((WAIT_RUNNING_HOURS * 3600))}"
MAX_FILE_MB="${AFB_MAX_FILE_MB:-$MAX_FILE_MB}"
PROC_REGEX="${AFB_PROC_REGEX:-$PROC_REGEX}"

REPO_DIR="${STATE_DIR}/repo"
LOG_FILE="${STATE_DIR}/daemon.log"
BIN_DIR="$HOME/.local/bin"
INSTALLED_PATH="${BIN_DIR}/${SELF_NAME}"
UNIT_NAME="appflowy-data-backup.service"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
AUTOSTART_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/appflowy-data-backup.desktop"
SNAPSHOT_DIR_NAME="appflowy-data"     # carpeta dentro del repositorio
COMMIT_PREFIX="Respaldo AppFlowy"

ASSUME_YES=0
ALLOW_HOT=0
INTERACTIVE=0
[ -t 0 ] && [ -t 1 ] && INTERACTIVE=1
HOT_COPY=0

# ----------------------------------------------------------------------------
# Mensajes
# ----------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'; RED=$'\033[1;31m'; GRN=$'\033[1;32m'
    YEL=$'\033[1;33m'; CYN=$'\033[1;36m'; MAG=$'\033[1;35m'
else
    B=''; D=''; R=''; RED=''; GRN=''; YEL=''; CYN=''; MAG=''
fi
msg()  { printf '%s\n' "${CYN}ℹ  $*${R}"; }
ok()   { printf '%s\n' "${GRN}✔  $*${R}"; }
warn() { printf '%s\n' "${YEL}⚠  $*${R}" >&2; }
err()  { printf '%s\n' "${RED}✘  $*${R}" >&2; }

# Registro en archivo (con rotación sencilla) para revisar qué hizo el daemon
log() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    if [ -f "$LOG_FILE" ] && [ "$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
        tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

# Notificación de escritorio (solo si hay sesión gráfica y notify-send)
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || return 0
    notify-send -a "AppFlowy Backup" "$1" "$2" >/dev/null 2>&1 || true
}

ask_yes_no() {   # ask_yes_no "texto" [S|N]
    local text="$1" def="${2:-N}" ans hint
    [ "$def" = "S" ] && hint="[S/n]" || hint="[s/N]"
    if [ "$ASSUME_YES" = 1 ]; then [ "$def" = "S" ]; return; fi
    [ "$INTERACTIVE" = 1 ] || { [ "$def" = "S" ]; return; }
    while true; do
        printf '%s' "${B}${text} ${hint}: ${R}"
        read -r ans || { echo; ans=""; }
        case "${ans,,}" in
            s|si|sí|y|yes) return 0 ;;
            n|no) return 1 ;;
            "") [ "$def" = "S" ]; return ;;
        esac
        warn "Responde con 's' o 'n'."
    done
}

# ----------------------------------------------------------------------------
# Utilidades
# ----------------------------------------------------------------------------
now() { date +%s; }

human_size() { du -sh "$1" 2>/dev/null | cut -f1; }

ago() {   # ago <epoch> → "hace 6 días"
    local t="$1" d
    [ "$t" -gt 0 ] 2>/dev/null || { echo "nunca"; return; }
    d=$(( $(now) - t ))
    if   [ "$d" -lt 3600 ];  then echo "hace $((d / 60)) min"
    elif [ "$d" -lt 86400 ]; then echo "hace $((d / 3600)) h"
    else echo "hace $((d / 86400)) días"; fi
}

init_state() { mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"; }

state_get() { cat "${STATE_DIR}/$1" 2>/dev/null || echo "${2:-0}"; }
state_set() { printf '%s\n' "$2" > "${STATE_DIR}/$1"; }

appflowy_running() { pgrep -f "$PROC_REGEX" >/dev/null 2>&1; }

# with_lock <comando…> — evita dos respaldos a la vez (código 75 si ya hay otro en curso)
with_lock() {
    init_state || return 1
    ( flock -n 9 || exit 75; "$@" ) 9>"${STATE_DIR}/lock"
}

check_tools() {
    local t miss=()
    for t in git tar flock pgrep; do command -v "$t" >/dev/null 2>&1 || miss+=("$t"); done
    if [ "${#miss[@]}" -gt 0 ]; then
        err "Faltan herramientas: ${miss[*]}"
        return 1
    fi
    if ! command -v sqlite3 >/dev/null 2>&1; then
        if [ "$SCRUB_TOKENS" = 1 ]; then
            err "Falta sqlite3: es necesario para copiar las bases de datos sin tus tokens de sesión. Instálalo (sqlite3 / sqlite)."
            return 1
        fi
        warn "sqlite3 no está instalado: las bases de datos se copiarán tal cual (menos seguro con AppFlowy abierto)."
    fi
    return 0
}

# ----------------------------------------------------------------------------
# GitHub: autenticación y comprobación de visibilidad
# ----------------------------------------------------------------------------
GH_OWNER=""; GH_REPO=""
parse_github_repo() {
    GH_OWNER=""; GH_REPO=""
    local u="$REPO_URL" path
    case "$u" in
        https://github.com/*) path="${u#https://github.com/}" ;;
        git@github.com:*)     path="${u#git@github.com:}" ;;
        ssh://git@github.com/*) path="${u#ssh://git@github.com/}" ;;
        *) return 1 ;;
    esac
    path="${path%.git}"
    GH_OWNER="${path%%/*}"; GH_REPO="${path#*/}"
    [ -n "$GH_OWNER" ] && [ -n "$GH_REPO" ] && [ "$GH_REPO" != "$path" ]
}

gh_ready() { command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; }

# git con las credenciales de «gh» si está iniciada la sesión (sin tocar tu configuración global)
git_remote() {
    local -a auth=()
    if gh_ready; then auth=(-c credential.helper= -c "credential.helper=!gh auth git-credential"); fi
    if [ "$INTERACTIVE" = 1 ]; then
        git "${auth[@]}" "$@"
    else
        GIT_TERMINAL_PROMPT=0 git "${auth[@]}" "$@"
    fi
}

# Escribe: public | private | missing | unknown | other
repo_visibility() {
    if ! parse_github_repo; then echo other; return; fi
    local v code
    if gh_ready; then
        if v="$(gh api "repos/${GH_OWNER}/${GH_REPO}" --jq .private 2>/dev/null)"; then
            case "$v" in true) echo private; return ;; false) echo public; return ;; esac
        else
            echo missing; return
        fi
    fi
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://api.github.com/repos/${GH_OWNER}/${GH_REPO}" 2>/dev/null || true)"
    case "$code" in
        200) echo public ;;
        404) echo private ;;     # sin sesión: un repo no público (o inexistente) responde 404
        *)   echo unknown ;;
    esac
}

# Garantiza que el destino sea seguro para subir notas personales. Códigos: 0 ok · 3 público · 4 no verificable · 5 no existe
assert_safe_remote() {
    local vis
    parse_github_repo    # fija GH_OWNER/GH_REPO aquí (repo_visibility corre en una subshell y no los exporta)
    vis="$(repo_visibility)"
    case "$vis" in
        public)
            err "El repositorio ${GH_OWNER}/${GH_REPO} es PÚBLICO: tus notas quedarían visibles para cualquiera."
            err "No se sube nada. Hazlo privado y vuelve a intentarlo:"
            printf '     %s\n' "gh repo edit ${GH_OWNER}/${GH_REPO} --visibility private --accept-visibility-change-consequences" >&2
            printf '     %s\n' "(o en GitHub → Settings → Danger Zone → Change visibility)" >&2
            if [ "$INTERACTIVE" = 1 ] && gh_ready && ask_yes_no "¿Quieres que lo haga privado ahora con gh?" N; then
                if gh repo edit "${GH_OWNER}/${GH_REPO}" --visibility private --accept-visibility-change-consequences; then
                    ok "Repositorio ahora privado."
                    return 0
                fi
                err "No se pudo cambiar la visibilidad."
            fi
            return 3 ;;
        unknown)
            err "No pude comprobar si ${GH_OWNER}/${GH_REPO} es privado (¿sin conexión?). Por seguridad no subo nada."
            return 4 ;;
        missing)
            if [ "$INTERACTIVE" = 1 ] && gh_ready && ask_yes_no "El repositorio ${GH_OWNER}/${GH_REPO} no existe. ¿Crearlo PRIVADO ahora?" S; then
                gh repo create "${GH_OWNER}/${GH_REPO}" --private --description "Respaldo de AppFlowy" && { ok "Repositorio privado creado."; return 0; }
                err "No se pudo crear el repositorio."
                return 5
            fi
            err "El repositorio ${GH_OWNER}/${GH_REPO} no existe o no tienes acceso. Créalo PRIVADO:"
            printf '     %s\n' "gh repo create ${GH_OWNER}/${GH_REPO} --private" >&2
            return 5 ;;
        *) return 0 ;;   # privado, o un remoto que no es de GitHub (p. ej. SSH propio)
    esac
}

# ----------------------------------------------------------------------------
# Repositorio local (clon en STATE_DIR/repo)
# ----------------------------------------------------------------------------
ensure_repo() {
    init_state || return 1
    if [ ! -d "${REPO_DIR}/.git" ]; then
        msg "Clonando ${REPO_URL} …"
        if ! git_remote clone --quiet "$REPO_URL" "$REPO_DIR" 2>&1; then
            err "No se pudo clonar el repositorio. ¿Iniciaste sesión? Prueba: gh auth login"
            return 6
        fi
    fi
    git -C "$REPO_DIR" remote set-url origin "$REPO_URL" 2>/dev/null
    if ! git_remote -C "$REPO_DIR" fetch --quiet origin 2>&1; then
        err "No se pudo actualizar desde GitHub."
        return 6
    fi
    if git -C "$REPO_DIR" rev-parse -q --verify "refs/remotes/origin/${BRANCH}" >/dev/null; then
        if git -C "$REPO_DIR" rev-parse -q --verify HEAD >/dev/null; then
            if git -C "$REPO_DIR" merge-base --is-ancestor "origin/${BRANCH}" HEAD; then
                :   # local al día o con respaldos aún sin subir
            elif git -C "$REPO_DIR" merge-base --is-ancestor HEAD "origin/${BRANCH}"; then
                git -C "$REPO_DIR" checkout -q -B "$BRANCH" "origin/${BRANCH}"
            else
                warn "El historial local y el de GitHub divergen: se usa el de GitHub."
                git -C "$REPO_DIR" checkout -q -f -B "$BRANCH" "origin/${BRANCH}"
            fi
        else
            git -C "$REPO_DIR" checkout -q -f -B "$BRANCH" "origin/${BRANCH}"
        fi
    else
        git -C "$REPO_DIR" symbolic-ref HEAD "refs/heads/${BRANCH}"   # repositorio remoto vacío
    fi
    return 0
}

git_commit() {   # git_commit "mensaje" — con identidad de reserva si no tienes una configurada
    local name email
    name="$(git config --global user.name 2>/dev/null || true)";  [ -n "$name" ]  || name="appflowy-data-backup"
    email="$(git config --global user.email 2>/dev/null || true)"; [ -n "$email" ] || email="appflowy-data-backup@$(hostname)"
    git -C "$REPO_DIR" -c user.name="$name" -c user.email="$email" -c commit.gpgsign=false commit -q -m "$1" -m "$2"
}

# ----------------------------------------------------------------------------
# Instantánea de los datos de AppFlowy
# ----------------------------------------------------------------------------
# scrub_db <copia> — vacía user_table.token (access/refresh token de la sesión) SOLO en la copia y compacta la
# base (VACUUM) para que no queden restos del token en páginas libres. Falla si no se puede garantizar.
scrub_db() {
    local db="$1" has
    has="$(sqlite3 "$db" "select count(*) from pragma_table_info('user_table') where name='token';" 2>/dev/null)" || return 1
    [ "$has" = 1 ] || return 0
    sqlite3 "$db" "PRAGMA journal_mode=DELETE; UPDATE user_table SET token=''; VACUUM;" >/dev/null 2>&1 || return 1
    rm -f "${db}-wal" "${db}-shm"
    return 0
}

# Crea en $1 una copia consistente de DATA_DIR sin logs, bloqueos ni (por defecto) preferencias.
SNAP_FILES=0; SNAP_SKIPPED=()
build_snapshot() {
    local dest="$1" f rel out rc_create rc_extract
    local -a pipe_rc
    local -a excl=(--exclude='log.*' --exclude='LOG' --exclude='LOG.old.*' --exclude='LOCK'
                   --exclude='*.lock' --exclude='*.tmp' --exclude='*.db-wal' --exclude='*.db-shm')
    [ "$INCLUDE_PREFERENCES" = 1 ] || excl+=(--exclude='shared_preferences.json')
    mkdir -p "$dest" || return 1
    tar -C "$DATA_DIR" "${excl[@]}" -cf - . 2>/dev/null | tar -C "$dest" -xf -
    pipe_rc=("${PIPESTATUS[@]}")      # copiar el array entero: cualquier asignación lo reinicia
    rc_create=${pipe_rc[0]:-1}; rc_extract=${pipe_rc[1]:-1}
    # código 1 de tar = "algún archivo cambió mientras se leía" (normal con AppFlowy abierto)
    [ "$rc_extract" -eq 0 ] && [ "$rc_create" -le 1 ] || return 1

    # Bases SQLite: instantánea consistente con la API de copia de SQLite (incluye lo pendiente del WAL)
    while IFS= read -r -d '' f; do
        rel="${f#"${DATA_DIR}"/}"
        if command -v sqlite3 >/dev/null 2>&1; then
            mkdir -p "$(dirname "${dest}/${rel}")"
            rm -f "${dest}/${rel}"
            if ! out="$(sqlite3 "$f" ".timeout 15000" ".backup '${dest}/${rel}'" 2>&1)"; then
                warn "sqlite3 no pudo copiar ${rel} (${out}); se copia el archivo tal cual."
                cp -a "$f" "${dest}/${rel}" 2>/dev/null
                [ -f "${f}-wal" ] && cp -a "${f}-wal" "${dest}/${rel}-wal" 2>/dev/null
                [ -f "${f}-shm" ] && cp -a "${f}-shm" "${dest}/${rel}-shm" 2>/dev/null
            fi
            if [ "$SCRUB_TOKENS" = 1 ] && ! scrub_db "${dest}/${rel}"; then
                warn "No pude limpiar los tokens de ${rel}: se omite del respaldo (no se sube con credenciales)."
                rm -f "${dest}/${rel}" "${dest}/${rel}-wal" "${dest}/${rel}-shm"
            fi
        else
            [ -f "${f}-wal" ] && cp -a "${f}-wal" "${dest}/${rel}-wal" 2>/dev/null
        fi
    done < <(find "$DATA_DIR" -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print0)

    # GitHub rechaza archivos > 100 MB: se omiten (y se anotan) los que superen el límite
    SNAP_SKIPPED=()
    while IFS= read -r -d '' f; do
        SNAP_SKIPPED+=("${f#"${dest}"/}")
        rm -f "$f"
    done < <(find "$dest" -type f -size "+${MAX_FILE_MB}M" -print0)
    SNAP_FILES="$(find "$dest" -type f | wc -l)"
    return 0
}

# ----------------------------------------------------------------------------
# Respaldo
# ----------------------------------------------------------------------------
# do_backup [auto] — códigos: 0 ok · 1 error · 3 repo público · 4 no verificable · 5 no existe · 6 sin acceso
_TMP=""
do_backup() {   # envoltorio: siempre limpia la carpeta temporal
    _do_backup "$@"
    local rc=$?
    [ -n "$_TMP" ] && rm -rf "$_TMP"
    return "$rc"
}
_do_backup() {
    local mode="${1:-manual}" tmp size host stamp mode_txt msg_body ahead
    init_state || return 1
    check_tools || return 1
    if [ ! -d "$DATA_DIR" ] || [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        err "No encuentro datos de AppFlowy en ${DATA_DIR} (¿está instalado y lo has usado?)."
        return 1
    fi

    assert_safe_remote || return $?

    if appflowy_running && [ "$HOT_COPY" != 1 ]; then
        if [ "$mode" = auto ]; then
            log "AppFlowy está abierto; el respaldo espera."
            return 7
        fi
        warn "AppFlowy está abierto: la copia puede quedar incompleta. Lo ideal es cerrarlo antes."
        if [ "$ALLOW_HOT" = 1 ]; then
            HOT_COPY=1; warn "Copia «en caliente» autorizada con --hot (queda anotada en BACKUP_INFO.txt)."
        elif ask_yes_no "¿Continuar de todos modos con una copia «en caliente»?" N; then HOT_COPY=1; else
            msg "Cierra AppFlowy y vuelve a intentarlo."; return 7
        fi
    fi
    appflowy_running && HOT_COPY=1

    ensure_repo || return $?

    msg "Preparando la copia de ${DATA_DIR} ($(human_size "$DATA_DIR")) …"
    tmp="$(mktemp -d "${STATE_DIR}/snap.XXXXXX")" || return 1
    _TMP="$tmp"
    build_snapshot "${tmp}/${SNAPSHOT_DIR_NAME}" || { err "No se pudo crear la copia."; return 1; }

    host="$(hostname)"; stamp="$(date '+%Y-%m-%d %H:%M')"
    size="$(human_size "${tmp}/${SNAPSHOT_DIR_NAME}")"
    mode_txt="completa (AppFlowy cerrado)"; [ "$HOT_COPY" = 1 ] && mode_txt="en caliente (AppFlowy estaba abierto)"

    rm -rf "${REPO_DIR:?}/${SNAPSHOT_DIR_NAME}"
    mv "${tmp}/${SNAPSHOT_DIR_NAME}" "${REPO_DIR}/${SNAPSHOT_DIR_NAME}"
    {
        echo "Respaldo de AppFlowy (la fecha de cada respaldo está en el historial de commits)"
        echo "Equipo:    ${host}"
        echo "Archivos:  ${SNAP_FILES}"
        echo "Tamaño:    ${size}"
        echo "Modo:      ${mode_txt}"
        echo "Origen:    ${DATA_DIR}"
        if [ "${#SNAP_SKIPPED[@]}" -gt 0 ]; then
            echo "Omitidos por superar ${MAX_FILE_MB} MB:"
            printf '  - %s\n' "${SNAP_SKIPPED[@]}"
        fi
    } > "${REPO_DIR}/BACKUP_INFO.txt"
    if [ ! -f "${REPO_DIR}/README.md" ]; then
        printf '# appflowy-backup\n\nRespaldo automático de los datos de AppFlowy, generado por `appflowy-data-backup.sh`.\n\n**Este repositorio debe ser PRIVADO.**\n\nPara restaurar: `appflowy-data-backup.sh` → «Restaurar mi información».\n' > "${REPO_DIR}/README.md"
    fi

    git -C "$REPO_DIR" add -A
    if git -C "$REPO_DIR" diff --cached --quiet; then
        msg "Sin cambios desde el último respaldo."
    else
        msg_body="Archivos: ${SNAP_FILES} · Tamaño: ${size} · Modo: ${mode_txt}"
        git_commit "${COMMIT_PREFIX} ${stamp} · ${host}" "$msg_body" || { err "No se pudo crear el commit."; return 1; }
        ok "Copia guardada localmente (${SNAP_FILES} archivos, ${size})."
    fi

    ahead="$(git -C "$REPO_DIR" rev-list --count "origin/${BRANCH}..HEAD" 2>/dev/null || echo 1)"
    if git -C "$REPO_DIR" rev-parse -q --verify "refs/remotes/origin/${BRANCH}" >/dev/null && [ "$ahead" = 0 ]; then
        state_set last_success "$(now)"
        ok "GitHub ya está al día."
        log "Respaldo sin cambios (${mode_txt})."
        return 0
    fi
    msg "Subiendo al repositorio remoto …"
    if git_remote -C "$REPO_DIR" push -q -u origin "$BRANCH" 2>&1; then
        state_set last_success "$(now)"
        ok "Respaldo subido a ${REPO_URL}"
        log "Respaldo subido: ${SNAP_FILES} archivos, ${size}, ${mode_txt}."
        return 0
    fi
    err "No se pudo subir a GitHub (la copia local queda guardada y se reintentará)."
    log "Falló la subida."
    return 6
}

# ----------------------------------------------------------------------------
# Restauración
# ----------------------------------------------------------------------------
list_backups() {   # imprime: hash|fecha|asunto (más reciente primero)
    git -C "$REPO_DIR" log --grep="^${COMMIT_PREFIX}" --date=format:'%Y-%m-%d %H:%M' \
        --format='%h|%ad|%s' -n "${1:-20}" 2>/dev/null
}

safe_data_dir() {   # evita que un error de configuración borre algo que no es de AppFlowy
    case "$DATA_DIR" in "$HOME"/*) ;; *) return 1 ;; esac
    case "${DATA_DIR##*/}" in *[Aa]pp[Ff]lowy*) return 0 ;; *) return 1 ;; esac
}

do_restore() {   # envoltorio: siempre limpia la carpeta temporal
    _do_restore "$@"
    local rc=$?
    [ -n "$_TMP" ] && rm -rf "$_TMP"
    return "$rc"
}
_do_restore() {
    local ref="${1:-}" lines n choice hash tmp pre entry name
    init_state || return 1
    check_tools || return 1
    safe_data_dir || { err "Ruta de datos no segura (${DATA_DIR}); no se restaura nada."; return 1; }

    ensure_repo || return $?
    lines="$(list_backups 20)"
    if [ -z "$lines" ]; then err "No hay respaldos en el repositorio todavía."; return 1; fi

    if [ -z "$ref" ]; then
        printf '\n%s\n' "${B}Respaldos disponibles (el 1 es el más reciente):${R}"
        n=0
        while IFS='|' read -r hash date _; do
            n=$((n + 1)); printf '   %2d) %s   %s%s%s\n' "$n" "$date" "$D" "$hash" "$R"
        done <<< "$lines"
        echo
        if [ "$INTERACTIVE" = 1 ]; then
            printf '%s' "${B}¿Cuál restaurar? [1-${n}, Enter = 1, 0 = cancelar]: ${R}"
            read -r choice || choice=""
        else
            choice=1
        fi
        [ -z "$choice" ] && choice=1
        [ "$choice" = 0 ] && { msg "Cancelado."; return 0; }
        [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ] || { err "Opción no válida."; return 1; }
        ref="$(sed -n "${choice}p" <<< "$lines" | cut -d'|' -f1)"
    fi
    git -C "$REPO_DIR" rev-parse -q --verify "${ref}^{commit}" >/dev/null || { err "No existe el respaldo «${ref}»."; return 1; }
    git -C "$REPO_DIR" cat-file -e "${ref}:${SNAPSHOT_DIR_NAME}" 2>/dev/null || { err "Ese commit no contiene datos de AppFlowy."; return 1; }

    while appflowy_running; do
        warn "AppFlowy está abierto: ciérralo antes de restaurar."
        [ "$INTERACTIVE" = 1 ] || return 7
        ask_yes_no "¿Ya lo cerraste? (n = cancelar)" S || { msg "Cancelado."; return 0; }
    done

    warn "Se reemplazarán los datos actuales de AppFlowy (${DATA_DIR}) por el respaldo ${ref}."
    # --yes es una orden explícita de restaurar; sin él (y sin terminal) se cancela por seguridad
    if [ "$ASSUME_YES" != 1 ]; then ask_yes_no "¿Continuar?" N || { msg "Cancelado. No se tocó nada."; return 0; }; fi

    # Copia de seguridad de lo que hay ahora, por si acaso
    if [ -d "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        mkdir -p "${STATE_DIR}/pre-restore"
        pre="${STATE_DIR}/pre-restore/antes-de-restaurar-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"
        tar -C "$DATA_DIR" -czf "$pre" . || { err "No se pudo guardar tu estado actual; no se restaura nada."; rm -f "$pre"; return 1; }
        ok "Estado actual guardado en: ${pre}"
    fi

    tmp="$(mktemp -d "${STATE_DIR}/restore.XXXXXX")" || return 1
    _TMP="$tmp"
    git -C "$REPO_DIR" archive "$ref" "$SNAPSHOT_DIR_NAME" | tar -x -C "$tmp" || { err "No se pudo extraer el respaldo."; return 1; }
    [ -d "${tmp}/${SNAPSHOT_DIR_NAME}" ] || { err "El respaldo está vacío."; return 1; }

    mkdir -p "$DATA_DIR"
    for entry in "$DATA_DIR"/* "$DATA_DIR"/.[!.]*; do
        [ -e "$entry" ] || continue
        name="${entry##*/}"
        [ "$name" = "shared_preferences.json" ] && [ "$INCLUDE_PREFERENCES" != 1 ] && continue   # tu sesión se conserva
        rm -rf -- "$entry"
    done
    cp -a "${tmp}/${SNAPSHOT_DIR_NAME}/." "$DATA_DIR/" || { err "Falló la copia de restauración."; return 1; }

    if command -v sqlite3 >/dev/null 2>&1; then
        while IFS= read -r -d '' entry; do
            [ "$(sqlite3 "$entry" 'PRAGMA integrity_check;' 2>/dev/null)" = "ok" ] || warn "Revisa la base de datos ${entry#"${DATA_DIR}"/}: no pasó la comprobación de integridad."
        done < <(find "$DATA_DIR" -type f -name '*.db' -print0)
    fi
    ok "Restauración completada. Abre AppFlowy para ver tu información."
    log "Restaurado el respaldo ${ref}."
    return 0
}

# ----------------------------------------------------------------------------
# Daemon
# ----------------------------------------------------------------------------
backup_due() {
    local last next t
    last="$(state_get last_success 0)"; next="$(state_get next_try 0)"; t="$(now)"
    [ $((t - last)) -ge "$INTERVAL_SECONDS" ] && [ "$t" -ge "$next" ]
}

run_scheduled() {
    local last due_since t rc fails delay
    t="$(now)"; last="$(state_get last_success 0)"; due_since=$((last + INTERVAL_SECONDS))
    HOT_COPY=0
    if [ ! -d "$DATA_DIR" ] || [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        [ "$(state_get no_data_logged 0)" = 1 ] || log "Aún no hay datos de AppFlowy en ${DATA_DIR}: espero a que los haya."
        state_set no_data_logged 1
        return 0
    fi
    state_set no_data_logged 0
    if appflowy_running; then
        if [ $((t - due_since)) -lt "$WAIT_RUNNING_SECONDS" ]; then
            log "Toca respaldar, pero AppFlowy está abierto: espero a que se cierre."
            return 0
        fi
        log "AppFlowy sigue abierto pasado el plazo: copia en caliente."
        HOT_COPY=1
    fi
    log "Iniciando respaldo programado."
    with_lock do_backup auto; rc=$?
    case "$rc" in
        0)  state_set fail_count 0; state_set next_try 0
            notify "Respaldo de AppFlowy" "Subido a GitHub correctamente." ;;
        75) log "Ya hay otro respaldo en curso." ;;
        7)  : ;;
        *)  fails="$(state_get fail_count 0)"; fails=$((fails + 1)); state_set fail_count "$fails"
            delay=$((3600 * (1 << (fails > 3 ? 3 : fails - 1)))); [ "$delay" -gt 21600 ] && delay=21600
            [ "$rc" = 3 ] && delay=21600
            state_set next_try $(( $(now) + delay ))
            log "Respaldo fallido (código ${rc}); reintento en $((delay / 3600)) h."
            if [ "$fails" = 1 ] || [ $((fails % 4)) = 0 ]; then
                if [ "$rc" = 3 ]; then notify "Respaldo de AppFlowy NO realizado" "El repositorio es público. Hazlo privado."
                else notify "Respaldo de AppFlowy falló" "Revisa: ${SELF_NAME} --status"; fi
            fi ;;
    esac
    return 0
}

daemon_loop() {
    init_state || exit 1
    trap 'kill "${SLEEP_PID:-0}" 2>/dev/null; log "Daemon detenido."; exit 0' TERM INT
    log "Daemon iniciado (respalda cada ${INTERVAL_SECONDS}s; comprueba cada ${CHECK_SECONDS}s) → ${REPO_URL}"
    msg "Daemon de respaldo de AppFlowy en marcha (Ctrl-C para detener)."
    while true; do
        backup_due && run_scheduled
        sleep "$CHECK_SECONDS" &
        SLEEP_PID=$!
        wait "$SLEEP_PID"
    done
}

# ----------------------------------------------------------------------------
# Instalación del daemon (servicio de usuario de systemd; alternativa: autoarranque de escritorio)
# ----------------------------------------------------------------------------
install_script_copy() {   # deja una copia en ~/.local/bin para ejecutarlo como «appflowy-data-backup.sh»
    local me; me="$(readlink -f "${BASH_SOURCE[0]}")"
    mkdir -p "$BIN_DIR"
    if [ "$me" != "$(readlink -f "$INSTALLED_PATH" 2>/dev/null || echo "$INSTALLED_PATH")" ]; then
        install -m 755 "$me" "$INSTALLED_PATH" || return 1
        ok "Script instalado en ${INSTALLED_PATH}"
    fi
    case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "${BIN_DIR} no está en tu PATH; abre una terminal nueva o añádelo." ;; esac
}

systemd_user_ok() { command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; }

daemon_installed() {
    [ -x "$INSTALLED_PATH" ] || return 1
    { [ -f "${UNIT_DIR}/${UNIT_NAME}" ] && systemctl --user is-enabled --quiet "$UNIT_NAME" 2>/dev/null; } \
        || [ -e "${UNIT_DIR}/default.target.wants/${UNIT_NAME}" ] \
        || [ -f "$AUTOSTART_FILE" ]
}

install_daemon() {
    install_script_copy || return 1
    mkdir -p "$UNIT_DIR"
    cat > "${UNIT_DIR}/${UNIT_NAME}" <<EOF
[Unit]
Description=Respaldo semanal de AppFlowy a GitHub (appflowy-data-backup)

[Service]
Type=simple
ExecStart=${INSTALLED_PATH} --daemon
Restart=on-failure
RestartSec=60
Nice=15
IOSchedulingClass=idle

[Install]
WantedBy=default.target
EOF
    if systemd_user_ok; then
        systemctl --user daemon-reload
        if systemctl --user enable "$UNIT_NAME" 2>/dev/null && systemctl --user restart "$UNIT_NAME" 2>/dev/null; then
            ok "Daemon activado: se respalda cada ${INTERVAL_DAYS} días (servicio de usuario ${UNIT_NAME})."
            rm -f "$AUTOSTART_FILE"
            return 0
        fi
    fi
    # Sin systemd de usuario (p. ej. otra sesión): autoarranque al iniciar el escritorio
    mkdir -p "$(dirname "$AUTOSTART_FILE")"
    cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=AppFlowy Data Backup
Comment=Respaldo semanal de AppFlowy a GitHub
Exec=${INSTALLED_PATH} --daemon
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    warn "systemd de usuario no está disponible ahora: el daemon arrancará en tu próximo inicio de sesión (autoarranque)."
    return 0
}

uninstall_daemon() {
    if systemd_user_ok; then systemctl --user disable --now "$UNIT_NAME" 2>/dev/null || true; fi
    rm -f "${UNIT_DIR}/${UNIT_NAME}" "${UNIT_DIR}/default.target.wants/${UNIT_NAME}" "$AUTOSTART_FILE"
    systemd_user_ok && systemctl --user daemon-reload 2>/dev/null
    ok "Daemon desactivado. Tus respaldos y el script no se han tocado."
}

# ----------------------------------------------------------------------------
# Estado
# ----------------------------------------------------------------------------
show_status() {
    local last next n vis daemon_txt
    last="$(state_get last_success 0)"; next="$(state_get next_try 0)"
    printf '%s\n' "${B}AppFlowy Data Backup v${VERSION}${R}"
    printf '  %-18s %s\n' "Datos:" "${DATA_DIR} ($( [ -d "$DATA_DIR" ] && human_size "$DATA_DIR" || echo 'no existe'))"
    printf '  %-18s %s\n' "Repositorio:" "$REPO_URL"
    vis="$(repo_visibility)"
    case "$vis" in
        public)  printf '  %-18s %s\n' "Visibilidad:" "${RED}PÚBLICO — no se subirá nada hasta que sea privado${R}" ;;
        private) printf '  %-18s %s\n' "Visibilidad:" "${GRN}privado${R}" ;;
        missing) printf '  %-18s %s\n' "Visibilidad:" "${YEL}el repositorio no existe o no tienes acceso${R}" ;;
        unknown) printf '  %-18s %s\n' "Visibilidad:" "${YEL}no se pudo comprobar${R}" ;;
        *)       printf '  %-18s %s\n' "Visibilidad:" "remoto que no es de GitHub (sin comprobar)" ;;
    esac
    printf '  %-18s %s\n' "Último respaldo:" "$(if [ "$last" -gt 0 ]; then date -d "@$last" '+%F %H:%M'; else echo 'ninguno'; fi) ($(ago "$last"))"
    if daemon_installed; then
        if systemd_user_ok && systemctl --user is-active --quiet "$UNIT_NAME" 2>/dev/null; then daemon_txt="${GRN}activo${R} (systemd)"
        else daemon_txt="${YEL}instalado, pendiente de arrancar${R}"; fi
    else daemon_txt="${D}no instalado${R}"; fi
    printf '  %-18s %s\n' "Daemon:" "$daemon_txt"
    printf '  %-18s %s\n' "Próximo respaldo:" "$(if [ "$last" -gt 0 ]; then date -d "@$((last + INTERVAL_SECONDS))" '+%F %H:%M'; else echo 'en cuanto el daemon pueda subirlo'; fi)"
    [ "$next" -gt "$(now)" ] && printf '  %-18s %s\n' "Reintento:" "$(date -d "@$next" '+%F %H:%M') (fallos: $(state_get fail_count 0))"
    appflowy_running && printf '  %-18s %s\n' "AppFlowy:" "abierto ahora mismo"
    if [ -d "${REPO_DIR}/.git" ]; then
        n="$(list_backups 1000 | wc -l)"
        printf '  %-18s %s\n' "Respaldos locales:" "$n (en ${REPO_DIR})"
    fi
    [ -f "$LOG_FILE" ] && { printf '  %s\n' "${D}Últimas líneas del registro (${LOG_FILE}):${R}"; tail -n 4 "$LOG_FILE" | sed 's/^/     /'; }
}

# ----------------------------------------------------------------------------
# Menú interactivo
# ----------------------------------------------------------------------------
banner() {
    printf '\n%s\n' "${MAG}══════════════════════════════════════════════════════════${R}"
    printf '%s\n'   "  ${B}APPFLOWY DATA BACKUP${R}   ${D}respaldo y restauración en GitHub${R}"
    printf '%s\n\n' "${MAG}══════════════════════════════════════════════════════════${R}"
}

pause_enter() { [ "$INTERACTIVE" = 1 ] && { printf '%s' "${D}Pulsa Enter para volver al menú…${R}"; read -r _ || true; }; }

run_backup_cli() {
    HOT_COPY=0
    with_lock do_backup manual; local rc=$?
    [ "$rc" = 75 ] && err "Ya hay otro respaldo en curso (¿el daemon?). Inténtalo en unos minutos."
    return "$rc"
}

menu() {
    local choice
    while true; do
        banner
        show_status
        printf '\n%s\n' "  ${B}¿Qué quieres hacer?${R}"
        echo "     1) Hacer una copia de seguridad ahora"
        echo "     2) Restaurar mi información"
        echo "     3) Ver los respaldos disponibles"
        echo "     4) Activar el respaldo semanal automático (daemon)"
        echo "     5) Desactivar el respaldo semanal automático"
        echo "     0) Salir"
        printf '\n%s' "${B}  Elige [0-5]: ${R}"
        read -r choice || { echo; return 0; }
        echo
        case "$choice" in
            1) run_backup_cli; pause_enter ;;
            2) with_lock do_restore ""; local rc=$?; [ "$rc" = 75 ] && err "Hay un respaldo en curso; espera a que termine."; pause_enter ;;
            3) ensure_repo && { list_backups 30 | awk -F'|' '{printf "   %s   %s\n", $2, $1}'; }; pause_enter ;;
            4) install_daemon; pause_enter ;;
            5) uninstall_daemon; pause_enter ;;
            0|q|Q|"") return 0 ;;
            *) warn "Opción no válida." ;;
        esac
    done
}

usage() {
    cat <<EOF
Uso: ${SELF_NAME} [OPCIÓN]

Sin opciones abre un menú para elegir entre hacer un respaldo o restaurar.

  --backup               Hace un respaldo ahora y lo sube a GitHub
  --hot                  Con --backup: permite copiar con AppFlowy abierto («en caliente»)
  --restore [ref]        Restaura un respaldo (el último, o el commit indicado)
  --list                 Lista los respaldos disponibles
  --status               Muestra el estado (repo, visibilidad, daemon, último respaldo)
  --install-daemon       Instala y activa el daemon (un respaldo cada ${INTERVAL_DAYS} días)
  --uninstall-daemon     Desactiva y elimina el daemon
  --daemon               Ejecuta el daemon en primer plano (lo usa systemd)
  --check-repo           Comprueba que el repositorio sea privado (código 3 si es público)
  --daemon-installed     Código 0 si el daemon está instalado
  --yes, -y              No pregunta (acepta los valores por defecto)
  --version, --help

Configuración opcional: ${CONFIG_FILE}
  REPO_URL, DATA_DIR, BRANCH, INTERVAL_DAYS, INCLUDE_PREFERENCES (variables de shell)

Repositorio: ${REPO_URL}
Datos:       ${DATA_DIR}
EOF
}

# ----------------------------------------------------------------------------
# Programa principal
# ----------------------------------------------------------------------------
main() {
    local action="menu" ref=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --backup|--run-now) action=backup ;;
            --restore) action=restore; if [ $# -gt 1 ] && [[ "$2" != -* ]]; then ref="$2"; shift; fi ;;
            --list) action=list ;;
            --status) action=status ;;
            --install-daemon) action=install ;;
            --uninstall-daemon) action=uninstall ;;
            --daemon) action=daemon ;;
            --check-repo) action=check ;;
            --daemon-installed) action=installed ;;
            --hot) ALLOW_HOT=1 ;;
            --yes|-y) ASSUME_YES=1 ;;
            --version) echo "${SELF_NAME} ${VERSION}"; exit 0 ;;
            --help|-h) usage; exit 0 ;;
            *) err "Opción desconocida: $1"; usage; exit 1 ;;
        esac
        shift
    done

    case "$action" in
        menu)
            [ "$INTERACTIVE" = 1 ] || { usage; exit 0; }
            menu ;;
        backup)    run_backup_cli; exit $? ;;
        restore)   with_lock do_restore "$ref"; exit $? ;;
        list)      ensure_repo || exit $?; list_backups 100 | awk -F'|' '{printf "%s   %s   %s\n", $1, $2, $3}' ;;
        status)    show_status ;;
        install)   install_daemon; exit $? ;;
        uninstall) uninstall_daemon ;;
        daemon)    check_tools || exit 1; daemon_loop ;;
        check)
            case "$(repo_visibility)" in
                public)  echo "PÚBLICO"; exit 3 ;;
                private) echo "privado" ;;
                missing) echo "no existe / sin acceso"; exit 5 ;;
                unknown) echo "no verificable"; exit 4 ;;
                *)       echo "remoto no GitHub" ;;
            esac ;;
        installed) daemon_installed; exit $? ;;
    esac
}

main "$@"
