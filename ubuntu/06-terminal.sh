#!/usr/bin/env bash
# ubuntu/06-terminal.sh — Zsh, Oh My Zsh, Powerlevel10k, fuentes, Wave Terminal, banner y shell por defecto.

section 06 "TERMINAL" "Zsh, Oh My Zsh, Powerlevel10k, fuentes, banner y shell por defecto"

FONT_DIR="${HOME}/.local/share/fonts"
ZSHRC="${HOME}/.zshrc"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
NERD_FONTS_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
MESLO_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
MESLO_FILES=("MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf")
BANNER_MARKER="# === BANNER VICTOR CARRILLO ==="
# zsh-syntax-highlighting debe ir siempre el último de la lista
ZSH_PLUGINS_WANTED=(git zsh-autosuggestions web-search docker docker-compose python zsh-syntax-highlighting)

register_pkg zsh-paquetes "Zsh + figlet, toilet, lolcat, fontconfig, Font Awesome" repo "" \
    zsh fontconfig fonts-font-awesome figlet toilet lolcat

# --- Oh My Zsh ---
v_oh_my_zsh() { [ -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]; }
i_oh_my_zsh() {
    # Una carpeta a medias hace que el instalador se niegue: se aparta, no se borra
    [ -d "${HOME}/.oh-my-zsh" ] && mv "${HOME}/.oh-my-zsh" "${HOME}/.oh-my-zsh.incompleto-$(date +%s)"
    local tmp; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    download https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh "$tmp"
    env CHSH=no RUNZSH=no sh "$tmp" --unattended
}
register_item oh-my-zsh "Oh My Zsh" v_oh_my_zsh i_oh_my_zsh zsh-paquetes

# --- Fuentes ---
v_fuente_cascadia() { glob_exists "${FONT_DIR}/CaskaydiaCove*"; }
i_fuente_cascadia() {
    mkdir -p "$FONT_DIR"
    local tmp; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    download "${NERD_FONTS_BASE}/CascadiaCode.tar.xz" "$tmp"   # en nerd-fonts se llama "CaskaydiaCove"
    tar -xJf "$tmp" -C "$FONT_DIR"
    fc-cache -f "$FONT_DIR"
}
register_item fuente-cascadia "Fuente CascadiaCode Nerd Font" v_fuente_cascadia i_fuente_cascadia zsh-paquetes

v_fuente_meslo() {
    local f
    for f in "${MESLO_FILES[@]}"; do [ -s "${FONT_DIR}/${f}" ] || return 1; done
}
i_fuente_meslo() {
    mkdir -p "$FONT_DIR"
    local f tmp
    for f in "${MESLO_FILES[@]}"; do
        tmp="$(mktemp)"
        if download "${MESLO_BASE}/${f// /%20}" "$tmp"; then
            chmod 644 "$tmp"; mv "$tmp" "${FONT_DIR}/${f}"
        else
            rm -f "$tmp"; return 1
        fi
    done
    fc-cache -f "$FONT_DIR"
}
register_item fuente-meslo "Fuente MesloLGS NF (Powerlevel10k)" v_fuente_meslo i_fuente_meslo zsh-paquetes

# --- Wave Terminal (el .deb se busca en la API de releases: el nombre cambia con cada versión) ---
v_wave() { pkg_installed waveterm || has_cmd waveterm || has_cmd wave; }
i_wave() {
    local arch dir url
    case "$(uname -m)" in aarch64) arch=arm64 ;; *) arch=amd64 ;; esac
    dir="$(mktemp -d)"; chmod 755 "$dir"; trap 'rm -rf "$dir"' EXIT
    download https://api.github.com/repos/wavetermdev/waveterm/releases/latest "${dir}/release.json"
    url="$(grep -m1 -oE "https://[^\"]*waveterm-linux-${arch}-[^\"]*\.deb" "${dir}/release.json" || true)"
    if [ -z "$url" ]; then
        warn "No hay un paquete .deb de Wave Terminal para ${arch}."
        return "$RC_SKIP"
    fi
    download "$url" "${dir}/wave.deb"
    pkg_install "${dir}/wave.deb"
}
register_item wave "Wave Terminal" v_wave i_wave utilidades-base

# --- Powerlevel10k y plugins de Zsh ---
v_p10k() {
    [ -f "${ZSH_CUSTOM_DIR}/themes/powerlevel10k/powerlevel10k.zsh-theme" ] \
        && [ -f "${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ] \
        && [ -f "${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]
}
# git_clone_si_falta <url> <destino> <archivo-que-debe-existir>
git_clone_si_falta() {
    [ -f "${2}/${3}" ] && return 0
    rm -rf "$2"    # clon roto de este mismo repo
    git clone --depth=1 "$1" "$2"
}
i_p10k() {
    mkdir -p "${ZSH_CUSTOM_DIR}/themes" "${ZSH_CUSTOM_DIR}/plugins"
    git_clone_si_falta https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM_DIR}/themes/powerlevel10k" powerlevel10k.zsh-theme
    git_clone_si_falta https://github.com/zsh-users/zsh-autosuggestions \
        "${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions" zsh-autosuggestions.zsh
    git_clone_si_falta https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting" zsh-syntax-highlighting.zsh
}
register_item p10k "Powerlevel10k + autosuggestions + syntax-highlighting" v_p10k i_p10k oh-my-zsh

# --- Configuración de ~/.zshrc ---
# Nombres de los plugins activos (admite plugins=(...) en una o varias líneas)
zshrc_plugin_names() {
    awk '/^plugins=\(/{f=1} f{print} f&&/\)/{exit}' "$ZSHRC" 2>/dev/null \
        | sed -e 's/#.*//' -e 's/^plugins=(//' | tr -d '()' | tr -s ' \t' '\n' | grep -v '^$' || true
}

v_zshrc() {
    [ -f "$ZSHRC" ] || return 1
    grep -q '^ZSH_THEME="powerlevel10k/powerlevel10k"' "$ZSHRC" || return 1
    local cur p m
    cur="$(zshrc_plugin_names)"
    for p in "${ZSH_PLUGINS_WANTED[@]}"; do grep -qx -- "$p" <<< "$cur" || return 1; done
    grep -q '^typeset -g POWERLEVEL9K_INSTANT_PROMPT=off' "$ZSHRC" || return 1
    for m in "# ------ NVM INIT ------" "# ------ PNPM PATH ------" "# ------ BUN PATH ------" "$BANNER_MARKER"; do
        grep -qF -- "$m" "$ZSHRC" || return 1
    done
    path_entries_ok "$ZSHRC"
}

zshrc_set_theme() {
    if grep -q '^ZSH_THEME=' "$ZSHRC"; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
    else
        sed -i '1i ZSH_THEME="powerlevel10k/powerlevel10k"' "$ZSHRC"
    fi
}

zshrc_set_plugins() {
    local line cur p new tmp missing=()
    cur="$(zshrc_plugin_names)"
    line="$(grep -m1 -E '^plugins=\(' "$ZSHRC" || true)"
    if [ -z "$line" ]; then
        printf '\nplugins=(%s)\n' "${ZSH_PLUGINS_WANTED[*]}" >> "$ZSHRC"
        return 0
    fi
    for p in "${ZSH_PLUGINS_WANTED[@]}"; do grep -qx -- "$p" <<< "$cur" || missing+=("$p"); done
    [ "${#missing[@]}" -eq 0 ] && return 0

    tmp="$(mktemp)"
    if [[ "$line" == *')'* ]]; then
        # Una línea: se reconstruye dejando zsh-syntax-highlighting al final
        new=""
        for p in $cur "${missing[@]}"; do
            [ "$p" = zsh-syntax-highlighting ] && continue
            [[ " $new " == *" $p "* ]] || new+="${new:+ }${p}"
        done
        new+=" zsh-syntax-highlighting"
        awk -v new="plugins=(${new})" '!d && /^plugins=\(/ {print new; d=1; next} {print}' "$ZSHRC" > "$tmp"
    else
        # Varias líneas: se añaden los que faltan justo después de 'plugins=('
        awk -v add="${missing[*]}" '!d && /^plugins=\(/ {print; n=split(add, a, " "); for (i=1; i<=n; i++) print "  " a[i]; d=1; next} {print}' "$ZSHRC" > "$tmp"
    fi
    cat "$tmp" > "$ZSHRC"
    rm -f "$tmp"
}

# Sin instant prompt: así el banner siempre se muestra sin "saltos" ni avisos de p10k
zshrc_instant_prompt_off() {
    if grep -qE '^[[:space:]]*(typeset -g[[:space:]]+)?POWERLEVEL9K_INSTANT_PROMPT=' "$ZSHRC"; then
        sed -i -E 's/^[[:space:]]*(typeset -g[[:space:]]+)?POWERLEVEL9K_INSTANT_PROMPT=.*/typeset -g POWERLEVEL9K_INSTANT_PROMPT=off/' "$ZSHRC"
    else
        sed -i '1i typeset -g POWERLEVEL9K_INSTANT_PROMPT=off' "$ZSHRC"
    fi
}

i_zshrc() {
    [ -f "$ZSHRC" ] || { error "No existe ~/.zshrc (¿falló la instalación de Oh My Zsh?)."; return 1; }
    zshrc_set_theme
    zshrc_set_plugins
    zshrc_instant_prompt_off

    # Los heredocs van entrecomillados para que \. y $ se guarden literales en el archivo
    append_zshrc_block "# ------ NVM INIT ------" "$(cat <<'NVM_EOF'
# ------ NVM INIT ------
export NVM_DIR="${HOME}/.nvm"
[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"
[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"
# ------ END NVM INIT ------
NVM_EOF
)"
    append_zshrc_block "# ------ PNPM PATH ------" "$(cat <<'PNPM_EOF'
# ------ PNPM PATH ------
export PNPM_HOME="${HOME}/.local/share/pnpm"
case ":${PATH}:" in
  *":${PNPM_HOME}:"*) ;;
  *) export PATH="${PNPM_HOME}:${PATH}" ;;
esac
# ------ END PNPM PATH ------
PNPM_EOF
)"
    append_zshrc_block "# ------ BUN PATH ------" "$(cat <<'BUN_EOF'
# ------ BUN PATH ------
export BUN_INSTALL="${HOME}/.bun"
export PATH="${BUN_INSTALL}/bin:${PATH}"
# ------ END BUN PATH ------
BUN_EOF
)"

    if ! grep -qF -- "$BANNER_MARKER" "$ZSHRC"; then
        cat >> "$ZSHRC" <<'ZSHRC_BANNER'

# === BANNER VICTOR CARRILLO ===
if command -v toilet >/dev/null 2>&1; then
  _lc=cat
  for _p in lolcat /usr/games/lolcat; do command -v "$_p" >/dev/null 2>&1 && { _lc="$_p"; break; }; done
  echo ""
  paste -d '  ' <(
    (
      toilet -f ivrit  -F border -w 90 '</> Victor Carrillo'
      toilet -f pagga  -w 90 "master linux dev pro >>"
      toilet -f emboss -w 90 "illuminati"
    ) | awk '{ printf "%-85s\n", $0 }'
  ) <(cat << 'EOF_INNER'
           \' /\ \'
             / _\
       \    /_|__\   /
       \   /_|__|_\  /
          /_ ( °)- \
         /__ __|_ __\
        /__|______|__\
       /_|_____|____|_\
EOF_INNER
  ) | "$_lc"
  echo ""
  unset _lc _p
fi
# === FIN BANNER ===
ZSHRC_BANNER
    fi

    ensure_path_entries "$ZSHRC"
}
register_item zshrc "Configurar ~/.zshrc (tema, plugins, PATH y banner)" v_zshrc i_zshrc p10k

# --- Zsh como shell por defecto ---
v_shell_zsh() {
    case "$(getent passwd "$USER" | cut -d: -f7)" in */zsh) return 0 ;; *) return 1 ;; esac
}
i_shell_zsh() {
    local zsh_path; zsh_path="$(command -v zsh)"
    grep -qxF "$zsh_path" /etc/shells 2>/dev/null || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    sudo chsh -s "$zsh_path" "$USER"
}
register_item shell-zsh "Zsh como shell por defecto" v_shell_zsh i_shell_zsh zsh-paquetes

# --- Pasos manuales propios de este módulo ---
post_terminal() {
    if item_new fuente-meslo || item_new p10k; then
        add_manual_step "En tu terminal elige la fuente ${BOLD}MesloLGS NF${RESET} (Preferencias → Perfil → Fuente) para ver bien los íconos de Powerlevel10k."
    fi
    if item_new p10k || item_new zshrc; then
        add_manual_step "Abre Zsh y ejecuta ${BOLD}p10k configure${RESET} para personalizar el prompt."
    fi
    if item_ok shell-zsh && [ "$(basename "${SHELL:-}")" != zsh ]; then
        add_manual_step "${BOLD}Cierra sesión y vuelve a entrar${RESET} para que Zsh sea tu shell por defecto."
    fi
    return 0
}
register_post post_terminal
