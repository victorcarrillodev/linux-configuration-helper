#!/usr/bin/env bash
# lib/core.sh — Motor del instalador.
#
# Cada programa/configuración es un "ítem" con dos funciones:
#   verify  → ¿está realmente instalado y funcionando?  (solo lectura)
#   install → lo instala                                (se ejecuta con 'set -e')
# El motor audita lo que ya existe, instala solo lo pendiente, verifica el
# resultado, diagnostica los fallos, repara el gestor de paquetes y reintenta.

[ -n "${CORE_LOADED:-}" ] && return 0
CORE_LOADED=1

MAX_RETRIES="${MAX_RETRIES:-3}"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
RC_SKIP=10      # un instalador devuelve esto cuando "no aplica" a este equipo

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/new-linux-conf"
LOG_FILE=""

# --- Catálogo -----------------------------------------------------------------
ITEM_IDS=()
ACTIVE_IDS=()
SECTION_IDS=()
CURRENT_SECTION=""
MANUAL_STEPS=()
POST_HOOKS=()
declare -A ITEM_LABEL ITEM_VERIFY ITEM_INSTALL ITEM_SECTION ITEM_DEPS
declare -A ITEM_STATUS ITEM_NOTE ITEM_INDEX ITEM_PRE
declare -A SECTION_NAME SECTION_DESC
declare -A PKG_SRC PKG_CMD PKG_LIST NPM_PKG NPM_CMD

# ---------------------------------------------------------------------------
# Registro y log
# ---------------------------------------------------------------------------
init_log() {
    mkdir -p "$STATE_DIR"
    LOG_FILE="${STATE_DIR}/instalacion-$(date +%Y%m%d-%H%M%S).log"
    : > "$LOG_FILE"
    log "Inicio · sistema=${DISTRO_ID:-?} destino=${INSTALL_TARGET:-?} usuario=${USER:-?} simulación=${DRY_RUN}"
}

log() {
    [ -n "$LOG_FILE" ] && printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >> "$LOG_FILE"
    return 0
}

# section <número> <NOMBRE GRANDE> [descripción] — agrupa los ítems que se registren después
section() {
    CURRENT_SECTION="$1"
    SECTION_IDS+=("$1")
    SECTION_NAME[$1]="$2"
    SECTION_DESC[$1]="${3:-}"
}

# register_item <id> "<etiqueta>" <verify|-> <install> [dependencias…]
# verify "-" = tarea que se ejecuta siempre (no hay forma de comprobarla de antemano)
register_item() {
    local id="$1" label="$2" verify="$3" install="$4"
    shift 4
    ITEM_IDS+=("$id")
    ITEM_LABEL[$id]="$label"
    ITEM_VERIFY[$id]="$verify"
    ITEM_INSTALL[$id]="$install"
    ITEM_SECTION[$id]="$CURRENT_SECTION"
    ITEM_DEPS[$id]="$*"
}

# register_pkg <id> "<etiqueta>" <repo|aur> <comando|""> <paquete…>
# Ítem genérico de paquete. Si hay comando, se verifica con él ("cmd!" = además ejecuta --version).
register_pkg() {
    local id="$1" label="$2" src="$3" cmd="$4"
    shift 4
    PKG_SRC[$id]="$src"; PKG_CMD[$id]="$cmd"; PKG_LIST[$id]="$*"
    register_item "$id" "$label" v_pkg i_pkg
}

# register_aur <id> "<etiqueta>" <comando|""> <paquete…> — paquete de AUR (depende de yay)
register_aur() {
    local id="$1"
    shift
    register_pkg "$id" "$1" aur "$2" "${@:3}"
    ITEM_DEPS[$id]="yay"
}

v_pkg() {
    local id="$1" cmd="${PKG_CMD[$1]}"
    if [ -n "$cmd" ]; then
        case "$cmd" in
            *'!') cmd_works "${cmd%!}" --version ;;
            *)    has_cmd "$cmd" ;;
        esac
    else
        # shellcheck disable=SC2086
        pkgs_installed ${PKG_LIST[$id]}
    fi
}

i_pkg() {
    local id="$1"
    # shellcheck disable=SC2086
    case "${PKG_SRC[$id]}" in
        aur) aur_install ${PKG_LIST[$id]} ;;
        *)   pkg_install ${PKG_LIST[$id]} ;;
    esac
}

# register_npm <id> "<etiqueta>" <comando> <paquete-npm> [dependencias…]
# Paquete global de npm (necesita Node: la dependencia la indica cada distro).
register_npm() {
    local id="$1" label="$2" cmd="$3" pkg="$4"
    shift 4
    NPM_CMD[$id]="$cmd"; NPM_PKG[$id]="$pkg"
    register_item "$id" "$label" v_npm i_npm "$@"
}

v_npm() { cmd_works "${NPM_CMD[$1]}" --version; }

i_npm() {
    has_cmd npm || { error "npm no está disponible (falta Node.js)."; return 1; }
    npm install -g "${NPM_PKG[$1]}"
}

register_post() { POST_HOOKS+=("$1"); }

add_manual_step() {
    local s
    for s in "${MANUAL_STEPS[@]:-}"; do [ "$s" = "$1" ] && return 0; done
    MANUAL_STEPS+=("$1")
}

item_ok()  { case "${ITEM_STATUS[$1]:-}" in ok|present) return 0 ;; esac; return 1; }
item_new() { [ "${ITEM_STATUS[$1]:-}" = ok ]; }   # instalado en ESTA ejecución

# ---------------------------------------------------------------------------
# Ganchos del gestor de paquetes (cada distro los redefine en su distro.sh)
# ---------------------------------------------------------------------------
pkg_lock_busy()  { return 1; }
pkg_unlock()     { return 0; }
pkg_refresh()    { return 0; }
pkg_repair()     { return 0; }
pkg_fix_keys()   { return 0; }
pkg_clean()      { return 0; }

# ---------------------------------------------------------------------------
# Sudo
# ---------------------------------------------------------------------------
SUDO_KEEPALIVE_PID=""

start_sudo() {
    [ "$DRY_RUN" = 1 ] && return 0
    info "Se necesitan permisos de administrador (sudo)…"
    sudo -v || { error "No se obtuvieron permisos de sudo."; exit 1; }
    # Mantener la sesión de sudo viva mientras dure el instalador
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
}

stop_sudo() {
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    SUDO_KEEPALIVE_PID=""
    return 0
}

# ---------------------------------------------------------------------------
# Verificación, diagnóstico y reparación
# ---------------------------------------------------------------------------
# run_verify <id> → 0 instalado · 1 pendiente · 2 tarea sin verificación
run_verify() {
    local v="${ITEM_VERIFY[$1]}"
    [ "$v" = "-" ] && return 2
    ( refresh_env; "$v" "$1" ) >/dev/null 2>&1 && return 0
    return 1
}

# ¿Se puede considerar disponible la dependencia?
dep_ok() {
    local d="$1"
    case "${ITEM_STATUS[$d]:-}" in
        ok|present|simulated) return 0 ;;
        failed|skipped) return 1 ;;
    esac
    [ -n "${ITEM_VERIFY[$d]:-}" ] || return 1
    run_verify "$d"
}

# Clasifica la causa probable de un fallo mirando la salida del intento
classify_failure() {
    local f="$1"
    if grep -qiE 'could not get lock|unable to acquire the dpkg|unable to lock|dpkg frontend lock|waiting for cache lock|db\.lck|another app is currently holding' "$f"; then echo lock; return; fi
    if grep -qiE 'could not resolve|temporary failure|hash sum mismatch|connection failed|network is down|network is unreachable|connection timed out|failed to connect|connection refused|ssl connect|curl: \((6|7|28|35|56)\)|unable to connect|could not connect|failed retrieving file|failed to fetch|timeout was reached|early eof' "$f"; then echo network; return; fi
    if grep -qiE 'no_pubkey|signature (from|is|of)|invalid or corrupted package|pgp|keyring|not signed|badsig|gpg: ' "$f"; then echo keys; return; fi
    if grep -qiE 'no space left|disk full|not enough free disk' "$f"; then echo space; return; fi
    if grep -qiE 'unable to locate package|target not found|database file for .* does not exist|has no installation candidate|404 +not found|e: failed to fetch|error: failed to prepare transaction' "$f"; then echo notfound; return; fi
    echo unknown
}

kind_text() {
    case "$1" in
        lock)     echo "otro gestor de paquetes está en uso (bloqueo)" ;;
        network)  echo "problema de red / descarga" ;;
        keys)     echo "claves o firmas de paquetes" ;;
        space)    echo "poco espacio en disco" ;;
        notfound) echo "paquete no encontrado (índices desactualizados)" ;;
        *)        echo "error no clasificado" ;;
    esac
}

wait_for_pkg_lock() {
    local waited=0
    while pkg_lock_busy && [ "$waited" -lt 120 ]; do
        warn "Otro proceso usa el gestor de paquetes; esperando 5 s…"
        sleep 5
        waited=$((waited + 5))
    done
    pkg_unlock
}

# Acción correctiva según la causa del fallo
repair_after_failure() {
    local kind="$1" attempt="$2"
    case "$kind" in
        lock)     wait_for_pkg_lock ;;
        network)  wait_for_network 90 || warn "Sigue sin haber conexión a internet." ;;
        keys)     pkg_fix_keys ;;
        space)    warn "Poco espacio en disco: liberando la caché de paquetes…"; pkg_clean; df -h / "$HOME" 2>/dev/null | sed 's/^/   /' ;;
        notfound) pkg_refresh ;;
    esac
    # A partir del segundo intento, reparación general del gestor de paquetes
    [ "$attempt" -ge 2 ] && pkg_repair
    return 0
}

# ---------------------------------------------------------------------------
# Ejecución de un ítem
# ---------------------------------------------------------------------------
# Línea más informativa del último intento: la última que parezca un error (sin las de "ver el log"); si no, la última
_last_error_line() {
    local clean line
    clean="$(sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$1" 2>/dev/null | grep -v '^[[:space:]]*$')"
    line="$(grep -iE 'error|fail|^E:|cannot|can.t |unable|not found|denied|no such|refused|could not' <<< "$clean" \
            | grep -viE 'complete log|debug-[0-9]+\.log|^npm notice' | tail -1)"
    [ -n "$line" ] || line="$(tail -1 <<< "$clean")"
    cut -c1-150 <<< "$line"
}

run_item() {
    local id="$1" n="$2" total="$3"
    local label="${ITEM_LABEL[$id]}" install="${ITEM_INSTALL[$id]}" verify="${ITEM_VERIFY[$id]}"
    local d missing="" attempt=1 rc kind tmp verified

    item_title "$n" "$total" "$label"
    log "ITEM ${id}: ${label}"

    # 1) Dependencias
    for d in ${ITEM_DEPS[$id]}; do
        dep_ok "$d" || missing+="${ITEM_LABEL[$d]:-$d}, "
    done
    if [ -n "$missing" ]; then
        missing="${missing%, }"
        warn "Se omite: depende de «${missing}», que no está disponible."
        ITEM_STATUS[$id]=skipped; ITEM_NOTE[$id]="depende de ${missing}"
        log "  omitido (dependencia: ${missing})"
        pause_after_item
        return 0
    fi

    # 2) ¿Ya está instalado? (verificación real, no solo "existe el archivo")
    if [ "$verify" != "-" ] && run_verify "$id"; then
        success "Ya está instalado/configurado y verificado — se omite."
        ITEM_STATUS[$id]=present
        log "  ya instalado"
        pause_after_item
        return 0
    fi

    # 3) Simulación
    if [ "$DRY_RUN" = 1 ]; then
        info "[simulación] se ejecutaría: ${label}"
        ITEM_STATUS[$id]=simulated
        return 0
    fi

    # 4) Instalar → verificar → (si falla) diagnosticar, reparar y reintentar
    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        info "Instalando… (intento ${attempt}/${MAX_RETRIES})"
        tmp="$(mktemp "${STATE_DIR}/intento.XXXXXX")"
        ( refresh_env; set -e; "$install" "$id" ) 2>&1 | tee "$tmp"
        rc=${PIPESTATUS[0]}
        cat "$tmp" >> "$LOG_FILE"
        refresh_env

        if [ "$rc" -eq "$RC_SKIP" ]; then
            ITEM_STATUS[$id]=skipped
            ITEM_NOTE[$id]="no aplica a este equipo"
            rm -f "$tmp"
            break
        fi

        verified=1
        if [ "$verify" = "-" ]; then
            [ "$rc" -eq 0 ] && verified=0
        else
            run_verify "$id" && verified=0
        fi

        if [ "$verified" -eq 0 ]; then
            [ "$rc" -ne 0 ] && warn "Verificado correctamente, aunque el instalador devolvió avisos (código ${rc})."
            ITEM_STATUS[$id]=ok
            rm -f "$tmp"
            break
        fi

        # Falló
        kind="$(classify_failure "$tmp")"
        ITEM_NOTE[$id]="$(_last_error_line "$tmp")"
        rm -f "$tmp"
        error "La instalación no se pudo verificar (intento ${attempt}/${MAX_RETRIES}). Causa probable: $(kind_text "$kind")."
        log "  fallo intento ${attempt}: ${kind} · ${ITEM_NOTE[$id]}"
        if [ "$attempt" -lt "$MAX_RETRIES" ]; then
            info "Revisando y reparando antes de reintentar…"
            repair_after_failure "$kind" "$attempt"
            sleep $((attempt * 3))
        fi
        attempt=$((attempt + 1))
    done

    [ -z "${ITEM_STATUS[$id]:-}" ] && ITEM_STATUS[$id]=failed

    echo
    case "${ITEM_STATUS[$id]}" in
        ok)      printf '%s\n' "${BG_GREEN}${BOLD}${WHITE}  ✔ INSTALADO Y VERIFICADO  ${RESET} ${label}" ;;
        skipped) printf '%s\n' "${YELLOW}${BOLD}  ○ OMITIDO${RESET} ${label} — ${ITEM_NOTE[$id]}" ;;
        failed)  printf '%s\n' "${RED}${BOLD}  ✘ FALLÓ tras ${MAX_RETRIES} intentos:${RESET} ${label}" ;;
    esac
    log "  resultado: ${ITEM_STATUS[$id]}"
    pause_after_item
}

# ---------------------------------------------------------------------------
# Auditoría previa y plan de ejecución
# ---------------------------------------------------------------------------
# Muestra qué hay ya instalado de la lista y qué falta
audit_items() {
    local sec id rc shown pending=0 installed=0 tasks=0
    section_title "AUDITORIA" "Comprobando qué de la lista ya está instalado y funcionando"
    for sec in "${SECTION_IDS[@]}"; do
        shown=0
        for id in "${ACTIVE_IDS[@]}"; do
            [ "${ITEM_SECTION[$id]}" = "$sec" ] || continue
            if [ "$shown" = 0 ]; then
                printf '%s\n' "  ${BOLD}${WHITE}${sec} · ${SECTION_NAME[$sec]}${RESET}"
                shown=1
            fi
            run_verify "$id"; rc=$?
            case "$rc" in
                0) ITEM_PRE[$id]=installed; installed=$((installed + 1))
                   printf '%s\n' "     ${GREEN}✔${RESET} ${ITEM_LABEL[$id]}" ;;
                1) ITEM_PRE[$id]=pending; pending=$((pending + 1))
                   printf '%s\n' "     ${RED}✘${RESET} ${ITEM_LABEL[$id]} ${DIM}— pendiente${RESET}" ;;
                *) ITEM_PRE[$id]=task; tasks=$((tasks + 1))
                   printf '%s\n' "     ${YELLOW}○${RESET} ${ITEM_LABEL[$id]} ${DIM}— tarea (se ejecuta siempre)${RESET}" ;;
            esac
        done
        [ "$shown" = 1 ] && echo
    done
    hr
    printf '%s\n' "  ${GREEN}${installed} ya instalados${RESET}  ·  ${RED}${pending} pendientes${RESET}  ·  ${YELLOW}${tasks} tareas${RESET}"
    hr
    log "Auditoría: ${installed} instalados, ${pending} pendientes, ${tasks} tareas"
}

# Ejecuta todos los ítems activos, sección por sección, y reintenta lo que falló
execute_plan() {
    local total=${#ACTIVE_IDS[@]} n=0 id cur="" failed=() saved

    for id in "${ACTIVE_IDS[@]}"; do
        n=$((n + 1)); ITEM_INDEX[$id]=$n
        if [ "${ITEM_SECTION[$id]}" != "$cur" ]; then
            cur="${ITEM_SECTION[$id]}"
            section_title "${SECTION_NAME[$cur]}" "${SECTION_DESC[$cur]}"
        fi
        run_item "$id" "$n" "$total"
    done

    [ "$DRY_RUN" = 1 ] && return 0

    for id in "${ACTIVE_IDS[@]}"; do
        [ "${ITEM_STATUS[$id]:-}" = failed ] && failed+=("$id")
    done
    if [ "${#failed[@]}" -gt 0 ]; then
        section_title "REVISION" "Reintentando ${#failed[@]} instalación(es) que fallaron"
        info "Reparando el gestor de paquetes antes del reintento final…"
        wait_for_network 60 || warn "Sin conexión a internet: es probable que el reintento falle."
        pkg_repair
        saved="$MAX_RETRIES"; MAX_RETRIES=2
        for id in "${failed[@]}"; do
            unset "ITEM_STATUS[$id]"
            run_item "$id" "${ITEM_INDEX[$id]}" "$total"
        done
        MAX_RETRIES="$saved"
    fi
}

# ---------------------------------------------------------------------------
# Resumen final
# ---------------------------------------------------------------------------
count_status() {
    local s="$1" id c=0
    for id in "${ACTIVE_IDS[@]}"; do [ "${ITEM_STATUS[$id]:-}" = "$s" ] && c=$((c + 1)); done
    echo "$c"
}

print_summary() {
    local sec id st rc mark text shown hook
    section_title "RESUMEN" "Verificación final de todo lo instalado"

    for sec in "${SECTION_IDS[@]}"; do
        shown=0
        for id in "${ACTIVE_IDS[@]}"; do
            [ "${ITEM_SECTION[$id]}" = "$sec" ] || continue
            if [ "$shown" = 0 ]; then
                printf '%s\n' "  ${BOLD}${WHITE}${sec} · ${SECTION_NAME[$sec]}${RESET}"
                shown=1
            fi
            st="${ITEM_STATUS[$id]:-sin_ejecutar}"
            if [ "$st" = ok ] || [ "$st" = present ]; then
                run_verify "$id"; rc=$?
                if [ "$rc" = 1 ]; then st="failed"; ITEM_STATUS[$id]=failed; ITEM_NOTE[$id]="ya no pasa la verificación final"; fi
            fi
            case "$st" in
                ok)         mark="${GREEN}✔${RESET}"
                            if [ "${ITEM_VERIFY[$id]}" = "-" ]; then text="${GREEN}ejecutado${RESET}"; else text="${GREEN}instalado ahora${RESET}"; fi ;;
                present)    mark="${GREEN}✔${RESET}"; text="${DIM}ya estaba instalado${RESET}" ;;
                skipped)    mark="${YELLOW}○${RESET}"; text="${YELLOW}omitido — ${ITEM_NOTE[$id]:-}${RESET}" ;;
                simulated)  mark="${CYAN}~${RESET}"; text="${CYAN}simulación${RESET}" ;;
                failed)     mark="${RED}✘${RESET}"; text="${RED}FALLÓ — ${ITEM_NOTE[$id]:-}${RESET}" ;;
                *)          mark="${DIM}·${RESET}"; text="${DIM}sin ejecutar${RESET}" ;;
            esac
            printf '     %s %-52s %s\n' "$mark" "${ITEM_LABEL[$id]}" "$text"
        done
        [ "$shown" = 1 ] && echo
    done
    local c_ok c_present c_skip c_fail
    c_ok="$(count_status ok)"; c_present="$(count_status present)"
    c_skip="$(count_status skipped)"; c_fail="$(count_status failed)"

    hr '═' "$MAGENTA"
    printf '%s\n' "  ${GREEN}${BOLD}${c_ok} instalados ahora${RESET}  ·  ${c_present} ya estaban  ·  ${YELLOW}${c_skip} omitidos${RESET}  ·  ${RED}${BOLD}${c_fail} con fallos${RESET}"
    hr '═' "$MAGENTA"
    echo
    log "Resumen: ok=${c_ok} presentes=${c_present} omitidos=${c_skip} fallos=${c_fail}"

    # Pasos manuales: cada módulo aporta los suyos según el estado final
    for hook in "${POST_HOOKS[@]:-}"; do [ -n "$hook" ] && "$hook"; done
    print_manual_steps

    [ "$c_fail" -eq 0 ]
}

print_manual_steps() {
    local i=1 s
    section_title "PENDIENTE" "Lo que debes hacer tú"
    if [ "${#MANUAL_STEPS[@]}" -eq 0 ]; then
        success "No necesitas hacer nada más."
    else
        for s in "${MANUAL_STEPS[@]}"; do
            printf '%s\n' "  ${BOLD}${YELLOW}${i}.${RESET} ${s}"
            echo
            i=$((i + 1))
        done
    fi
    [ -n "$LOG_FILE" ] && dim "  Registro completo: ${LOG_FILE}"
    echo
}

# ---------------------------------------------------------------------------
# Borrar el instalador (siempre se pregunta; --yes nunca borra)
# ---------------------------------------------------------------------------
offer_delete_installer() {
    local dir="$SCRIPT_DIR" dirty=0 ahead=0 st

    hr '─'
    if [ "$DRY_RUN" = 1 ]; then
        info "[simulación] aquí se preguntaría si quieres borrar el instalador (${dir})."
        return 0
    fi
    if [ "$ASSUME_YES" = 1 ]; then
        info "Modo --yes: el instalador se conserva (${dir})."
        return 0
    fi

    if ! ask_yes_no "¿Quieres BORRAR el instalador (${dir})?" N; then
        info "Instalador conservado en ${dir}"
        return 0
    fi

    # Salvaguardas: nunca borrar rutas peligrosas ni algo que no sea este proyecto
    if [ -z "$dir" ] || [ "$dir" = "/" ] || [ "$dir" = "$HOME" ] || [ ! -f "${dir}/init.sh" ]; then
        error "Ruta no segura para borrar (${dir}); no se elimina nada."
        return 1
    fi

    # Si es un repositorio git con trabajo sin subir, avisar antes
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        st="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)"
        dirty="$st"
        if git -C "$dir" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
            ahead="$(git -C "$dir" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
            if [ "$dirty" -gt 0 ] || [ "$ahead" -gt 0 ]; then
                warn "Es un repositorio git con ${dirty} cambio(s) sin guardar y ${ahead} commit(s) sin subir."
                ask_yes_no "Se perderían al borrar. ¿Borrar de todos modos?" N || { info "Instalador conservado."; return 0; }
            fi
        else
            warn "Es un repositorio git SIN remoto configurado: su historial solo existe en esta carpeta."
            ask_yes_no "Se perdería al borrar. ¿Borrar de todos modos?" N || { info "Instalador conservado."; return 0; }
        fi
    fi

    cd "$HOME" 2>/dev/null || cd /
    if rm -rf -- "$dir"; then
        success "Instalador eliminado: ${dir}"
    else
        error "No se pudo eliminar ${dir}"
        return 1
    fi
}
