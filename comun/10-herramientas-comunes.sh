#!/usr/bin/env bash
# comun/10-herramientas-comunes.sh — Funciones de herramientas que se instalan IGUAL en Ubuntu y Manjaro
#                                    (herdr CLI y App; descripciones de Neovim, lazygit y Yazi).
#
# Aquí solo se DEFINEN las funciones de verificación/instalación. Cada distro registra el ítem
# en su propio módulo (así se ejecuta en el orden correcto y con las dependencias de esa distro).

# --- herdr: dos productos independientes (se puede elegir uno, otro o ambos en la lista) ---
# CLI/TUI: binario «herdr» en ~/.local/bin (instalador oficial, verifica el SHA-256).
v_herdr() { cmd_works herdr --version; }
i_herdr() { run_remote_script https://herdr.dev/install.sh sh; }

# App de escritorio: ~/.local/share/herdr-app, enlace «herdr-app» en ~/.local/bin, entrada en el menú
# de aplicaciones e icono. Si no hay herdr-core (comando «hc»), su instalador también lo pone.
HERDR_APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/herdr-app"
v_herdr_app() {
    [ -x "${HERDR_APP_DIR}/herdr-app" ] \
        && [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/herdr-app.desktop" ]
}
i_herdr_app() { run_remote_script https://releases.herdr.dev/app/install.sh sh; }

# describe_herdr — descripciones comunes (cada distro las llama tras registrar los ítems)
describe_herdr() {
    describe herdr     "herdr para la terminal (TUI/CLI): multiplexor para lanzar y vigilar varios agentes de IA de programación (Claude Code, Codex, OpenCode…) en paneles que siguen ejecutándose aunque cierres la terminal o te desconectes. Comando: herdr"
    describe herdr-app "App de escritorio de herdr: ventana gráfica para tus terminales y agentes de IA que siguen ejecutándose, con acceso en el menú de aplicaciones. Incluye herdr-core (comando hc) para controlarla desde la terminal. Comando: herdr-app"
}

# --- Herramientas de terminal: Neovim, lazygit y Yazi ---
# Cada distro las instala a su manera (Manjaro: repos oficiales · Ubuntu: releases oficiales de
# GitHub, porque apt trae un Neovim antiguo y no tiene lazygit ni Yazi). La descripción es común.
describe_terminal_tools() {
    describe neovim  "Editor de texto modal en la terminal, sucesor moderno de Vim: rápido, extensible con plugins en Lua y con LSP integrado (autocompletado, diagnósticos, ir a definición). Comando: nvim"
    describe lazygit "Interfaz visual para Git dentro de la terminal: añadir cambios por archivo o por línea, commits, ramas, stash, rebase y resolver conflictos con atajos de teclado. Comando: lazygit"
    describe yazi    "Gestor de archivos para la terminal, muy rápido (Rust y E/S asíncrona): navega carpetas con el teclado y previsualiza imágenes, PDF, vídeos y código. Comando: yazi"
}

# --- Neovim como editor de código: LazyVim (nvim/ del repositorio) ---
# nvim/ es el starter oficial de LazyVim (github.com/LazyVim/starter) con:
#   · extras activados en lua/config/lazy.lua: neo-tree, TypeScript, Tailwind, JSON, ESLint y Prettier
#   · lua/plugins/aspecto.lua: tema VS Code, inicio «NEOVIM» con menú f/n/g/r/p/q y neo-tree con
#     pestañas File/Buffers/Git que se abre solo al iniciar sin archivos
# Si ya había OTRA configuración, se mueven a «.bak-<fecha>» ~/.config/nvim y también los datos,
# estado y caché de Neovim (como recomienda LazyVim), para poder volver atrás.
# lazy-lock.json y lazyvim.json los genera LazyVim en tu equipo y no se comparan.
NVIM_CFG_SRC="${SCRIPT_DIR}/nvim"
NVIM_CFG_DST="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
NVIM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
NVIM_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"
# Diccionario de español para el corrector (spelllang = es,en en nvim/lua/config/options.lua).
# Sin él, LazyVim subraya como error todo el texto en español de los Markdown.
NVIM_SPELL_DIR="${NVIM_DATA_DIR}/site/spell"
NVIM_SPELL_URL="https://ftp.nluug.nl/pub/vim/runtime/spell"

nvim_config_same() {
    local f
    while IFS= read -r f; do
        cmp -s "${NVIM_CFG_SRC}/${f}" "${NVIM_CFG_DST}/${f}" || return 1
    done < <(cd "$NVIM_CFG_SRC" && find . -type f -printf '%P\n')
}
v_nvim_config() {
    nvim_config_same && [ -d "${NVIM_DATA_DIR}/lazy/LazyVim" ] \
        && [ -d "${NVIM_DATA_DIR}/lazy/snacks.nvim" ] && [ -d "${NVIM_DATA_DIR}/lazy/neo-tree.nvim" ] \
        && [ -s "${NVIM_SPELL_DIR}/es.utf-8.spl" ] && has_cmd npm
}
i_nvim_config() {
    has_cmd nvim || { error "Neovim (comando nvim) no está disponible."; return 1; }
    refresh_env
    # Extras que pide LazyVim: tree-sitter (compila el resaltado) y Nerd Font (iconos). Mason
    # instala con npm los servidores de TypeScript, ESLint, Tailwind y JSON: sin él fallan con
    # «Could not find executable npm». npm viene del ítem nodejs (Manjaro) o nvm-node (Ubuntu).
    # Ubuntu usa la CascadiaCode Nerd Font (ítem fuente-cascadia).
    has_cmd npm || { error "npm no está disponible: Mason no podría instalar los servidores de JS/TS."; return 1; }
    case "$DISTRO_ID" in
        manjaro) pkg_install tree-sitter-cli ttf-jetbrains-mono-nerd ;;
        ubuntu)
            if ! has_cmd tree-sitter; then
                if has_cmd npm; then npm install -g tree-sitter-cli
                else warn "Sin npm no se instala tree-sitter-cli: LazyVim avisará en :checkhealth."
                fi
            fi ;;
    esac
    if [ -e "$NVIM_CFG_DST" ] && ! nvim_config_same; then
        local d ts; ts="$(date +%Y%m%d-%H%M%S)"
        for d in "$NVIM_CFG_DST" "$NVIM_DATA_DIR" "$NVIM_STATE_DIR" "$NVIM_CACHE_DIR"; do
            [ -e "$d" ] || continue
            info "Respaldando ${d} en ${d}.bak-${ts}"
            mv "$d" "${d}.bak-${ts}"
        done
    fi
    mkdir -p "$NVIM_CFG_DST"
    cp -r "${NVIM_CFG_SRC}/." "$NVIM_CFG_DST/"
    local f
    mkdir -p "$NVIM_SPELL_DIR"
    for f in es.utf-8.spl es.utf-8.sug; do
        [ -s "${NVIM_SPELL_DIR}/${f}" ] && continue
        download "${NVIM_SPELL_URL}/${f}" "${NVIM_SPELL_DIR}/${f}" \
            || warn "No se pudo descargar el diccionario ${f}: Neovim lo pedirá al abrir un Markdown."
    done
    info "Descargando LazyVim y sus plugins…"
    nvim --headless "+Lazy! sync" +qa
}
describe_nvim_config() {
    describe nvim-config "Convierte Neovim en un editor de código con LazyVim: inicio con menú, árbol de archivos con pestañas File/Buffers/Git, pestañas, barra de estado, tema VS Code, resaltado, autocompletado, LSP, ESLint y Prettier para TypeScript/React y Tailwind. Atajos: Espacio e (árbol), Espacio Espacio (archivos), Espacio / (texto). Respalda tu configuración anterior en ~/.config/nvim.bak-<fecha>."
}

# --- Claude: app de escritorio y CLI son ítems independientes (uno, otro o ambos) ---
describe_claude() {
    describe claude-code    "Claude Code para la terminal: agente de programación de Anthropic que entiende tu proyecto, edita archivos, ejecuta comandos y hace commits desde la línea de comandos. Comando: claude"
    describe claude-desktop "App de escritorio de Claude: Chat, Cowork y Claude Code en ventanas, con sesiones en paralelo, revisión visual de cambios, terminal y editor integrados y vista previa de apps. Comando: claude-desktop"
}

# --- Editores e IDEs (se eligen en la lista principal junto a todo lo demás) ---
describe_editors() {
    describe antigravity "IDE de Google con agentes de IA (Gemini) que planifican, escriben y prueban código por ti; basado en VS Code. Comando: antigravity"
    describe cursor      "Editor de código con IA integrada (basado en VS Code): autocompletado inteligente, chat sobre tu proyecto y agentes que editan varios archivos. Comando: cursor"
    describe vscode      "Visual Studio Code de Microsoft: editor ligero y muy extensible, con depurador, terminal, Git integrado y miles de extensiones. Comando: code"
}

# --- Docker sin sudo (pasos post-instalación oficiales de Docker) ---
# Grupo «docker» con tu usuario, ~/.docker de tu propiedad (si se creó con sudo da «permission
# denied») y Docker + containerd arrancando con el sistema. El grupo se aplica en la próxima sesión.
v_docker_sin_sudo() {
    getent group docker >/dev/null 2>&1 || return 1
    user_in_group_file docker || return 1
    if [ -e "$HOME/.docker" ] && [ -n "$(find "$HOME/.docker" ! -user "$USER" -print -quit 2>/dev/null)" ]; then
        return 1
    fi
    service_enabled docker.service
}
i_docker_sin_sudo() {
    getent group docker >/dev/null 2>&1 || sudo groupadd docker
    sudo usermod -aG docker "$USER"
    if [ -e "$HOME/.docker" ]; then
        sudo chown -R "$USER":"$USER" "$HOME/.docker"
        chmod -R g+rwx "$HOME/.docker"
    fi
    sudo systemctl enable --now docker.service
    if systemctl list-unit-files containerd.service >/dev/null 2>&1; then
        sudo systemctl enable containerd.service || true
    fi
}
describe_docker() {
    describe docker          "Motor de contenedores: empaqueta y ejecuta aplicaciones aisladas con todas sus dependencias. Incluye Compose (varios servicios con un docker-compose.yml) y Buildx."
    describe docker-sin-sudo "Configura Docker para usarlo SIN sudo: añade tu usuario al grupo docker, corrige los permisos de ~/.docker y arranca Docker con el sistema. Se aplica al volver a iniciar sesión (o con newgrp docker)."
}

# --- Espanso: expansor de texto (variante Wayland o X11 según la sesión gráfica) ---
# espanso_flavor → wayland | x11 (si no hay sesión gráfica, Wayland: el predeterminado de Ubuntu y Manjaro)
espanso_flavor() {
    case "${XDG_SESSION_TYPE:-}" in
        x11)     echo x11; return ;;
        wayland) echo wayland; return ;;
    esac
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then echo wayland
    elif [ -n "${DISPLAY:-}" ]; then echo x11
    else echo wayland
    fi
}
ESPANSO_UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/espanso.service"
v_espanso() { cmd_works espanso --version && [ -f "$ESPANSO_UNIT" ]; }

# Tras instalar el paquete: permisos en Wayland, servicio de usuario e inicio
espanso_setup() {
    local bin
    bin="$(command -v espanso)" || { error "No se encontró el comando espanso."; return 1; }
    if [ "$(espanso_flavor)" = wayland ]; then
        # En Wayland espanso lee el teclado directamente: necesita esta capacidad (hay que repetirlo
        # tras cada actualización de espanso)
        sudo setcap "cap_dac_override+p" "$bin"
    fi
    espanso service register
    espanso start >/dev/null 2>&1 || warn "Espanso se iniciará al entrar en tu sesión gráfica."
}
describe_espanso() {
    describe espanso "Expansor de texto: escribe un atajo (p. ej. :fecha o :firma) y se reemplaza al instante por el texto que definas, en cualquier aplicación. Se configura en ~/.config/espanso/match/base.yml. Comando: espanso"
}

# --- Status line de Claude Code (claude/statusline.py del repositorio) ---
# Se COPIA a ~/.claude (no un enlace) para que siga funcionando si borras esta carpeta, y se activa
# en ~/.claude/settings.json sin tocar el resto de ajustes (con copia de seguridad).
CLAUDE_SL_SRC="${SCRIPT_DIR}/claude/statusline.py"
CLAUDE_SL_DST="${HOME}/.claude/statusline.py"
v_claude_statusline() {
    has_cmd python3 && [ -x "$CLAUDE_SL_DST" ] && cmp -s "$CLAUDE_SL_SRC" "$CLAUDE_SL_DST" \
        && python3 "${SCRIPT_DIR}/claude/instalar-statusline.py" --comprobar
}
ensure_python3() {
    has_cmd python3 && return 0
    case "$DISTRO_ID" in
        ubuntu)  pkg_install python3 ;;
        manjaro) pkg_install python ;;
    esac
}
i_claude_statusline() {
    ensure_python3
    mkdir -p "${HOME}/.claude"
    install -m 755 "$CLAUDE_SL_SRC" "$CLAUDE_SL_DST"
    python3 "${SCRIPT_DIR}/claude/instalar-statusline.py" --instalar
    # Prueba con datos de ejemplo: si el script falla, que falle la instalación
    echo '{"model":{"display_name":"Prueba"},"context_window":{"context_window_size":200000,"used_percentage":5}}' \
        | COLUMNS=100 python3 "$CLAUDE_SL_DST" >/dev/null
}
describe_claude_statusline() {
    describe claude-statusline "Barra de estado para Claude Code en la terminal: usuario@equipo, carpeta y estado de git; modelo y contexto usado con barra; y los límites de 5 horas y semanal con barras de color y hora de reinicio. Se activa en ~/.claude/settings.json (con copia de seguridad)."
}

# --- Ahorro de tokens en Claude Code: uv, Serena y ajustes globales ---
# Todo se escribe con claude/configurar-claude.py, que fusiona sin borrar tus ajustes y hace copia
# de seguridad de ~/.claude/settings.json antes de cambiarlo.
CLAUDE_CFG_PY="${SCRIPT_DIR}/claude/configurar-claude.py"
CLAUDE_PROYECTO_SRC="${SCRIPT_DIR}/claude/claude-proyecto.sh"
CLAUDE_PROYECTO_DST="${HOME}/.local/bin/claude-proyecto"

# uv (gestor de Python de Astral): Serena se instala y actualiza con él.
# Ubuntu: instalador oficial → ~/.local/bin (sin tocar los rc: el PATH lo gestiona este instalador).
# Manjaro: paquete «uv» del repo oficial (se registra con register_pkg).
v_uv() { cmd_works uv --version; }
i_uv() { UV_NO_MODIFY_PATH=1 run_remote_script https://astral.sh/uv/install.sh sh; }

# Serena: MCP que indexa el código con servidores de lenguaje (LSP) para que Claude lea símbolos
# concretos en vez de archivos completos. Se registra para TODOS los proyectos (--scope user) con
# --project-from-cwd: al abrir «claude» en una carpeta, Serena trabaja sobre ese proyecto.
# El panel web no se abre solo (--open-web-dashboard False). Además se añaden los hooks
# recomendados por Serena (remind/activate/cleanup) y MCP_TIMEOUT=60000.
SERENA_MCP_ARGS=(start-mcp-server --context claude-code --project-from-cwd --open-web-dashboard False)
v_serena() {
    cmd_works serena --help || return 1
    has_cmd serena-hooks || return 1
    python3 "$CLAUDE_CFG_PY" --comprobar-serena
}
i_serena() {
    has_cmd uv     || { error "uv no está disponible."; return 1; }
    has_cmd claude || { error "Claude Code (comando claude) no está disponible."; return 1; }
    ensure_python3
    # --force: reinstala limpio si una instalación anterior quedó rota
    uv tool install --force -p 3.13 serena-agent
    refresh_env
    local bin hooks
    bin="$(command -v serena)"        || { error "No se encontró el comando serena tras instalarlo."; return 1; }
    hooks="$(command -v serena-hooks)" || { error "No se encontró serena-hooks tras instalarlo."; return 1; }
    # Registro limpio en Claude Code (ruta absoluta: funciona aunque el PATH del cliente sea otro)
    claude mcp remove --scope user serena >/dev/null 2>&1 || true
    claude mcp add --scope user serena -- "$bin" "${SERENA_MCP_ARGS[@]}"
    python3 "$CLAUDE_CFG_PY" --serena "$hooks"
}

# Graphify: convierte un proyecto en un grafo de conocimiento (código + documentación) que Claude
# consulta para orientarse antes de leer archivos: alcance de un cambio, piezas centrales y qué
# spec o documento menciona algo. Complementa a Serena (que lee y edita símbolos concretos).
# Se instala con uv (paquete «graphifyy»; el comando es «graphify») y deja la skill /graphify en
# ~/.claude/skills para todos los proyectos. No instala hooks: el grafo de cada proyecto se genera
# a mano con «graphify update .» (solo código, local y sin IA) o con «/graphify .» dentro de Claude.
v_graphify() {
    cmd_works graphify --help || return 1
    [ -f "${HOME}/.claude/skills/graphify/SKILL.md" ]
}
i_graphify() {
    has_cmd uv     || { error "uv no está disponible."; return 1; }
    has_cmd claude || { error "Claude Code (comando claude) no está disponible."; return 1; }
    # --force: reinstala limpio si una instalación anterior quedó rota
    uv tool install --force -p 3.13 graphifyy
    refresh_env
    has_cmd graphify || { error "No se encontró el comando graphify tras instalarlo."; return 1; }
    graphify install --platform claude
}

# Ajustes globales de Claude Code para gastar menos tokens:
#   · ~/.claude/settings.json → permissions.deny para node_modules, dist, lockfiles, *.min.js…
#   · ~/.claude/CLAUDE.md     → bloque con pautas de ahorro (usar Serena, subagentes, salidas cortas)
#   · ~/.local/bin/claude-proyecto → prepara cada proyecto (CLAUDE.md + índice de Serena)
v_claude_ahorro() {
    [ -x "$CLAUDE_PROYECTO_DST" ] && cmp -s "$CLAUDE_PROYECTO_SRC" "$CLAUDE_PROYECTO_DST" \
        && python3 "$CLAUDE_CFG_PY" --comprobar-ahorro
}
i_claude_ahorro() {
    ensure_python3
    mkdir -p "${HOME}/.local/bin"
    install -m 755 "$CLAUDE_PROYECTO_SRC" "$CLAUDE_PROYECTO_DST"
    python3 "$CLAUDE_CFG_PY" --ahorro
}

describe_claude_tokens() {
    describe uv            "uv: gestor de paquetes y versiones de Python, muy rápido (Astral). Lo usa Serena para instalarse y actualizarse. Comandos: uv, uvx"
    describe serena        "Serena: índice de código para Claude Code (MCP con servidores de lenguaje). Claude busca funciones, clases y referencias sin leer archivos completos, y así gasta menos tokens. Queda activo en todos los proyectos con sus hooks. Comando: serena"
    describe graphify      "Graphify: grafo de conocimiento del proyecto (código y documentación) para Claude Code. Sirve para orientarse antes de leer archivos: qué toca un cambio, piezas centrales y qué documento menciona algo. Instala la skill /graphify para todos los proyectos. Comandos: graphify, graphify-mcp"
    describe claude-ahorro "Ajustes de Claude Code para ahorrar tokens: bloquea la lectura de node_modules, dist, lockfiles y minificados; añade pautas de ahorro a ~/.claude/CLAUDE.md; e instala el comando claude-proyecto (CLAUDE.md + índice de Serena por proyecto)."
}

# Paso manual al terminar: cada proyecto se prepara una vez con claude-proyecto
post_claude_tokens() {
    if item_new serena || item_new claude-ahorro; then
        add_manual_step "Claude Code + Serena: en cada proyecto ejecuta ${BOLD}claude-proyecto${RESET} una vez (crea CLAUDE.md e indexa el código) y luego abre ${BOLD}claude${RESET} ahí. Comprueba con ${BOLD}/mcp${RESET} que «serena» aparece conectado. Guía: GUIA-DE-USO.md, sección 13."
    fi
}
