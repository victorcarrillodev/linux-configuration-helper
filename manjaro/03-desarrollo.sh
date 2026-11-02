#!/usr/bin/env bash
#!/usr/bin/env bash
# manjaro/03-desarrollo.sh — Node.js LTS, pnpm, Bun, Rust, Flutter, rutas globales de JS y Tailscale.

section 03 "DESARROLLO" "Node.js LTS, pnpm, Bun, Rust, Flutter, GitHub CLI, Playwright, herdr y Tailscale"

# --- Node.js LTS (repo de Manjaro) ---
# El repo trae «nodejs» (versión Current) y «nodejs-lts» (LTS). Si hay un nodejs no-LTS, se
# desinstala y queda la LTS. Se verifica contra /usr/bin/node (ignora cualquier nvm del usuario).
v_node() {
    pkg_installed nodejs-lts || return 1
    [ -x /usr/bin/node ] || return 1
    cmd_works /usr/bin/node --version || return 1
    [ -n "$(/usr/bin/node -p 'process.release.lts || ""' 2>/dev/null)" ] || return 1
}
i_node() {
    if pkg_installed nodejs; then   # la versión Current (no LTS) está instalada: fuera
        info "Retirando «nodejs» (versión que no es LTS)…"
        sudo pacman -Rns --noconfirm nodejs || sudo pacman -Rdd --noconfirm nodejs
    fi
    pkg_install nodejs-lts
}
register_item nodejs "Node.js LTS + npm" v_node i_node
register_pkg pnpm   "pnpm"          repo "pnpm!" pnpm
register_pkg bun    "Bun"           repo "bun!"  bun

# --- Rust (vía rustup: sin toolchain por defecto 'rustc' no funciona, por eso se ejecuta para verificar) ---
v_rust() { cmd_works rustc --version; }
i_rust() {
    pkg_install rustup
    rustup default stable
}
register_item rust "Rust (rustup, toolchain stable)" v_rust i_rust

register_aur flutter "Flutter SDK" flutter flutter-bin

# --- npm/pnpm/bun listos para paquetes globales SIN sudo ---
JS_RC_LINES=(
    'export PATH="$HOME/.npm-global/bin:$PATH"'
    'export PNPM_HOME="$HOME/.local/share/pnpm"'
    'export PATH="$PNPM_HOME:$PATH"'
    'export PATH="$HOME/.bun/bin:$PATH"'
    'export PATH="$HOME/.local/bin:$PATH"'
)
v_entorno_js() {
    local rc l
    [ "$(npm config get prefix 2>/dev/null)" = "${HOME}/.npm-global" ] || return 1
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        [ -f "$rc" ] || continue
        for l in "${JS_RC_LINES[@]}"; do grep -qxF -- "$l" "$rc" || return 1; done
    done
    return 0
}
i_entorno_js() {
    local l
    npm config set prefix "${HOME}/.npm-global"
    mkdir -p "${HOME}/.npm-global/bin"
    for l in "${JS_RC_LINES[@]}"; do add_to_shell_rc "$l"; done
}
register_item entorno-js "Rutas globales de npm, pnpm y bun (sin sudo)" v_entorno_js i_entorno_js nodejs

# --- Tailscale ---
v_tailscale() { cmd_works tailscale version && service_enabled tailscaled.service; }
i_tailscale() {
    pkg_install tailscale
    sudo systemctl enable --now tailscaled.service
}
register_item tailscale "Tailscale (VPN)" v_tailscale i_tailscale

# --- GitHub CLI (repositorio oficial de Arch/Manjaro) ---
register_pkg gh "GitHub CLI (gh)" repo "gh!" github-cli

# --- Playwright CLI (comando: playwright-cli) y herdr: iguales en Ubuntu y Manjaro ---
# El prefijo global de npm lo deja listo entorno-js (sin sudo), por eso depende de él.
register_npm playwright-cli "Playwright CLI" playwright-cli "@playwright/cli@latest" entorno-js
register_item herdr "herdr (multiplexor de agentes de IA)" v_herdr i_herdr
