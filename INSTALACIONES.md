# Qué se instala en cada sistema

Catálogo de referencia de **LINUX CONF**: todo lo que hace `./init.sh`, separado en lo que se instala
**solo en Ubuntu**, **solo en Manjaro** y **en las dos distros**, con el origen de cada paquete, cómo
se verifica, de qué depende y qué archivos del sistema se modifican.

La lista exacta y siempre actualizada se obtiene del propio instalador:

```bash
./init.sh --listar --sistema ubuntu
./init.sh --listar --sistema manjaro
```

Convención: **Ubuntu** = `linux conf` (apt, snap y repositorios externos) · **Manjaro** =
`manjaro conf` (pacman y AUR con `yay`).

**Índice**

1. [Mapa de módulos](#1-mapa-de-módulos)
2. [En las dos distros](#2-en-las-dos-distros-al-mismo-tiempo)
3. [Solo Ubuntu](#3-solo-en-ubuntu-linux-conf)
4. [Acciones sobre el sistema](#4-acciones-sobre-el-sistema)
5. [Solo Manjaro](#5-solo-en-manjaro-manjaro-conf)
6. [Dependencias entre ítems](#6-dependencias-entre-ítems)
7. [Orígenes externos](#7-orígenes-externos)
8. [Respaldo semanal de AppFlowy a GitHub](#8-respaldo-semanal-de-appflowy-a-github)
9. [Mantener este documento actualizado](#9-mantener-este-documento-actualizado)

---

## 1. Mapa de módulos

| Módulo | Ubuntu (`linux conf`) | Manjaro (`manjaro conf`) |
|---|---|---|
| `00` | ESCRITORIO / USB | ESCRITORIO / USB |
| `01` | SISTEMA | SISTEMA |
| `02` | NAVEGADORES | NAVEGADORES |
| `03` | DESARROLLO | DESARROLLO |
| `04` | DOCKER | DOCKER |
| `05` | EDITORES | EDITORES |
| `06` | TERMINAL | IA |
| `07` | MULTIMEDIA | PRODUCTIVIDAD |
| `08` | PRODUCTIVIDAD | LIMPIEZA |
| `09` | LIMPIEZA | — |

Las secciones `00` (optimizaciones de destino) son **comunes** y viven en `comun/00-modo-usb.sh`;
los ítems se describen en la sección 4.

Columnas usadas a partir de aquí:

- **id** — nombre que aceptan `--solo` y `--omitir`.
- **Cómo se instala** — paquete, repositorio, script oficial o `.deb`/AUR.
- **Verificación** — la comprobación real que decide si el ítem ya está instalado.
- **Depende de** — ítem que debe estar disponible para ejecutarlo.

---

## 2. En las dos distros al mismo tiempo

El programa es el mismo; cambia **cómo** se instala en cada sistema. Los ids compartidos tienen el
mismo comportamiento en ambas distros.

| Programa | id | Ubuntu (linux conf) | Manjaro (manjaro conf) | Verificación | Depende de |
|---|---|---|---|---|---|
| Actualización del sistema | `actualizar` | `apt update` + `apt upgrade` | `pacman -Syu` | **Tarea**: se ejecuta siempre | — |
| Herramientas base y git | `utilidades-base` / `base-devel` | `curl wget git gnupg build-essential htop net-tools software-properties-common apt-transport-https ca-certificates unzip xz-utils zip libglu1-mesa` | grupo `base-devel` + `git` | los paquetes indicados | — |
| Eliminar Firefox | `sin-firefox` | `snap remove --purge` + `apt purge`, y borra `~/.mozilla` y `~/snap/firefox` | `pacman -Rns firefox` | no queda Firefox (deb ni snap) | — |
| Brave Nightly | `brave` | repositorio apt oficial de Brave Nightly (`brave-browser-nightly`) | AUR `brave-nightly-bin` | comando `brave-browser-nightly` | — |
| Google Chrome | `chrome` | **canal Dev**: `.deb` oficial `google-chrome-unstable` | **canal estable**: AUR `google-chrome` | comando `google-chrome-unstable` / `google-chrome-stable` | — |
| Node.js LTS | `nvm-node` / `nodejs` | NVM + **Node LTS** vigente; desinstala cualquier otra versión de nvm | `nodejs-lts`; si existe `nodejs` (no LTS) lo retira | `node`, `npm` y que la versión activa sea la LTS actual | — |
| pnpm | `pnpm` | `npm -g pnpm` | pacman `pnpm` | `pnpm --version` | Node |
| Bun | `bun` | instalador oficial (`bun.sh/install`) | pacman `bun` | `bun --version` | utilidades base (solo Ubuntu) |
| Flutter | `flutter` | snap `flutter --classic` + `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev` | AUR `flutter-bin` | comando `flutter` y snap registrado (Ubuntu) | — |
| Tailscale | `tailscale` | instalador oficial + `systemctl enable tailscaled` | pacman `tailscale` + servicio | `tailscale version` y servicio habilitado | utilidades base (solo Ubuntu) |
| GitHub CLI | `gh` | repositorio apt oficial de GitHub | `github-cli` (repo) | `gh --version` | utilidades base (solo Ubuntu) |
| Playwright CLI | `playwright-cli` | `npm -g @playwright/cli@latest` | igual, con prefijo `~/.npm-global` (sin sudo) | `playwright-cli --version` | Node (`nvm-node` / `entorno-js`) |
| herdr | `herdr` | instalador oficial → `~/.local/bin` | igual | `herdr --version` | utilidades base (solo Ubuntu) |
| Docker + Compose + Buildx | `docker` | repositorio oficial `docker-ce` + `usermod -aG docker` | pacman `docker docker-compose docker-buildx` + grupo | `docker --version`, `docker compose version`, grupo y servicio | utilidades base (solo Ubuntu) |
| Antigravity IDE | `antigravity` | repositorio apt de Google | AUR `antigravity-ide` | comando `antigravity` | utilidades base / `yay` |
| Cursor | `cursor` | `.deb` oficial (solo amd64) | AUR `cursor-bin` | comando `cursor` | utilidades base / `yay` |
| VS Code | `vscode` | repositorio apt de Microsoft | AUR `visual-studio-code-bin` (el original de Microsoft) | comando `code` y paquete (Ubuntu) | utilidades base / `yay` |
| AppFlowy | `appflowy` | `.deb` oficial de GitHub (última versión, solo amd64) | AUR `appflowy-bin` | paquete y binario `/usr/lib/AppFlowy/AppFlowy` (Ubuntu) | utilidades base / `yay` |
| Respaldo de AppFlowy | `appflowy-backup` | script copiado a `~/.local/bin` + servicio de usuario + `git` y `sqlite3` | igual, con `sqlite` | script idéntico, herramientas y daemon instalados | utilidades base / `base-devel` |
| Limpieza final | `limpieza` | `autoremove` + `autoclean` + `clean` | caché de pacman/yay + huérfanos (`pacman -Qtdq`) | **Tarea**: se ejecuta siempre | — |

> Los editores se eligen en el PASO 3 del menú (uno o varios). Si un editor que no elegiste está
> instalado, el instalador pregunta si conservarlo o desinstalarlo; en ese caso añade un ítem
> `purga-<editor>` justo antes de la limpieza. Ver [GUIA-DE-USO.md](GUIA-DE-USO.md#6-editores-de-código).

---

## 3. Solo en Ubuntu (linux conf)

| Programa / configuración | id | Cómo se instala | Verificación | Depende de |
|---|---|---|---|---|
| Gemini CLI | `gemini-cli` | `npm -g @google/gemini-cli` | `gemini --version` | `nvm-node` |
| Claude Code (CLI) | `claude-code` | `npm -g @anthropic-ai/claude-code` | `claude --version` | `nvm-node` |
| Codex CLI | `codex` | `npm -g @openai/codex` | `codex --version` | `nvm-node` |
| OpenCode | `opencode` | `npm -g opencode-ai` | `opencode --version` | `nvm-node` |
| Hermes Agent (Nous Research) | `hermes` | instalador oficial con `--skip-setup` (sin asistente) | comando `hermes` | `utilidades-base` |
| PostgreSQL | `postgresql` | `postgresql` + `postgresql-contrib`, servicio habilitado | paquetes, comando `psql` y servicio `postgresql` habilitado | — |
| Variety + wallpapers | `variety`, `wallpapers` | apt `variety`; clona `victorcarrillodev/wallpapers` en `~/wallpapers` (~260 MB) | paquete `variety`; `~/wallpapers` con contenido | — |
| Zsh y utilidades | `zsh-paquetes` | `zsh fontconfig fonts-font-awesome figlet toilet lolcat` | los 6 paquetes instalados | — |
| Oh My Zsh | `oh-my-zsh` | instalador oficial (`--unattended`, sin cambiar el shell) | `~/.oh-my-zsh/oh-my-zsh.sh` | `zsh-paquetes` |
| Fuente CascadiaCode Nerd Font | `fuente-cascadia` | `.tar.xz` de nerd-fonts → `~/.local/share/fonts` | archivos `CaskaydiaCove*` y `fc-cache` aplicado | `zsh-paquetes` |
| Fuente MesloLGS NF | `fuente-meslo` | 4 `.ttf` de powerlevel10k-media → `~/.local/share/fonts` | los 4 archivos presentes | `zsh-paquetes` |
| Wave Terminal | `wave` | `.deb` de la última release de GitHub (según arquitectura) | paquete `waveterm` o comandos `waveterm`/`wave` | `utilidades-base` |
| Powerlevel10k + plugins | `p10k` | clones en `~/.oh-my-zsh/custom`: `powerlevel10k`, `zsh-autosuggestions`, `zsh-syntax-highlighting` | los tres archivos presentes | `oh-my-zsh` |
| Configuración de `~/.zshrc` | `zshrc` | tema p10k, plugins (`git`, `zsh-autosuggestions`, `web-search`, `docker`, `docker-compose`, `python`, `zsh-syntax-highlighting`), `POWERLEVEL9K_INSTANT_PROMPT=off`, bloques NVM/pnpm/bun, banner y PATH | todos los marcadores, tema, plugins y bloques presentes | `p10k` |
| Zsh como shell por defecto | `shell-zsh` | añade `zsh` a `/etc/shells` y `chsh -s` | shell del usuario termina en `/zsh` | `zsh-paquetes` |
| Rutas (PATH) en bash | `entorno-bash` | bloques de PATH en `~/.profile` y `~/.bashrc` | bloques correctos en ambos archivos | — |
| LibreOffice | `libreoffice` | PPA `libreoffice/ppa` y paquetes en español (`libreoffice-l10n-es`, `libreoffice-help-es`, estilo Sukapura) | los paquetes de idioma y `libreoffice-core` | `utilidades-base` |
| Códecs multimedia | `codecs` | `ubuntu-restricted-extras`, `ffmpeg` y plugins GStreamer (base/good/bad/ugly/libav/vaapi), acepta la licencia de fuentes de Microsoft | todos los paquetes de la lista | `utilidades-base` |
| VLC | `vlc` | apt `vlc` | paquete `vlc` | — |
| MPV | `mpv` | apt `mpv` | paquete `mpv` | — |

**Notas de Ubuntu**

- `postgresql`, `zsh-paquetes`, `oh-my-zsh`, las fuentes, `p10k`, `zshrc`, `shell-zsh`, `libreoffice`,
  `codecs`, `vlc`, `mpv`, `variety` y `wallpapers` no existen en el catálogo de Manjaro.
- `pnpm`, `gemini-cli`, `claude-code`, `codex`, `opencode` y `playwright-cli` se instalan como
  paquetes globales de npm y por eso dependen de `nvm-node` (Node LTS).
- `bun`, `hermes`, `tailscale`, `gh`, `herdr`, `wave`, `docker` y `appflowy` usan el instalador o
  repositorio oficial, no el repositorio de Ubuntu.

---

## 4. Acciones sobre el sistema

Todo lo que el instalador modifica fuera de «instalar paquetes». En la columna **Cómo se revierte**
se indica lo que el propio instalador deshace (si algo) y lo que queda a tu cargo.

| Recurso | Ubuntu | Manjaro | Cómo se revierte |
|---|---|---|---|
| Repositorios apt externos | `/etc/apt/sources.list.d/`: `brave-browser-nightly`, `docker.sources`, `vscode.list`, `antigravity.list`, `github-cli.list`; PPA de LibreOffice; `multiverse` | — | Borrar el archivo del repo y la clave de `/etc/apt/keyrings`. |
| Claves de repositorios | `/etc/apt/keyrings/`: Brave, `docker.asc`, `packages.microsoft.gpg`, `antigravity-repo-key.gpg`, `githubcli-archive-keyring.gpg` | Llavero de pacman (`pacman-key`) | Al desinstalar el paquete correspondiente. |
| Grupo `docker` | `usermod -aG docker $USER` | igual | `sudo gpasswd -d $USER docker`. |
| Servicios habilitados | `docker`, `postgresql`, `tailscaled` | `docker`, `tailscaled` | `sudo systemctl disable --now <unidad>`. |
| Shell por defecto | `chsh -s $(command -v zsh)` + `/etc/shells` | — | `chsh -s /bin/bash`. |
| `~/.zshrc` | Tema, plugins, `POWERLEVEL9K_INSTANT_PROMPT=off`, bloques NVM/pnpm/bun, banner y PATH (idempotente, con marcadores) | — | Quitar los bloques marcados. |
| `~/.profile`, `~/.bashrc` | Bloques `# >>> linux-conf PATH … >>>` | Líneas de PATH de npm/pnpm/bun y prefijo `npm config set prefix ~/.npm-global` | Quitar los bloques; en Manjaro, `npm config delete prefix`. |
| Firefox | Borra `~/.mozilla` y `~/snap/firefox` (perfiles incluidos) | `pacman -Rns firefox` | Reinstalar Firefox. |
| Wallpapers | Clona `victorcarrillodev/wallpapers` en `~/wallpapers` (~260 MB) | — | No se borra nunca si la carpeta tiene contenido. |
| Fuentes | `~/.local/share/fonts` (CascadiaCode, MesloLGS NF) | — | Borrar los archivos y `fc-cache -f`. |
| Oh My Zsh | `~/.oh-my-zsh` (custom: temas y plugins) | — | Borrar la carpeta. |
| `npm` global | — | Prefijo `~/.npm-global` (sin `sudo`) | `npm config delete prefix`. |
| Swap comprimido | `systemd-zram-generator` + `/etc/systemd/zram-generator.conf` | `zram-generator` + mismo archivo | Modo Escritorio elimina el archivo; el paquete se queda. |
| Memoria y escrituras | `/etc/sysctl.d/99-usb-optimize.conf` | igual | Modo Escritorio lo elimina y recarga `sysctl`. |
| Logs | `/etc/systemd/journald.conf.d/99-usb-optimize.conf` (`Storage=volatile`) | igual | Modo Escritorio lo elimina y reinicia `journald`. |
| Planificador de E/S | `/etc/udev/rules.d/60-usb-ioscheduler.rules` (`bfq` en USB) | igual | Modo Escritorio lo elimina y recarga `udev`. |
| `/etc/fstab` | `noatime` en entradas `ext4/btrfs/xfs/f2fs`, con respaldo `/etc/fstab.bak-new-linux-conf` | igual | Restaurar el respaldo y remontar. |
| `/tmp` en RAM | `tmp.mount` habilitado | igual | `sudo systemctl disable tmp.mount`. |
| Perfiles de navegador | `profile-sync-daemon` + `psd.service` de usuario | igual | `systemctl --user disable psd.service`. |
| Respaldo de AppFlowy | `~/.local/bin/appflowy-data-backup.sh`, servicio de usuario y `~/.config/appflowy-data-backup/config` | igual | `appflowy-data-backup.sh --uninstall-daemon`. |

Con **destino Escritorio** se ejecuta `usb-revertir`, que solo elimina los archivos que llevan la
marca `Generado por new-linux-conf (modo USB)`; nunca toca configuraciones ajenas. `zram` queda
desactivado tras reiniciar. Los archivos del modo USB se detallan en la
[GUIA-DE-USO.md](GUIA-DE-USO.md#5-destino-escritorio-y-usb).

---

## 5. Solo en Manjaro (manjaro conf)

| Programa / configuración | id | Cómo se instala | Verificación | Depende de |
|---|---|---|---|---|
| yay (ayudante de AUR) | `yay` | repo; si no está, compila `yay-bin` desde AUR con `makepkg` | `yay --version` | `base-devel` |
| Rust | `rust` | `rustup` + `rustup default stable` | `rustc --version` | — |
| Claude Desktop | `claude-desktop` | AUR `claude-desktop` | comando `claude-desktop` | `yay` |
| Claude Code (CLI) | `claude-code` | AUR `claude-code` | comando `claude` | `yay` |
| OpenCode | `opencode` | AUR `opencode-bin` | comando `opencode` | `yay` |
| WhatsDesk (WhatsApp) | `whatsdesk` | AUR `whatsdesk-bin` | comando `whatsdesk` | `yay` |
| Rutas globales de JS | `entorno-js` | `npm config set prefix ~/.npm-global` y líneas de PATH en `~/.zshrc` y `~/.bashrc` | prefijo de npm y líneas presentes | `nodejs` |

**Notas de Manjaro**

- **Todos** los paquetes de AUR (`brave`, `chrome`, `flutter`, `appflowy`, `whatsdesk`, los tres
  editores y las herramientas de IA) dependen de `yay`, que instala el módulo `01`.
- No hay NVM: Node es el `nodejs-lts` del sistema y las herramientas globales de npm se instalan sin
  `sudo` gracias al prefijo `~/.npm-global` de `entorno-js`.
- Gemini CLI, Codex CLI, Hermes Agent, PostgreSQL, Flutter por snap, Zsh, Wave Terminal, LibreOffice,
  códecs, VLC, MPV, Variety, los wallpapers y el módulo TERMINAL completo son exclusivos de Ubuntu.

---

## 6. Dependencias entre ítems

Si una dependencia falla u no está disponible, el ítem dependiente se **omite con un aviso**, no se
instala a medias.

**Comunes**

```
yay (Manjaro) ──> todos los ítems de AUR
nodejs / nvm-node ──> pnpm · playwright-cli
entorno-js (Manjaro) ──> playwright-cli
```

**Ubuntu**

```
utilidades-base ──> bun · hermes · tailscale · gh · herdr · docker · wave · appflowy · appflowy-backup
                   · libreoffice · codecs · vscode · antigravity · cursor
nvm-node ─────────> pnpm · gemini-cli · claude-code · codex · opencode · playwright-cli
zsh-paquetes ─────> oh-my-zsh · fuente-cascadia · fuente-meslo · shell-zsh
oh-my-zsh ────────> p10k
p10k ─────────────> zshrc
```

**Manjaro**

```
base-devel ──> yay · appflowy-backup
yay ─────────> brave · chrome · flutter · appflowy · whatsdesk · claude-desktop · claude-code
               · opencode · antigravity · cursor · vscode
nodejs ──────> entorno-js
entorno-js ──> playwright-cli
```

---

## 7. Orígenes externos

**Ubuntu**

| Uso | Origen |
|---|---|
| Brave Nightly | `brave-browser-apt-nightly.s3.brave.com` (clave + repo apt, solo amd64) |
| Google Chrome Dev | `dl.google.com/linux/direct/google-chrome-unstable_current_amd64.deb` |
| Docker CE | `download.docker.com/linux/ubuntu` (clave en `/etc/apt/keyrings/docker.asc`) |
| VS Code | `packages.microsoft.com/repos/code` |
| Antigravity | `us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev` |
| GitHub CLI | `cli.github.com/packages` |
| LibreOffice | `ppa:libreoffice/ppa` |
| Cursor | `downloader.cursor.sh/deb/x64` |
| Wave Terminal | última release de `wavetermdev/waveterm` (API de GitHub) |
| AppFlowy | última release de `AppFlowy-IO/AppFlowy` (API de GitHub) |
| Wallpapers | `github.com/victorcarrillodev/wallpapers` |
| NVM | `raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh` |
| Oh My Zsh | instalador oficial de `ohmyzsh/ohmyzsh` |
| Fuentes Nerd | releases de `ryanoasis/nerd-fonts` y `romkatv/powerlevel10k-media` |
| Bun | `bun.sh/install` |
| Tailscale | `tailscale.com/install.sh` |
| Hermes Agent | `hermes-agent.nousresearch.com/install.sh` |
| herdr | `herdr.dev/install.sh` |

**Manjaro**

| Origen | Paquetes |
|---|---|
| Repositorios oficiales | `base-devel`, `git`, `nodejs-lts`, `pnpm`, `bun`, `rustup`, `tailscale`, `github-cli`, `docker`, `docker-compose`, `docker-buildx`, `yay`, `sqlite` |
| AUR | `brave-nightly-bin`, `google-chrome`, `flutter-bin`, `appflowy-bin`, `whatsdesk-bin`, `claude-desktop`, `claude-code`, `opencode-bin`, `antigravity-ide`, `cursor-bin`, `visual-studio-code-bin` |

Todas las descargas que se ejecutan como script se bajan primero a un archivo temporal
(`run_remote_script`): si la descarga falla, no se ejecuta nada a medias.

---

## 8. Respaldo semanal de AppFlowy a GitHub

`appflowy-data-backup.sh` se instala **igual en ambas distros**: se copia a `~/.local/bin` (copia, no
enlace, para que siga funcionando si borras esta carpeta) y se registra como servicio de usuario de
systemd. Añade `git` y `sqlite3`/`sqlite` a la instalación.

```bash
appflowy-data-backup.sh                 # menú interactivo
appflowy-data-backup.sh --backup        # respaldar ahora (--hot si AppFlowy está abierto)
appflowy-data-backup.sh --restore       # restaurar (--restore <hash> --yes para uno concreto)
appflowy-data-backup.sh --list          # respaldos disponibles
appflowy-data-backup.sh --status        # repo, visibilidad, daemon, último respaldo
appflowy-data-backup.sh --install-daemon / --uninstall-daemon
```

- **Qué guarda:** todo `~/.local/share/io.appflowy.appflowy` (notas, bases de datos, imágenes), con
  las bases SQLite copiadas de forma consistente. Excluye logs, archivos de bloqueo y
  `shared_preferences.json` (puede contener tu sesión). Además **vacía los tokens de sesión**
  (`user_table.token`) en la *copia* de la base de datos —tu original no se toca—, así que tras
  restaurar hay que iniciar sesión de nuevo. Los archivos de más de 90 MB se omiten porque GitHub
  rechaza más de 100 MB.
- **Daemon:** `appflowy-data-backup.service` comprueba cada 30 minutos si pasaron 7 días desde el
  último respaldo; si el equipo estuvo apagado, respalda al volver. Si AppFlowy está abierto, espera
  (hasta 24 h) para copiar con la aplicación cerrada. Los fallos se reintentan con espera creciente.
- **Restaurar:** antes de pisar nada guarda tu estado actual en `~/.local/share/appflowy-data-backup/pre-restore/`
  y exige que AppFlowy esté cerrado. Conserva tu sesión local.
- **Repositorio:** `https://github.com/victorcarrillodev/appflowy-backup.git` (cámbialo en
  `~/.config/appflowy-data-backup/config` con `REPO_URL=...`). Usa tu sesión de `gh`.

> **El repositorio debe ser PRIVADO.** Tus notas se suben tal cual. Antes de cada subida el script
> comprueba la visibilidad y **se niega a subir si es público** (o si no puede comprobarlo; códigos
> de `--check-repo`: `3` público, `4` no verificable, `5` inexistente o sin acceso).
> Hazlo privado con:
> `gh repo edit victorcarrillodev/appflowy-backup --visibility private --accept-visibility-change-consequences`

---

## 9. Mantener este documento actualizado

- **Añadir algo a una sola distro:** regístralo en su carpeta (`ubuntu/` o `manjaro/`).
- **Añadirlo a las dos:** regístralo en el módulo equivalente de **cada** distro con el **mismo id**
  (como hacen `gh`, `playwright-cli`, `herdr` y `appflowy`); si el instalador es idéntico, define sus
  funciones una sola vez en `comun/10-herramientas-comunes.sh`.
- Después actualiza este archivo. Para comprobar qué ids comparten las dos distros:

```bash
diff <(./init.sh --listar --sistema ubuntu  | awk 'NF>=2 && $1 ~ /^[a-z][a-z0-9-]+$/ {print $1}' | sort) \
     <(./init.sh --listar --sistema manjaro | awk 'NF>=2 && $1 ~ /^[a-z][a-z0-9-]+$/ {print $1}' | sort)
```
