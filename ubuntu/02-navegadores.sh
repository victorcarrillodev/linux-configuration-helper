#!/usr/bin/env bash
# ubuntu/02-navegadores.sh — Sin Firefox; Brave Nightly, Chrome Dev, Variety y wallpapers.

section 02 "NAVEGADORES" "Elimina Firefox; instala Brave Nightly, Google Chrome Dev, Variety y wallpapers"

# Los repos de Brave y Chrome solo publican amd64
_solo_amd64() {
    [ "$(dpkg --print-architecture)" = "amd64" ] && return 0
    warn "Este paquete solo existe para amd64 (este equipo es $(dpkg --print-architecture))."
    return 1
}

# --- Firefox fuera (deb y snap) ---
v_sin_firefox() {
    ! pkg_installed firefox && ! { has_cmd snap && snap list firefox >/dev/null 2>&1; }
}
i_sin_firefox() {
    sudo umount /var/snap/firefox/common/host-hunspell 2>/dev/null || true
    sudo snap remove --purge firefox 2>/dev/null || true
    apt_get purge firefox 2>/dev/null || true
    apt_get autoremove
    rm -rf "$HOME/.mozilla" "$HOME/snap/firefox"
}
register_item sin-firefox "Eliminar Firefox (deb y snap)" v_sin_firefox i_sin_firefox

# --- Brave Nightly ---
v_brave() { has_cmd brave-browser-nightly || pkg_installed brave-browser-nightly; }
i_brave() {
    _solo_amd64 || return "$RC_SKIP"
    local key=/usr/share/keyrings/brave-browser-nightly-archive-keyring.gpg
    sudo curl -fsSLo "$key" https://brave-browser-apt-nightly.s3.brave.com/brave-browser-nightly-archive-keyring.gpg
    echo "deb [signed-by=${key} arch=amd64] https://brave-browser-apt-nightly.s3.brave.com/ stable main" \
        | sudo tee /etc/apt/sources.list.d/brave-browser-nightly.list >/dev/null
    pkg_refresh
    pkg_install brave-browser-nightly
}
register_item brave "Brave Nightly" v_brave i_brave

# --- Google Chrome (canal Dev) ---
v_chrome() { has_cmd google-chrome-unstable || pkg_installed google-chrome-unstable; }
i_chrome() {
    _solo_amd64 || return "$RC_SKIP"
    local dir
    dir="$(mktemp -d)"; chmod 755 "$dir"
    trap 'rm -rf "$dir"' EXIT
    download https://dl.google.com/linux/direct/google-chrome-unstable_current_amd64.deb "${dir}/chrome.deb"
    pkg_install "${dir}/chrome.deb"
}
register_item chrome "Google Chrome Dev" v_chrome i_chrome

# --- Variety + wallpapers ---
register_pkg variety "Variety (cambio de fondos de pantalla)" repo variety variety

# Una carpeta ~/wallpapers con contenido (aunque sea del usuario) cuenta como lista: nunca se borra
v_wallpapers() { [ -d "$HOME/wallpapers" ] && [ -n "$(ls -A "$HOME/wallpapers" 2>/dev/null)" ]; }
i_wallpapers() {
    [ -d "$HOME/wallpapers" ] && rmdir "$HOME/wallpapers"   # solo si está vacía
    git clone --depth=1 https://github.com/victorcarrillodev/wallpapers.git "$HOME/wallpapers"
}
register_item wallpapers "Wallpapers (~/wallpapers)" v_wallpapers i_wallpapers
