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
i_claude_statusline() {
    if ! has_cmd python3; then
        case "$DISTRO_ID" in
            ubuntu)  pkg_install python3 ;;
            manjaro) pkg_install python ;;
        esac
    fi
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
