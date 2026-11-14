#!/usr/bin/env python3
"""Activa (o comprueba) la status line en ~/.claude/settings.json sin tocar el resto de ajustes.

Uso:  instalar-statusline.py --instalar   escribe el bloque statusLine (con copia de seguridad)
      instalar-statusline.py --comprobar  0 si ya está configurada, 1 si no
"""
import json
import os
import shutil
import sys
import time

SETTINGS = os.path.expanduser('~/.claude/settings.json')
COMMAND = 'python3 ~/.claude/statusline.py'
BLOCK = {'type': 'command', 'command': COMMAND, 'padding': 0, 'refreshInterval': 60}


def load():
    if not os.path.exists(SETTINGS):
        return {}
    with open(SETTINGS, encoding='utf-8') as f:
        text = f.read().strip()
    if not text:
        return {}
    data = json.loads(text)   # si el JSON está roto, falla aquí y no se escribe nada
    if not isinstance(data, dict):
        raise ValueError(f'{SETTINGS} no contiene un objeto JSON')
    return data


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else '--comprobar'
    try:
        cfg = load()
    except Exception as e:  # noqa: BLE001
        print(f'No se puede leer {SETTINGS}: {e}', file=sys.stderr)
        return 1

    current = cfg.get('statusLine') or {}
    if mode == '--comprobar':
        return 0 if current.get('command') == COMMAND else 1

    if mode != '--instalar':
        print(__doc__, file=sys.stderr)
        return 2

    if current.get('command') == COMMAND:
        print('La status line ya estaba configurada.')
        return 0
    os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
    if os.path.exists(SETTINGS):
        backup = f'{SETTINGS}.bak-{time.strftime("%Y%m%d-%H%M%S")}'
        shutil.copy2(SETTINGS, backup)
        print(f'Copia de seguridad: {backup}')
        if current:
            print(f'Se reemplaza la status line anterior: {current.get("command", current)}')
    cfg['statusLine'] = BLOCK
    tmp = SETTINGS + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write('\n')
    os.replace(tmp, SETTINGS)
    print(f'Status line activada en {SETTINGS}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
