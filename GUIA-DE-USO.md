# Guía de uso

Referencia completa de **LINUX CONF**: cómo está organizado, qué hace cada opción, cómo se ejecuta
una instalación, cómo interpreta los fallos y cómo volver a ejecutarlo sin romper nada.

Para la primera instalación, empieza por [INICIO-RAPIDO.md](INICIO-RAPIDO.md).
Para saber qué se instala en cada distro, consulta [INSTALACIONES.md](INSTALACIONES.md).

---

## 1. Modelo de ejecución

Todo el instalador gira alrededor de tres conceptos.

**Ítem.** Cada programa o configuración es un ítem con un `id` (`docker`, `nvm-node`, `wave`…),
una etiqueta legible, una función de **verificación** y una función de **instalación**.

**Sección.** Los ítems se agrupan en módulos numerados (`01` SISTEMA, `02` NAVEGADORES, …). El
contenido de cada módulo depende de la distro; los ids compartidos se comportan igual en ambas.

**Dependencia.** Un ítem puede depender de otro (`pnpm` depende de Node, todo paquete de AUR depende
de `yay`). Si la dependencia no está disponible, el ítem se **omite con un aviso**, nunca se fuerza.

Estados posibles de un ítem durante la ejecución:

| Estado | Significado |
|---|---|
| `ok` | Instalado y verificado en esta ejecución. |
| `present` | Ya estaba instalado y verificado: se omitió. |
| `skipped` | No aplica a este equipo o le falta una dependencia. |
| `simulated` | `--simular`: se habría instalado. |
| `failed` | No pasó la verificación tras agotar los reintentos. |

El **código de salida** es `0` si ningún ítem quedó en `failed`, y distinto de `0` si alguno falló.

## 2. Ejecución interactiva

```bash
./init.sh
```

1. **Banner** y comprobación de que no eres root.
2. **PASO 1 · Sistema**: Ubuntu o Manjaro, con el actual propuesto por defecto. Si eliges una distro
   cuyo gestor de paquetes no existe en el equipo, vuelve a preguntar (con `--sistema` aborta y pide
   corregir la opción).
3. **PASO 2 · Destino**: Escritorio o USB. Si detecta que `/` está en un dispositivo USB, propone USB.
4. **PASO 3 · Editores**: solo aparece si el plan incluye el módulo de editores.
5. **Auditoría** de solo lectura de lo que hay y lo que falta.
6. **Confirmación** («¿Continuar con la instalación?»).
7. `sudo` una vez y **ejecución del plan**.
8. **Resumen verificado**, **pasos manuales** y oferta de **borrar el instalador**.

## 3. Opciones de línea de comandos

| Opción | Argumento | Efecto |
|---|---|---|
| `--sistema`, `--distro` | `ubuntu` \| `manjaro` | Fija la distro y salta el PASO 1. |
| `--destino` | `escritorio` \| `desktop` \| `usb` | Fija el destino y salta el PASO 2. |
| `--solo`, `--only` | número de módulo o id | Ejecuta **solo** eso. Repetible. |
| `--omitir`, `--skip` | número de módulo o id | **Salta** eso. Repetible. |
| `--solo-usb`, `--only-optimize` | — | Destino USB y solo el módulo `00` (optimizaciones). |
| `--listar`, `--list`, `-l` | — | Muestra módulos e ítems y termina. |
| `--simular`, `--dry-run` | — | No instala, no pide `sudo`, no modifica nada. |
| `--sin-pausa` | — | Quita la pausa de 2 s tras cada ítem. |
| `--yes`, `-y`, `--si` | — | Acepta las respuestas por defecto. |
| `--ayuda`, `--help`, `-h` | — | Ayuda y salida. |

Detalles que conviene conocer:

- Las opciones se pueden combinar en cualquier orden; si repites una, gana la última.
- `--listar` funciona en cualquier equipo: no necesita el gestor de paquetes de la distro elegida.
- Con `--simular`, la elección de una distro «equivocada» solo produce un aviso.
- `--yes` implica: los **tres** editores, conservar los editores ya instalados, responder «sí» a la
  instalación y **no** borrar el instalador. Nunca desinstala nada por su cuenta.
- Los números de módulo de un dígito se normalizan: `--solo 3` equivale a `--solo 03`.

## 4. Elegir módulos e ítems

```bash
./init.sh --listar --sistema ubuntu          # ver ids y módulos
./init.sh --solo 04                          # solo el módulo DOCKER
./init.sh --solo docker --solo 06            # Docker + módulo TERMINAL (Ubuntu)
./init.sh --omitir wave --omitir multimedia  # todo menos Wave y el módulo 07
```

- Se aceptan ids (`docker`, `nvm-node`) y números de módulo (`04`, `06`).
- `--solo` y `--omitir` se aplican a la vez: primero se limita, después se descarta.
- Los editores se filtran con la selección del PASO 3; si `--solo`/`--omitir` excluye el módulo de
  editores, esa pregunta no aparece.
- Si el plan queda vacío, el script avisa y sale sin hacer nada.
- Ejecutar un ítem aislado no instala sus dependencias: si la dependencia no está ya en el equipo,
  el ítem se omite con el motivo (`--solo playwright-cli` sin Node instalado, por ejemplo).

## 5. Destino: Escritorio y USB

El destino no cambia **qué** se instala, sino las optimizaciones del sistema (módulo `00`).

### Modo USB

| Optimización | Qué hace |
|---|---|
| `usb-sysctl` | `vm.swappiness=10`, `vfs_cache_pressure=50`, escrituras agrupadas (`dirty_bytes` 48 MB) en `/etc/sysctl.d/99-usb-optimize.conf`. |
| `usb-journald` | Logs en RAM (`Storage=volatile`, 64 MB) para no escribir en la USB. |
| `usb-bfq` | Regla udev que pone el planificador `bfq` en discos USB. |
| `usb-zram` | Swap comprimido en RAM (`ram/2`, zstd, prioridad 100). Instala `systemd-zram-generator` (Ubuntu) o `zram-generator` (Manjaro). |
| `usb-noatime` | Añade `noatime` a las entradas `ext4/btrfs/xfs/f2fs` de `/etc/fstab`; guarda copia en `/etc/fstab.bak-new-linux-conf` y revierte si `findmnt --verify` falla. |
| `usb-tmp` | `/tmp` en RAM habilitando `tmp.mount` (se aplica en el próximo arranque). |
| `usb-psd` | `profile-sync-daemon`: perfiles de navegador en RAM, sincronizados a disco. |

Los archivos que crea llevan la marca `Generado por new-linux-conf (modo USB)`: solo se revierten
esos, nunca archivos ajenos.

### Modo Escritorio

Registra un único ítem, `usb-revertir`, que elimina las configuraciones USB anteriores (si las
hubiera), recarga `sysctl`, reinicia `journald`, recarga `udev` y `systemd`. `zram` se desactiva al
reiniciar.

```bash
./init.sh --solo-usb --sistema ubuntu --destino usb   # solo aplicar optimizaciones
./init.sh --sistema ubuntu --destino escritorio        # revertirlas
```

## 6. Editores de código

Se eligen siempre en el PASO 3 (o con `--yes`, que instala los tres).

| Elección | Ubuntu | Manjaro |
|---|---|---|
| Antigravity IDE | repositorio apt de Google | AUR `antigravity-ide` |
| Cursor | `.deb` oficial (solo amd64) | AUR `cursor-bin` |
| VS Code | repositorio apt de Microsoft | AUR `visual-studio-code-bin` |

- Sintaxis de selección: `1`, `2`, `3`, `1 3`, `1,3`, `13` o `todos`.
- Un editor instalado que **no** elegiste genera una pregunta: **conservarlo** o **desinstalarlo**.
  Si eliges desinstalar, el ítem `purga-<id>` se coloca justo antes de la sección de limpieza.
- Con `--omitir <editor>` no se toca ese editor en absoluto.
- En `--simular` solo se informa de lo que ocurriría.

## 7. Durante la instalación

### Permisos

El script pide `sudo` una vez al empezar y mantiene la sesión activa cada 50 s mientras dura la
ejecución. En `--simular` no se pide.

### Red

Antes de empezar comprueba la conexión (GitHub y, si falla, Google). Si no hay, espera 30 s; durante
las reparaciones espera hasta 90 s.

### Reintentos y reparación

Cada ítem se instala, se **vuelve a verificar** y, si no pasa, se diagnostica la causa por la salida
del intento:

| Causa | Detección | Reparación |
|---|---|---|
| Bloqueo | otro `apt`/`dpkg`/`pacman` en uso | espera hasta 2 min y, en Manjaro, elimina un `db.lck` huérfano |
| Red | DNS, timeout, descarga fallida | espera hasta 90 s a que vuelva la conexión |
| Claves | `NO_PUBKEY`, firmas, keyring | `pacman-key` (Manjaro) o refresco de índices (Ubuntu) |
| Disco | sin espacio | limpieza de caché y `df -h` |
| No encontrado | paquete inexistente o índice viejo | refresco de índices |
| Desconocido | — | reparación general del gestor |

- Hasta **3 intentos** por ítem; a partir del segundo se ejecuta además una reparación general
  (`dpkg --configure -a` + `apt -f install` en Ubuntu; desbloqueo + `pacman -Syu` en Manjaro).
- Lo que sigue fallando pasa por una **REVISIÓN final**: reparación general y **2 intentos** más.
- Si el instalador devuelve un código de error pero la verificación posterior pasa, se da por
  correcto con un aviso.
- Un instalador puede devolver `RC_SKIP` (10) para indicar «no aplica»: el ítem queda como omitido,
  no como fallo.

### Casos de «no aplica» previstos

| Ítem | Motivo |
|---|---|
| `cursor`, `chrome`, `brave`, `appflowy`, `wallpapers` | paquete solo para `amd64` (o `.deb` inexistente para la arquitectura). |
| `wave` | no hay `.deb` para esa arquitectura. |
| `sin-firefox` (Manjaro) | otro paquete depende de Firefox. |

## 8. Resumen, registro y caché

Al terminar se re-verifica **todo** el plan, no solo lo recién instalado:

```
  N instalados ahora  ·  N ya estaban  ·  N omitidos  ·  N con fallos
```

| Recurso | Ruta |
|---|---|
| Registro de cada ejecución | `~/.local/state/new-linux-conf/instalacion-AAAAMMDD-HHMMSS.log` |
| Caché de la LTS de Node consultada | `~/.cache/new-linux-conf/node-lts` |
| Respaldo de `/etc/fstab` (modo USB) | `/etc/fstab.bak-new-linux-conf` |

`XDG_STATE_HOME` y `XDG_CACHE_HOME` se respetan si están definidos. `MAX_RETRIES` permite cambiar el
número de intentos (`MAX_RETRIES=1 ./init.sh`, útil con mala conexión para no esperar tanto).

## 9. Pasos manuales automáticos

La sección **PENDIENTE** se calcula con el estado real del sistema, así que también es correcta al
volver a ejecutar el instalador sin instalar nada nuevo:

| Condición | Paso que se muestra |
|---|---|
| Algún ítem falló | Volver a ejecutar `./init.sh` y revisar el log. |
| Kernel o componentes actualizados | Reiniciar el equipo. |
| Optimizaciones USB nuevas | Reiniciar para activarlas del todo. |
| Docker instalado y sin el grupo en la sesión | `newgrp docker` o cerrar sesión. |
| Tailscale sin autorizar | `sudo tailscale up`. |
| Git sin identidad | `git config --global user.name` / `user.email`. |
| Node, pnpm, Bun, Rust, rutas nuevas | Abrir terminal nueva o `exec $SHELL`. |
| CLIs de IA recién instaladas | Ejecutar cada una para iniciar sesión. |
| Hermes nuevo | `hermes setup`. |
| `gh` nuevo | `gh auth login`. |
| Playwright CLI nuevo | `playwright-cli install-browser` (en Ubuntu con `--with-deps`). |
| Respaldo de AppFlowy | Repo público (**urgente**), inexistente, no verificable o `gh` sin sesión. |
| Flutter nuevo | `flutter doctor`. |
| Editores, navegadores y apps nuevas | Abrirlos e iniciar sesión. |
| Terminal configurada | Elegir la fuente MesloLGS NF y ejecutar `p10k configure`. |

## 10. Volver a ejecutar

Es la forma prevista de recuperar lo que falló: lo instalado y verificado se omite, lo pendiente se
reintenta y las tareas (`actualizar`, `limpieza`) se ejecutan siempre.

```bash
./init.sh --sistema ubuntu --destino escritorio
./init.sh --sistema ubuntu --solo 03 --omitir flutter   # reintentar solo DESARROLLO sin Flutter
```

Son **tareas que siempre se ejecutan** (no tienen verificación previa): `actualizar` y `limpieza`.
El resto solo se omite si pasa su verificación real.

## 11. Borrar el instalador

Se pregunta al final y por defecto es **No**. `--yes` y `--simular` nunca borran.

Antes de borrar, el script comprueba que:

- la ruta no sea `/`, `$HOME` ni vacía, y que contenga `init.sh`;
- si es un repositorio git, avisa de cambios sin guardar y commits sin subir, y exige una segunda
  confirmación; si no tiene remoto, avisa de que el historial solo existe ahí.

## 12. Solución de problemas

| Situación | Causa y solución |
|---|---|
| «No ejecutes este script como root ni con `sudo ./init.sh`» | Vuelve a ejecutarlo con tu usuario normal. |
| «Elegiste X, pero este equipo no tiene su gestor de paquetes» | Estás configurando la distro equivocada, o `--sistema` no coincide con el equipo. |
| Un ítem se omite «depende de …» | Instala o arregla la dependencia primero (por ejemplo Node para `pnpm`/`playwright-cli`). |
| `flutter` falla en Ubuntu | Necesita `snapd`; el módulo instala antes las dependencias de escritorio (`clang`, `cmake`, `ninja-build`, `libgtk-3-dev`…). |
| El node activo no es LTS | El instalador consulta la LTS vigente en `nodejs.org`; sin conexión solo exige «que sea LTS». |
| Iconos rotos en la terminal | Falta la fuente: elige **MesloLGS NF** (Powerlevel10k) o **CascadiaCode Nerd Font**. |
| `zsh` no es el shell por defecto tras instalarlo | Hay que cerrar sesión y volver a entrar. |
| Docker pide `sudo` | El grupo `docker` solo se aplica en una sesión nueva: `newgrp docker`. |
| El respaldo de AppFlowy no sube | El repositorio es público o no se puede comprobar: `appflowy-data-backup.sh --status`. |
| `/tmp` sigue en disco tras el modo USB | `tmp.mount` se activa en el próximo arranque. |
| `zram` no aparece | Se activa al reiniciar; el instalador avisa si no pudo arrancarlo ahora. |

Si un ítem falla de forma reproducible, el registro de la ejecución contiene la salida completa del
instalador y la línea de error que se muestra en el resumen.

## 13. Referencia rápida

```bash
./init.sh --ayuda                                  # todas las opciones
./init.sh --listar --sistema manjaro               # catálogo de Manjaro
./init.sh --simular --sistema ubuntu               # plan sin ejecutar
./init.sh --sistema manjaro --destino usb          # instalación desatendida de preguntas
./init.sh --solo docker --solo 06                  # módulos concretos
./init.sh --omitir wave                            # todo menos un ítem
./init.sh --solo-usb                               # solo optimizaciones USB
tail -f ~/.local/state/new-linux-conf/*.log        # seguir el registro

appflowy-data-backup.sh --status                   # estado del respaldo de AppFlowy
appflowy-data-backup.sh --backup                   # respaldar ahora
```
