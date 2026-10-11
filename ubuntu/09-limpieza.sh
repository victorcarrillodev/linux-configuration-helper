#!/usr/bin/env bash
# ubuntu/09-limpieza.sh — Limpieza de paquetes residuales.
# (El borrado del instalador ya no es automático: al final se pregunta.)

section 09 "LIMPIEZA" "Paquetes huérfanos y caché de apt"

i_limpieza() { pkg_clean; }
register_item limpieza "Limpiar paquetes residuales y caché de apt" - i_limpieza
