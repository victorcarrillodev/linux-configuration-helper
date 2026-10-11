#!/usr/bin/env bash
# manjaro/07-productividad.sh — AppFlowy y WhatsDesk (AUR).

section 07 "PRODUCTIVIDAD" "AppFlowy (con respaldo semanal a GitHub) y WhatsApp Desktop (WhatsDesk)"

register_aur appflowy "AppFlowy" "" appflowy-bin

# Respaldo semanal de AppFlowy a GitHub (script + daemon): igual en Ubuntu y Manjaro (funciones en comun/)
register_item appflowy-backup "Respaldo semanal de AppFlowy a GitHub (daemon)" v_appflowy_backup i_appflowy_backup base-devel
register_aur whatsdesk "WhatsDesk (WhatsApp)" whatsdesk whatsdesk-bin
