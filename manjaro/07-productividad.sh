#!/usr/bin/env bash
# manjaro/07-productividad.sh — WhatsDesk y Espanso (AUR).

section 07 "PRODUCTIVIDAD" "WhatsApp Desktop (WhatsDesk) y Espanso (expansor de texto)"

register_aur whatsdesk "WhatsDesk (WhatsApp)" whatsdesk whatsdesk-bin

# --- Espanso: AUR espanso-wayland o espanso-x11 según la sesión gráfica (se compila con Rust) ---
i_espanso() {
    local pkg="espanso-$(espanso_flavor)"
    info "Sesión $(espanso_flavor): se instala ${pkg} (se compila; puede tardar unos minutos)."
    aur_install "$pkg"
    espanso_setup
}
register_item espanso "Espanso (expansor de texto)" v_espanso i_espanso yay
describe_espanso
