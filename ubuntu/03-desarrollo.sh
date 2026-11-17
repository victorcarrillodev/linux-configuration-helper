#!/usr/bin/env bash
# ubuntu/03-desarrollo.sh — NVM + Node LTS, pnpm, Bun, PostgreSQL, Flutter, CLIs de IA, Claude Desktop, Serena,
#                           Hermes, herdr y Tailscale.

section 03 "DESARROLLO" "NVM, Node LTS, pnpm, Bun, PostgreSQL, Flutter, CLIs de IA, Claude Desktop, ahorro de tokens (Serena), herdr (CLI/App) y Tailscale"

NVM_VERSION="v0.40.3"

# --- NVM + Node LTS (si hay otras versiones se desinstalan y queda solo la LTS) ---
v_nvm_node() {
    [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ] || return 1
    cmd_works node --version && cmd_works npm --version || return 1
    # El node activo debe ser de una línea LTS
    [ -n "$(node_release_lts)" ] || return 1
    # Si se pudo saber cuál es la LTS actual del sitio oficial, debe ser exactamente esa
    local m; m="$(node_lts_major)" || return 0
    case "$(node --version 2>/dev/null)" in "v$m"*) return 0 ;; *) return 1 ;; esac
}
i_nvm_node() {
    if [ ! -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
        run_remote_script "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" bash
    fi
    # Instala la LTS vigente y la deja usando; si no se pudo saber cuál es,
    # '--lts' hace que nvm use la LTS que conozca
    local m=""
    m="$(node_lts_major 2>/dev/null)" || true
    if [ -n "${m:-}" ]; then
        nvm_cmd install "$m"
        nvm_cmd alias default "$m"
        nvm_cmd use "$m"
    else
        nvm_cmd install --lts
        nvm_cmd alias default 'lts/*'
        nvm_cmd use 'lts/*'
    fi
    # Desinstala cualquier otra versión de nvm (Current, LTS antiguas…)
    uninstall_other_nvm_versions "${m:-}"
}
register_item nvm-node "NVM + Node.js LTS" v_nvm_node i_nvm_node

# --- Paquetes globales de npm (necesitan Node; register_npm está en lib/core.sh) ---
register_npm pnpm "pnpm" pnpm pnpm nvm-node

# --- Bun ---
v_bun() { cmd_works bun --version; }
i_bun() { run_remote_script https://bun.sh/install bash; }
register_item bun "Bun" v_bun i_bun utilidades-base

# --- PostgreSQL ---
v_postgresql() { pkg_installed postgresql && has_cmd psql && service_enabled postgresql; }
i_postgresql() {
    pkg_install postgresql postgresql-contrib
    sudo systemctl enable --now postgresql
}
register_item postgresql "PostgreSQL" v_postgresql i_postgresql

# --- Flutter (snap) + dependencias de escritorio Linux ---
v_flutter() { has_cmd flutter && has_cmd snap && snap list flutter >/dev/null 2>&1; }
i_flutter() {
    has_cmd snap || { error "snapd no está instalado; Flutter se instala vía snap."; return 1; }
    pkg_install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
    sudo snap install flutter --classic
}
register_item flutter "Flutter SDK (snap) + dependencias" v_flutter i_flutter

# --- CLIs de IA ---
register_npm gemini-cli  "Gemini CLI (Google)"      gemini   "@google/gemini-cli"     nvm-node
register_npm claude-code "Claude Code CLI (terminal)" claude "@anthropic-ai/claude-code" nvm-node
register_npm codex       "Codex CLI (OpenAI)"       codex    "@openai/codex"          nvm-node
register_npm opencode    "OpenCode"                 opencode "opencode-ai"            nvm-node

# --- Claude Desktop (app oficial de Anthropic para Ubuntu 22.04+, beta, amd64/arm64) ---
# Repositorio apt oficial: las actualizaciones llegan con «apt upgrade». Antes de confiar en la
# clave se comprueba que su huella sea la que publica Anthropic.
CLAUDE_DESKTOP_KEY=/usr/share/keyrings/claude-desktop-archive-keyring.asc
CLAUDE_DESKTOP_FPR=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
v_claude_desktop() { pkg_installed claude-desktop && has_cmd claude-desktop; }
i_claude_desktop() {
    local arch tmp fpr
    arch="$(dpkg --print-architecture)"
    case "$arch" in amd64|arm64) ;; *) warn "Claude Desktop solo existe para amd64 y arm64 (este equipo: ${arch})."; return "$RC_SKIP" ;; esac
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    download https://downloads.claude.ai/claude-desktop/key.asc "$tmp"
    fpr="$(gpg --show-keys --with-colons "$tmp" 2>/dev/null | awk -F: '$1 == "fpr" { print $10 }')"
    if [ "$fpr" != "$CLAUDE_DESKTOP_FPR" ]; then
        error "La clave descargada de Anthropic no tiene la huella esperada (${fpr:-ninguna}); no se añade el repositorio."
        return 1
    fi
    sudo install -m 644 "$tmp" "$CLAUDE_DESKTOP_KEY"
    echo "deb [arch=amd64,arm64 signed-by=${CLAUDE_DESKTOP_KEY}] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
        | sudo tee /etc/apt/sources.list.d/claude-desktop.list >/dev/null
    pkg_refresh
    pkg_install claude-desktop
}
register_item claude-desktop "Claude Desktop (app de escritorio)" v_claude_desktop i_claude_desktop utilidades-base
describe_claude

# Status line de Claude Code (barras de contexto y límites de 5 h / semanal), igual en ambas distros
register_item claude-statusline "Status line de Claude Code (contexto y límites)" v_claude_statusline i_claude_statusline
describe_claude_statusline

# Ahorro de tokens: uv (instalador oficial) → Serena (índice de código, MCP) + ajustes globales de Claude Code
register_item uv            "uv (gestor de Python, lo usa Serena)"            v_uv            i_uv            utilidades-base
register_item claude-ahorro "Claude Code: ajustes para ahorrar tokens"        v_claude_ahorro i_claude_ahorro claude-code
register_item claude-salida  "Claude Code: salida concisa (verbose off)"     v_claude_salida i_claude_salida claude-code
register_item serena        "Serena: índice de código para Claude Code (MCP)" v_serena        i_serena        uv claude-code
register_item graphify      "Graphify: grafo de conocimiento para Claude Code" v_graphify      i_graphify      uv claude-code
describe_claude_tokens
register_post post_claude_tokens

# Hermes Agent (Nous Research). --skip-setup evita el asistente interactivo: queda como paso manual.
v_hermes() { has_cmd hermes; }
i_hermes() { run_remote_script https://hermes-agent.nousresearch.com/install.sh bash --skip-setup; }
register_item hermes "Hermes Agent (Nous Research)" v_hermes i_hermes utilidades-base

# --- Tailscale ---
v_tailscale() { cmd_works tailscale version && service_enabled tailscaled; }
i_tailscale() {
    run_remote_script https://tailscale.com/install.sh sh
    sudo systemctl enable --now tailscaled
}
register_item tailscale "Tailscale (VPN)" v_tailscale i_tailscale utilidades-base

# --- GitHub CLI (repositorio oficial de apt) ---
v_gh() { cmd_works gh --version; }
i_gh() {
    sudo mkdir -p -m 755 /etc/apt/keyrings
    local tmp; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    download https://cli.github.com/packages/githubcli-archive-keyring.gpg "$tmp"
    sudo install -m 644 "$tmp" /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    pkg_refresh
    pkg_install gh
}
register_item gh "GitHub CLI (gh)" v_gh i_gh utilidades-base

# --- Playwright CLI (comando: playwright-cli) y herdr (CLI y/o App): iguales en Ubuntu y Manjaro ---
register_npm playwright-cli "Playwright CLI" playwright-cli "@playwright/cli@latest" nvm-node
register_item herdr     "herdr CLI (terminal)"   v_herdr     i_herdr     utilidades-base
register_item herdr-app "herdr App (escritorio)" v_herdr_app i_herdr_app utilidades-base
describe_herdr

# --- PATH en bash (el de zsh se configura en el módulo 06, después de Oh My Zsh) ---
v_entorno_bash() { path_entries_ok "$HOME/.profile" "$HOME/.bashrc"; }
i_entorno_bash() { ensure_path_entries "$HOME/.profile" "$HOME/.bashrc"; }
register_item entorno-bash "Rutas (PATH) de herramientas en bash" v_entorno_bash i_entorno_bash
