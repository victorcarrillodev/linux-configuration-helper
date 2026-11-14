#!/usr/bin/env python3
"""Configura Claude Code para ahorrar tokens y usar Serena, sin tocar el resto de ajustes.

Uso:
  configurar-claude.py --ahorro                      reglas «deny» + guía en ~/.claude/CLAUDE.md
  configurar-claude.py --comprobar-ahorro            0 si ya está aplicado, 1 si no
  configurar-claude.py --serena <ruta serena-hooks>  hooks de Serena + MCP_TIMEOUT
  configurar-claude.py --comprobar-serena            0 si Serena está registrado y con hooks, 1 si no

Antes de escribir settings.json se hace una copia settings.json.bak-<fecha>. Si el JSON está roto,
no se escribe nada. Los bloques propios se reconocen por su contenido (deny) o por la marca
«serena-hooks» (hooks) y por marcadores en CLAUDE.md, así que ejecutarlo varias veces es seguro.
"""
import json
import os
import shutil
import sys
import time

CLAUDE_DIR = os.path.expanduser('~/.claude')
SETTINGS = os.path.join(CLAUDE_DIR, 'settings.json')
MEMORY = os.path.join(CLAUDE_DIR, 'CLAUDE.md')
CLAUDE_JSON = os.path.expanduser('~/.claude.json')   # aquí guarda «claude mcp add --scope user»

# Archivos que Claude no debe leer: generados, dependencias o enormes. Nunca aportan contexto útil.
# (build/ y target/ no se incluyen: en algunos proyectos son código fuente. Las reglas «deny»
# tienen prioridad sobre «allow», así que solo van las que son basura en cualquier proyecto.)
DENY = [
    'Read(**/node_modules/**)',
    'Read(**/.next/**)',
    'Read(**/.nuxt/**)',
    'Read(**/dist/**)',
    'Read(**/coverage/**)',
    'Read(**/__pycache__/**)',
    'Read(**/.venv/**)',
    'Read(**/venv/**)',
    'Read(**/*.min.js)',
    'Read(**/*.min.css)',
    'Read(**/*.map)',
    'Read(**/package-lock.json)',
    'Read(**/pnpm-lock.yaml)',
    'Read(**/yarn.lock)',
    'Read(**/bun.lockb)',
]

MARK_START = '<!-- >>> linux-conf: ahorro de tokens >>> -->'
MARK_END = '<!-- <<< linux-conf: ahorro de tokens <<< -->'
MEMORY_BLOCK = f"""{MARK_START}
## Ahorro de tokens (configurado por linux-conf)

- Si el servidor MCP **serena** está disponible, úsalo para explorar código: `get_symbols_overview`,
  `find_symbol` y `find_referencing_symbols` antes de leer archivos completos. Lee solo el símbolo o
  el rango de líneas que necesites.
- Para búsquedas amplias en el proyecto, usa un subagente (Explore) y devuelve solo la conclusión.
- Limita la salida de los comandos: tests en modo silencioso (`-q`, `--silent`), `| tail -n 50` en
  logs largos y `git diff --stat` antes que el diff completo.
- No releas archivos que ya están en la conversación ni repitas su contenido en las respuestas.
- Respuestas concisas: muestra solo el código que cambia, no archivos completos.
{MARK_END}"""

HOOK_EVENTS = {
    # evento: subcomando de serena-hooks (recomendados por la documentación de Serena)
    'PreToolUse': 'remind',     # recuerda usar Serena tras muchos grep/read seguidos
    'SessionStart': 'activate', # activa el proyecto al iniciar la sesión
    'SessionEnd': 'cleanup',    # limpia los datos de la sesión
}
MCP_TIMEOUT = '60000'


# --- settings.json -------------------------------------------------------------------------------
def load_json(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as f:
        text = f.read().strip()
    if not text:
        return {}
    data = json.loads(text)   # si el JSON está roto, falla aquí y no se escribe nada
    if not isinstance(data, dict):
        raise ValueError(f'{path} no contiene un objeto JSON')
    return data


def save_settings(cfg):
    os.makedirs(CLAUDE_DIR, exist_ok=True)
    if os.path.exists(SETTINGS):
        backup = f'{SETTINGS}.bak-{time.strftime("%Y%m%d-%H%M%S")}'
        n = 1
        while os.path.exists(backup):   # dos cambios en el mismo segundo: no pisar la copia
            backup = f'{SETTINGS}.bak-{time.strftime("%Y%m%d-%H%M%S")}-{n}'
            n += 1
        shutil.copy2(SETTINGS, backup)
        print(f'Copia de seguridad: {backup}')
    tmp = SETTINGS + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write('\n')
    os.replace(tmp, SETTINGS)


def hook_command(hooks_bin, sub):
    return f'{hooks_bin} {sub} --client=claude-code'


def hooks_ok(cfg, hooks_bin=None):
    hooks = cfg.get('hooks') or {}
    for event, sub in HOOK_EVENTS.items():
        found = False
        for group in hooks.get(event) or []:
            for h in group.get('hooks') or []:
                cmd = h.get('command', '')
                if 'serena-hooks' in cmd and f' {sub} ' in f'{cmd} ':
                    exe = cmd.split()[0]
                    if hooks_bin and exe != hooks_bin:
                        continue
                    if not hooks_bin and not (shutil.which(exe) or os.access(exe, os.X_OK)):
                        continue
                    found = True
        if not found:
            return False
    return True


def set_hooks(cfg, hooks_bin):
    hooks = cfg.setdefault('hooks', {})
    for event, sub in HOOK_EVENTS.items():
        groups = []
        # quita las entradas de serena-hooks anteriores (ruta vieja, etc.) y conserva las demás
        for group in hooks.get(event) or []:
            rest = [h for h in group.get('hooks') or [] if 'serena-hooks' not in h.get('command', '')]
            if rest:
                group = dict(group, hooks=rest)
                groups.append(group)
        groups.append({'matcher': '', 'hooks': [{'type': 'command', 'command': hook_command(hooks_bin, sub)}]})
        hooks[event] = groups


# --- ~/.claude/CLAUDE.md -------------------------------------------------------------------------
def memory_text():
    if not os.path.exists(MEMORY):
        return ''
    with open(MEMORY, encoding='utf-8') as f:
        return f.read()


def memory_ok():
    return MEMORY_BLOCK in memory_text()


def write_memory():
    text = memory_text()
    if MARK_START in text and MARK_END in text:
        before = text.split(MARK_START, 1)[0]
        after = text.split(MARK_END, 1)[1]
        text = before + MEMORY_BLOCK + after
    else:
        text = (text.rstrip() + '\n\n' if text.strip() else '') + MEMORY_BLOCK + '\n'
    os.makedirs(CLAUDE_DIR, exist_ok=True)
    tmp = MEMORY + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(text)
    os.replace(tmp, MEMORY)
    print(f'Guía de ahorro de tokens en {MEMORY}')


# --- Serena registrado como MCP de usuario --------------------------------------------------------
def serena_registered():
    try:
        data = load_json(CLAUDE_JSON)
    except Exception:  # noqa: BLE001
        return False
    srv = (data.get('mcpServers') or {}).get('serena') or {}
    cmd, args = srv.get('command', ''), srv.get('args') or []
    return bool(cmd) and os.access(cmd, os.X_OK) and 'start-mcp-server' in args \
        and '--project-from-cwd' in args and 'claude-code' in args


# --- main ----------------------------------------------------------------------------------------
def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ''
    try:
        cfg = load_json(SETTINGS)
    except Exception as e:  # noqa: BLE001
        print(f'No se puede leer {SETTINGS}: {e}', file=sys.stderr)
        return 1

    deny = (cfg.get('permissions') or {}).get('deny') or []

    if mode == '--comprobar-ahorro':
        return 0 if all(r in deny for r in DENY) and memory_ok() else 1

    if mode == '--comprobar-serena':
        ok = serena_registered() and hooks_ok(cfg) \
            and (cfg.get('env') or {}).get('MCP_TIMEOUT') == MCP_TIMEOUT
        return 0 if ok else 1

    if mode == '--ahorro':
        missing = [r for r in DENY if r not in deny]
        if missing:
            cfg.setdefault('permissions', {})['deny'] = deny + missing
            save_settings(cfg)
            print(f'{len(missing)} regla(s) «deny» añadidas a {SETTINGS}')
        else:
            print('Las reglas «deny» ya estaban.')
        if not memory_ok():
            write_memory()
        return 0

    if mode == '--serena':
        if len(sys.argv) < 3:
            print('Falta la ruta de serena-hooks', file=sys.stderr)
            return 2
        hooks_bin = sys.argv[2]
        changed = False
        if not hooks_ok(cfg, hooks_bin):
            set_hooks(cfg, hooks_bin)
            changed = True
        env = cfg.setdefault('env', {})
        if env.get('MCP_TIMEOUT') != MCP_TIMEOUT:
            env['MCP_TIMEOUT'] = MCP_TIMEOUT   # Serena tarda en arrancar la primera vez
            changed = True
        if changed:
            save_settings(cfg)
            print(f'Hooks de Serena y MCP_TIMEOUT en {SETTINGS}')
        else:
            print('Los hooks de Serena ya estaban.')
        return 0

    print(__doc__, file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main())
