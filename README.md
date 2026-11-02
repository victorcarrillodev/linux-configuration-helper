# LINUX CONF

Instalador y configurador automático para **Ubuntu** (`linux conf`) y **Manjaro** (`manjaro conf`),
pensado tanto para un **escritorio** como para un sistema **portable en USB**.

Un solo comando, tres preguntas y el resto lo hace el instalador: audita qué falta, instala solo lo
pendiente, verifica que todo funcione de verdad y te dice qué te queda por hacer a mano.

```bash
./init.sh
```

---

## Documentación

| Documento | Para qué sirve |
|---|---|
| **[INICIO-RAPIDO.md](INICIO-RAPIDO.md)** | Primera instalación en 5 minutos, paso a paso. |
| **[GUIA-DE-USO.md](GUIA-DE-USO.md)** | Menús, todas las opciones, modos Escritorio/USB, fallos y registro. |
| **[INSTALACIONES.md](INSTALACIONES.md)** | Catálogo completo: qué se instala en cada distro, cómo, cómo se verifica y de qué depende. |

---

## Requisitos

- Ubuntu o Manjaro (la configuración de una distro **no** se aplica sobre la otra).
- Usuario con `sudo`. **No ejecutes el script como root**: `yay`, NVM y Oh My Zsh fallan como root,
  y el instalador pedirá la contraseña cuando la necesite.
- Conexión a internet (salvo en `--simular`).
- Bash 4.3+, `curl`, `git` y el gestor de paquetes de la distro (`apt` o `pacman`).

## Inicio rápido

```bash
git clone https://github.com/victorcarrillodev/linux-configuration-helper.git
cd linux-configuration-helper
./init.sh
```

1. **PASO 1 · Sistema** — Ubuntu o Manjaro. Detecta el actual y lo propone.
2. **PASO 2 · Destino** — Escritorio (disco interno) o USB (sistema portable).
3. **PASO 3 · Editores** — Antigravity IDE, Cursor y/o VS Code (al menos uno).

Después verás una **auditoría** de la lista con lo que ya está instalado y lo que falta, y una
confirmación. A partir de ahí no hay que tocar nada: al terminar obtendrás un **resumen verificado**
y la lista de **pasos manuales** que te corresponden.

> ¿Solo quieres ver el plan? `./init.sh --simular` no instala ni modifica nada.

## Cómo funciona

- **Verificación real.** Cada programa tiene su propia comprobación: no basta con que exista un archivo,
  se ejecuta `--version`, se consultan paquetes, grupos, servicios y configuración.
- **Auditoría previa** de solo lectura (sin `sudo`) con tabla `✔ instalado / ✘ pendiente / ○ tarea`.
- **Solo lo pendiente.** Volver a ejecutarlo es seguro: lo que ya está bien se omite.
- **Reintentos con diagnóstico.** Si algo falla, se clasifica la causa (red, bloqueo del gestor de
  paquetes, claves, disco, paquete no encontrado), se repara y se reintenta hasta 3 veces; lo que
  sigue fallando pasa por una **revisión final** con 2 intentos más.
- **Dependencias respetadas.** Si falla algo base (p. ej. Node.js), lo que depende de ello se omite
  con un aviso claro en vez de fallar en cadena.
- **Resumen final** con verificación de todo, pasos manuales calculados según el estado real del
  sistema y registro completo en `~/.local/state/new-linux-conf/`.
- **Borrar el instalador** siempre se pregunta (por defecto **No**), con protección extra si la
  carpeta es un repositorio git con cambios o commits sin subir.

## Estructura del repositorio

```
init.sh                     Punto de entrada único: opciones, menús y flujo
appflowy-data-backup.sh     Respaldo/restauración de AppFlowy en GitHub + daemon semanal
lib/                        Motor
  ui.sh                     Banner, títulos, mensajes, pausa entre instalaciones
  menu.sh                   Preguntas: sistema, destino, editores, confirmaciones
  core.sh                   Catálogo de ítems, verificación, reintentos, resumen, borrado
  checks.sh                 Comprobaciones de solo lectura, red y descargas
  shellrc.sh                Edición idempotente de ~/.profile, ~/.bashrc y ~/.zshrc
comun/                      Módulos compartidos por ambas distros
  00-modo-usb.sh            USB: optimizaciones · Escritorio: las revierte
  10-herramientas-comunes.sh Instaladores idénticos en las dos distros (herdr, respaldo de AppFlowy)
  99-pasos-manuales.sh      Calcula los pasos que debe hacer el usuario al final
ubuntu/                     «linux conf» (apt, snap, repositorios externos)
  distro.sh                 Adaptador de paquetes (apt)
  01-sistema … 09-limpieza
manjaro/                    «manjaro conf» (pacman + AUR con yay)
  distro.sh                 Adaptador de paquetes (pacman/yay)
  01-sistema … 08-limpieza
```

## Opciones

| Opción | Efecto |
|---|---|
| `--sistema ubuntu\|manjaro` | Elige la distro sin preguntar. |
| `--destino escritorio\|usb` | Elige el destino sin preguntar. |
| `--solo <n\|id>` | Ejecuta solo ese módulo (`03`) o ítem (`docker`). Repetible. |
| `--omitir <n\|id>` | Salta ese módulo o ítem. Repetible. |
| `--solo-usb` | Solo las optimizaciones USB y termina. |
| `--listar` | Muestra módulos e ítems de la distro elegida. |
| `--simular` | Muestra el plan sin instalar nada. |
| `--sin-pausa` | Quita la pausa de 2 s tras cada instalación. |
| `--yes`, `-y` | Acepta las respuestas por defecto (editores: los tres; nunca borra el instalador). |
| `--ayuda`, `-h` | Ayuda completa. |

```bash
./init.sh --sistema manjaro --destino usb      # sin preguntas
./init.sh --solo docker --solo 06              # solo Docker y el módulo 06
./init.sh --omitir wave                        # todo menos Wave Terminal
./init.sh --simular                            # ver el plan sin tocar nada
```

## Modo Escritorio y modo USB

El **modo USB** aplica optimizaciones para reducir escrituras y mejorar la respuesta de un sistema
portable: `sysctl` de memoria, logs en RAM, planificador BFQ, `zram`, `noatime`, `/tmp` en RAM y
`profile-sync-daemon`. El **modo Escritorio** revierte esas configuraciones si venían de una
instalación anterior. El detalle está en [INSTALACIONES.md](INSTALACIONES.md#4-acciones-sobre-el-sistema).

## Respaldo semanal de AppFlowy

`appflowy-data-backup.sh` respalda tus notas de AppFlowy en un repositorio **privado** de GitHub,
funciona como servicio de usuario y tiene un menú para respaldar, restaurar o ver el estado.
`init.sh` lo instala y lo activa en ambas distros.

```bash
appflowy-data-backup.sh           # menú interactivo
appflowy-data-backup.sh --status  # repo, visibilidad, daemon, último respaldo
```

> El repositorio **debe ser privado**: antes de cada subida el script comprueba la visibilidad y se
> niega a subir si es público o si no puede comprobarlo. Advertencias completas en
> [INSTALACIONES.md](INSTALACIONES.md#8-respaldo-semanal-de-appflowy-a-github).

## Añadir un programa

En el módulo que corresponda (`ubuntu/` o `manjaro/`):

```bash
# Paquete simple: id, etiqueta, origen (repo|aur), comando a verificar, paquete(s)
register_pkg  vlc   "VLC"      repo vlc vlc
register_aur  cursor "Cursor"  cursor cursor-bin       # AUR (depende de yay)
register_npm  playwright-cli "Playwright CLI" playwright-cli "@playwright/cli@latest" nvm-node  # npm -g (+ dependencia)

# Caso general: una función que verifica y otra que instala
v_mi_app() { cmd_works mi-app --version; }
i_mi_app() { pkg_install mi-app; }
register_item mi-app "Mi App" v_mi_app i_mi_app [dependencia…]
```

- `verify` debe ser de solo lectura y devolver 0 si ya está bien instalado.
- `install` se ejecuta con `set -e` en un subshell; devuelve `$RC_SKIP` si «no aplica» a este equipo.
- Con verify `-` el ítem es una *tarea* que se ejecuta siempre.
- Si algo se instala igual en ambas distros, define las funciones una sola vez en
  `comun/10-herramientas-comunes.sh` y registra el ítem en cada distro con el **mismo id**.
- Después actualiza [INSTALACIONES.md](INSTALACIONES.md).

## Seguridad

- No se ejecuta como root ni con `sudo ./init.sh`.
- Las claves y repositorios externos se verifican por firma (`signed-by`) antes de añadirlos.
- El borrado del instalador exige confirmación explícita y comprueba la ruta y el estado de git.
- El respaldo de AppFlowy nunca sube a un repositorio público.
