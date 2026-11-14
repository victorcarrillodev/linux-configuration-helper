#!/usr/bin/env bash
# manjaro/05-editores.sh — Cursor y Antigravity IDE (AUR) y VS Code (repositorio).
# Se eligen en la lista principal (PASO 3) junto al resto de programas.

section 05 "EDITORES E IDES" "Antigravity IDE, Cursor y VS Code (elige uno, varios o ninguno)"

# --- Cursor (AUR) ---
register_aur cursor "Cursor IDE" cursor cursor-bin
set_editor_packages cursor cursor-bin

# --- Antigravity IDE (AUR) ---
register_aur antigravity "Antigravity IDE" antigravity-ide antigravity-ide
set_editor_packages antigravity antigravity-ide

# --- VS Code (AUR: visual-studio-code-bin, el original de Microsoft) ---
# Se instala con yay (depende del módulo 01) y se verifica con el comando «code».
register_aur vscode "Visual Studio Code" code visual-studio-code-bin
set_editor_packages vscode visual-studio-code-bin
describe_editors
