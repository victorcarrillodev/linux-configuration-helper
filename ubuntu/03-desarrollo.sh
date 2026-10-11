#!/usr/bin/env bash
# ubuntu/03-desarrollo.sh — NVM + Node 24, pnpm, Bun, PostgreSQL, Flutter, CLIs de IA, Hermes y Tailscale.

section 03 "DESARROLLO" "NVM, Node 24, pnpm, Bun, PostgreSQL, Flutter, CLIs de IA y Tailscale"

NVM_VERSION="v0.40.3"
NODE_MAJOR="24"

# --- NVM + Node ---
v_nvm_node() {
    [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ] && cmd_works node --version \
        && [[ "$(node --version 2>/dev/null)" == v${NODE_MAJOR}.* ]] && cmd_works npm --version
}
i_nvm_node() {
    if [ ! -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
        run_remote_script "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" bash
    fi
    nvm_cmd install "$NODE_MAJOR"
    nvm_cmd alias default "$NODE_MAJOR"
    nvm_cmd use "$NODE_MAJOR"
}
register_item nvm-node "NVM + Node.js ${NODE_MAJOR}" v_nvm_node i_nvm_node

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
register_npm claude-code "Claude Code (Anthropic)"  claude   "@anthropic-ai/claude-code" nvm-node
register_npm codex       "Codex CLI (OpenAI)"       codex    "@openai/codex"          nvm-node
register_npm opencode    "OpenCode"                 opencode "opencode-ai"            nvm-node

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

# --- Playwright CLI (comando: playwright-cli) y herdr: iguales en Ubuntu y Manjaro ---
register_npm playwright-cli "Playwright CLI" playwright-cli "@playwright/cli@latest" nvm-node
register_item herdr "herdr (multiplexor de agentes de IA)" v_herdr i_herdr utilidades-base

# --- PATH en bash (el de zsh se configura en el módulo 06, después de Oh My Zsh) ---
v_entorno_bash() { path_entries_ok "$HOME/.profile" "$HOME/.bashrc"; }
i_entorno_bash() { ensure_path_entries "$HOME/.profile" "$HOME/.bashrc"; }
register_item entorno-bash "Rutas (PATH) de herramientas en bash" v_entorno_bash i_entorno_bash
