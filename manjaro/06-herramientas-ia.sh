#!/usr/bin/env bash
# manjaro/06-herramientas-ia.sh — Claude Desktop, Claude Code CLI, OpenCode (AUR) y ahorro de tokens (uv + Serena).

section 06 "IA" "Claude Desktop, Claude Code CLI, su status line, OpenCode y ahorro de tokens (Serena)"

# Claude Desktop y Claude Code son independientes: en la lista se elige uno, otro o ambos.
# (Anthropic publica la app solo para Debian/Ubuntu; en AUR «claude-desktop» la reempaqueta.)
register_aur claude-desktop "Claude Desktop (app de escritorio)" claude-desktop claude-desktop
register_aur claude-code    "Claude Code CLI (terminal)"         claude         claude-code
register_aur opencode       "OpenCode"                           opencode       opencode-bin
describe_claude

# Status line de Claude Code (barras de contexto y límites de 5 h / semanal), igual en ambas distros
register_item claude-statusline "Status line de Claude Code (contexto y límites)" v_claude_statusline i_claude_statusline
describe_claude_statusline

# Ahorro de tokens: uv (repo oficial) → Serena (índice de código, MCP) + ajustes globales de Claude Code
register_pkg  uv            "uv (gestor de Python, lo usa Serena)"            repo "uv!" uv
register_item claude-ahorro "Claude Code: ajustes para ahorrar tokens"        v_claude_ahorro i_claude_ahorro claude-code
register_item serena        "Serena: índice de código para Claude Code (MCP)" v_serena        i_serena        uv claude-code
register_item graphify      "Graphify: grafo de conocimiento para Claude Code" v_graphify      i_graphify      uv claude-code
describe_claude_tokens
register_post post_claude_tokens
