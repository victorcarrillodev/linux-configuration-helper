#!/usr/bin/env bash
# comun/10-herramientas-comunes.sh — Funciones de herramientas que se instalan IGUAL en Ubuntu y Manjaro.
#
# Aquí solo se DEFINEN las funciones de verificación/instalación. Cada distro registra el ítem
# en su propio módulo (así se ejecuta en el orden correcto y con las dependencias de esa distro).

# --- herdr: multiplexor de terminal para agentes de IA (binario estático, instalador oficial) ---
# El instalador oficial descarga el binario a ~/.local/bin y verifica su SHA-256.
v_herdr() { cmd_works herdr --version; }
i_herdr() { run_remote_script https://herdr.dev/install.sh sh; }
