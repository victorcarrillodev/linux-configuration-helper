#!/usr/bin/env bash
# manjaro/05-editores.sh — Cursor y Antigravity IDE (AUR) y VS Code (repositorio).
# El usuario elige en el PASO 3 del menú entre Antigravity, Cursor y VS Code (uno o varios);
# aquí se definen los ítems, el motor del instalador filtra los que no se eligieron.

section 05 "EDITORES" "Editores elegidos en el menú: Antigravity IDE, Cursor y VS Code"

# --- Cursor (AUR) ---
register_aur cursor "Cursor IDE" cursor cursor-bin
set_editor_packages cursor cursor-bin

# --- Antigravity IDE (AUR) ---
register_aur antigravity "Antigravity IDE" antigravity-ide antigravity-ide
set_editor_packages antigravity antigravity-ide

# --- VS Code (paquete «code» del repositorio de Manjaro/Arch) ---
register_pkg vscode "Visual Studio Code" repo "code!" code
set_editor_packages vscode code
