# LINUX CONF

Instalador y configurador automático para **Ubuntu** (`linux conf`) y **Manjaro** (`manjaro conf`),
para instalar en el **escritorio** o en una **USB** portable. Un solo comando:

```bash
./init.sh
```

Al ejecutarlo muestra un banner y pregunta:

1. **¿Qué sistema?** Ubuntu (linux conf) o Manjaro (manjaro conf). Detecta el actual y lo propone;
   si eliges uno que no corresponde a este equipo (p. ej. Ubuntu en Manjaro), vuelve a preguntar.
2. **¿Dónde se instala?** Escritorio (disco interno) o USB (aplica optimizaciones de menos escrituras).

Después audita qué de la lista ya está instalado (sin pedir sudo), te pide confirmación y entonces instala
solo lo pendiente. Al terminar, te dice qué pasos debes hacer tú y te pregunta si quieres borrar el instalador.

## Cómo funciona

- **Verificación real**: cada programa tiene una comprobación propia (no basta con que exista un archivo:
  se ejecuta `--version`, se revisan paquetes, grupos, configuración…).
- **Auditoría previa**: tabla `✔ instalado / ✘ pendiente` antes de tocar nada.
- **Una pausa de 2 s** tras cada instalación para que el resultado quede visible (`--sin-pausa` la quita).
- **Reintentos con diagnóstico**: si algo falla (o no se puede verificar tras instalarlo) se detecta la causa
  (red, bloqueo del gestor de paquetes, claves, disco, paquete no encontrado), se repara y se reintenta hasta 3 veces.
  Lo que sigue fallando tiene una **revisión final** con 2 intentos más.
- **Dependencias**: si algo base falla (p. ej. Node), lo que depende de eso se omite con un aviso claro.
- **Resumen final** con verificación de todo, **pasos manuales** calculados según el estado real del sistema
  y registro completo en `~/.local/state/new-linux-conf/`.
- **Borrar el instalador**: siempre se pregunta (por defecto **No**). Si la carpeta es un repositorio git con
  cambios o commits sin subir, avisa y pide una segunda confirmación.

## Estructura

```
init.sh              Punto de entrada único (menús, opciones, flujo)
appflowy-data-backup.sh  Respaldo/restauración de AppFlowy en GitHub + daemon semanal (se instala en ~/.local/bin)
lib/                 Motor
  ui.sh                banner, títulos grandes, mensajes, pausa
  menu.sh              preguntas: sistema, destino, confirmaciones
  core.sh              catálogo de ítems, verificación, reintentos, resumen, borrado
  checks.sh            verificaciones de solo lectura y descargas
  shellrc.sh           edición idempotente de ~/.profile, ~/.bashrc y ~/.zshrc
comun/               Módulos compartidos por ambos sistemas
  00-modo-usb.sh       USB: optimizaciones · Escritorio: revierte las de USB
  10-herramientas-comunes.sh  instaladores idénticos en ambas distros (herdr)
  99-pasos-manuales.sh pasos que debe hacer el usuario al final
INSTALACIONES.md     Qué se instala solo en Ubuntu, solo en Manjaro y en las dos
ubuntu/              «linux conf» (apt, snap, repos externos)
  distro.sh            adaptador de paquetes (apt)
  01-sistema … 09-limpieza
manjaro/             «manjaro conf» (pacman + AUR/yay)
  distro.sh            adaptador de paquetes (pacman/yay)
  01-sistema … 08-limpieza
```

## Qué instala cada sistema

Está detallado en **[INSTALACIONES.md](INSTALACIONES.md)**, separado en tres secciones:
lo que se instala **solo en Ubuntu**, **solo en Manjaro** y **en las dos distros**
(GitHub CLI, Playwright CLI, herdr, AppFlowy, Docker, Brave, Node, pnpm, Bun, Flutter, Claude Code, OpenCode, Tailscale, Antigravity…).

**Modo USB** (ambos sistemas): sysctl de escritura, logs en RAM, planificador BFQ, zram, `noatime`,
`/tmp` en RAM y `profile-sync-daemon`. **Modo Escritorio** revierte lo anterior si se había aplicado.

## Respaldo de AppFlowy

`appflowy-data-backup.sh` hace un respaldo semanal de tus notas de AppFlowy a un repositorio **privado** de GitHub,
funciona como daemon y tiene un menú para respaldar o restaurar. `init.sh` lo instala y lo activa en ambas distros.
Detalles y advertencias de seguridad en [INSTALACIONES.md](INSTALACIONES.md#respaldo-semanal-de-appflowy-a-github-appflowy-data-backupsh).

## Opciones

```bash
./init.sh --ayuda
./init.sh --sistema manjaro --destino usb      # sin preguntas
./init.sh --listar --sistema ubuntu            # ver módulos e ítems
./init.sh --solo docker --solo 06              # solo Docker y el módulo 06
./init.sh --omitir wave                        # todo menos Wave Terminal
./init.sh --solo-usb                           # solo las optimizaciones USB
./init.sh --simular                            # muestra el plan sin instalar nada
```

`--yes` acepta las respuestas por defecto y **nunca** borra el instalador.
No lo ejecutes con `sudo`: pedirá la contraseña cuando haga falta (yay, NVM y Oh My Zsh fallan como root).

## Añadir un programa

En el módulo que corresponda (`ubuntu/` o `manjaro/`):

```bash
# Paquete simple: id, etiqueta, origen (repo|aur), comando a verificar, paquete(s)
register_pkg  vlc   "VLC"      repo vlc vlc
register_aur  cursor "Cursor"  cursor cursor-bin       # AUR (depende de yay)
register_npm  playwright-cli "Playwright CLI" playwright-cli "@playwright/cli@latest" nvm-node   # npm -g (+ dependencia)

# Caso general: una función que verifica y otra que instala
v_mi_app() { cmd_works mi-app --version; }
i_mi_app() { pkg_install mi-app; }
register_item mi-app "Mi App" v_mi_app i_mi_app [dependencia…]
```

- `verify` debe ser de solo lectura y devolver 0 si ya está bien instalado.
- `install` se ejecuta con `set -e` en un subshell; devuelve `$RC_SKIP` si «no aplica» a este equipo.
- Con verify `-` el ítem es una *tarea* que se ejecuta siempre.
