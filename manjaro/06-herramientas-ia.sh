#!/usr/bin/env bash
# manjaro/06-herramientas-ia.sh — Claude Desktop, Claude Code CLI y OpenCode (AUR).

section 06 "IA" "Claude Desktop, Claude Code CLI, su status line y OpenCode"

# Claude Desktop y Claude Code son independientes: en la lista se elige uno, otro o ambos.
# (Anthropic publica la app solo para Debian/Ubuntu; en AUR «claude-desktop» la reempaqueta.)
register_aur claude-desktop "Claude Desktop (app de escritorio)" claude-desktop claude-desktop
register_aur claude-code    "Claude Code CLI (terminal)"         claude         claude-code
register_aur opencode       "OpenCode"                           opencode       opencode-bin
describe_claude

# Status line de Claude Code (barras de contexto y límites de 5 h / semanal), igual en ambas distros
register_item claude-statusline "Status line de Claude Code (contexto y límites)" v_claude_statusline i_claude_statusline
describe_claude_statusline
