#!/usr/bin/env python3
"""Status line de Claude Code (instalada por linux conf: claude/statusline.py) al estilo «usuario@equipo → ruta git(...)» con barras finas.

Línea 1: usuario@equipo → …/ruta  git(rama × ↑N ↓N !N ?N)  ↑remoto
Línea 2: Modelo | ctx ━━━━━━──────────  10%/1M
Línea 3: | 5h ━━━━━────────  42% ⟳14:13   | 7d ━━━━━━━━──  62% ⟳lun 00:00

Claude Code le pasa los datos de la sesión en JSON por stdin y el ancho en $COLUMNS.
"""
import json
import os
import socket
import subprocess
import sys
import time

# --- Colores (24 bits) --------------------------------------------------------
def rgb(h):
    h = h.lstrip('#')
    return f"\033[38;2;{int(h[0:2], 16)};{int(h[2:4], 16)};{int(h[4:6], 16)}m"

R = "\033[0m"
B = "\033[1m"
BLUE = rgb('#82AAFF')      # usuario@equipo y remoto
GREEN = rgb('#9ECE6A')     # flecha, barra de contexto
TEXT = rgb('#C0CAF5')      # ruta
YELLOW = rgb('#E0AF68')    # git(rama)
RED = rgb('#F7768E')       # × y cambios
CYAN = rgb('#7DCFFF')
MUTED = rgb('#737AA2')     # separadores, reinicios
TRACK = rgb('#3B4261')     # pista vacía de las barras
ORANGE = rgb('#FF9E64')
WHITE = rgb('#E9E9ED')

DIAS = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom']


def level(pct):
    """Verde < 50 %, naranja < 80 %, rojo a partir de ahí."""
    return GREEN if pct < 50 else ORANGE if pct < 80 else RED


def bar(pct, width, color=None):
    """Barra fina con media celda de resolución: tramo lleno de color y pista tenue."""
    width = max(4, width)
    halves = max(0, min(2 * width, round(min(100.0, pct) / 100 * 2 * width)))
    full, half = divmod(halves, 2)
    c = color or level(pct)
    s = c + '━' * full
    if half:
        s += '╸'
    rest = width - full - half
    return s + TRACK + '─' * rest + R


def pct_txt(p):
    return f"{p:.0f}%" if p >= 10 or float(p).is_integer() else f"{p:.1f}%"


def tokens_txt(n):
    if not n:
        return ''
    if n >= 1_000_000:
        return f"{n / 1_000_000:g}M"
    return f"{n / 1000:g}k"


def reset_txt(epoch, weekly):
    if not epoch:
        return ''
    t = time.localtime(int(epoch))
    hhmm = time.strftime('%H:%M', t)
    if not weekly and time.strftime('%Y%m%d', t) == time.strftime('%Y%m%d'):
        return hhmm
    return f"{DIAS[t.tm_wday]} {hhmm}"


def short_path(path):
    home = os.path.expanduser('~')
    if path == home:
        return '~'
    if path.startswith(home + os.sep):
        path = path[len(home) + 1:]
        parts = path.split(os.sep)
        return ('…/' + '/'.join(parts[-3:])) if len(parts) > 3 else '~/' + path
    parts = path.strip(os.sep).split(os.sep)
    return ('…/' + '/'.join(parts[-3:])) if len(parts) > 3 else path


def git_info(cwd):
    """Rama, adelantos/atrasos, modificados y sin seguimiento en una sola llamada a git."""
    try:
        out = subprocess.run(
            ['git', '-C', cwd, '--no-optional-locks', 'status', '--porcelain=v2', '--branch'],
            capture_output=True, text=True, timeout=1.5,
        )
    except Exception:
        return None
    if out.returncode != 0:
        return None
    branch, ahead, behind, changed, untracked, upstream = '', 0, 0, 0, 0, False
    for line in out.stdout.splitlines():
        if line.startswith('# branch.head '):
            branch = line.split(' ', 2)[2]
        elif line.startswith('# branch.upstream '):
            upstream = True
        elif line.startswith('# branch.ab '):
            a, b = line.split()[2:4]
            ahead, behind = int(a), -int(b)
        elif line.startswith(('1 ', '2 ', 'u ')):
            changed += 1
        elif line.startswith('? '):
            untracked += 1
    if branch == '(detached)':
        branch = 'HEAD'
    return branch, ahead, behind, changed, untracked, upstream


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}
    cols = int(os.environ.get('COLUMNS') or 100)

    ws = data.get('workspace') or {}
    cwd = ws.get('current_dir') or data.get('cwd') or os.getcwd()

    # --- Línea 1: usuario@equipo → ruta  git(...)  ↑remoto -------------------
    user = os.environ.get('USER') or 'yo'
    host = socket.gethostname().split('.')[0]
    line1 = f"{BLUE}{user}@{host}{R} {GREEN}→{R} {TEXT}{short_path(cwd)}{R}"
    g = git_info(cwd)
    if g:
        branch, ahead, behind, changed, untracked, upstream = g
        parts = [f"{YELLOW}{branch}{R}"]
        if changed or untracked:
            parts.append(f"{RED}×{R}")
        if ahead:
            parts.append(f"{CYAN}↑{ahead}{R}")
        if behind:
            parts.append(f"{CYAN}↓{behind}{R}")
        if changed:
            parts.append(f"{RED}!{changed}{R}")
        if untracked:
            parts.append(f"{MUTED}?{untracked}{R}")
        line1 += f" {YELLOW}git({R}{' '.join(parts)}{YELLOW}){R}"
        if upstream:
            line1 += f" {BLUE}↑remoto{R}"

    # --- Línea 2: modelo | ctx barra  10%/1M ---------------------------------
    model = (data.get('model') or {}).get('display_name') or 'Claude'
    ctx = data.get('context_window') or {}
    used = ctx.get('used_percentage')
    size = tokens_txt(ctx.get('context_window_size'))
    label = f"{model} {MUTED}|{R} ctx "
    bar_w = max(10, min(40, cols - len(model) - 22))
    if used is None:
        line2 = f"{WHITE}{B}{model}{R} {MUTED}| ctx —{R}"
    else:
        line2 = (f"{WHITE}{B}{model}{R} {MUTED}|{R} ctx {bar(used, bar_w, GREEN if used < 50 else None)}  "
                 f"{level(used)}{pct_txt(used)}{R}{MUTED}/{size}{R}")

    # --- Línea 3: límites de 5 h y 7 d ---------------------------------------
    limits = data.get('rate_limits') or {}
    gauges = []
    for key, name, weekly in (('five_hour', '5h', False), ('seven_day', '7d', True)):
        w = limits.get(key)
        if not w or w.get('used_percentage') is None:
            continue
        p = float(w['used_percentage'])
        rst = reset_txt(w.get('resets_at'), weekly)
        gauges.append((name, p, rst))

    lines = [line1, line2]
    if gauges:
        # Las dos en una línea si caben con barras de ≥ 12; si no, una por línea
        per = (cols - 4) // len(gauges)
        fixed = 4 + 2 + 5 + 3 + 10   # «| 5h » + espacios + «42%» + « ⟳» + fecha
        inline = len(gauges) > 1 and per - fixed >= 12
        bw = min(40, (per - fixed) if inline else max(10, min(40, cols - fixed - 2)))
        rendered = [
            f"{MUTED}|{R} {WHITE}{name}{R} {bar(p, bw)}  {level(p)}{pct_txt(p)}{R}"
            + (f" {MUTED}⟳{rst}{R}" if rst else '')
            for name, p, rst in gauges
        ]
        if inline:
            lines.append('   '.join(rendered))
        else:
            lines.extend(rendered)

    print('\n'.join(lines))


if __name__ == '__main__':
    main()
