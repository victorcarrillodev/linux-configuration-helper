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
8. [Mantener este documento actualizado](#8-mantener-este-documento-actualizado)

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
| Node.js LTS | `nvm-node` / `nodejs` | NVM + **Node LTS** vigente; desinstala cualquier otra versión de nvm | `nodejs-lts npm`; si existe `nodejs` (no LTS) lo retira | `node`, `npm` y que la versión activa sea la LTS actual | — |
| pnpm | `pnpm` | `npm -g pnpm` | pacman `pnpm` | `pnpm --version` | Node |
| Bun | `bun` | instalador oficial (`bun.sh/install`) | pacman `bun` | `bun --version` | utilidades base (solo Ubuntu) |
| Flutter | `flutter` | snap `flutter --classic` + `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev` | AUR `flutter-bin` | comando `flutter` y snap registrado (Ubuntu) | — |
| Tailscale | `tailscale` | instalador oficial + `systemctl enable tailscaled` | pacman `tailscale` + servicio | `tailscale version` y servicio habilitado | utilidades base (solo Ubuntu) |
| GitHub CLI | `gh` | repositorio apt oficial de GitHub | `github-cli` (repo) | `gh --version` | utilidades base (solo Ubuntu) |
| Playwright CLI | `playwright-cli` | `npm -g @playwright/cli@latest` | igual, con prefijo `~/.npm-global` (sin sudo) | `playwright-cli --version` | Node (`nvm-node` / `entorno-js`) |
| herdr CLI (terminal) | `herdr` | instalador oficial (`herdr.dev/install.sh`, comprueba SHA-256) → `~/.local/bin/herdr` | igual | `herdr --version` | utilidades base (solo Ubuntu) |
| herdr App (escritorio) | `herdr-app` | instalador oficial (`releases.herdr.dev/app/install.sh`) → `~/.local/share/herdr-app`, enlace `~/.local/bin/herdr-app`, entrada en el menú e icono; instala `herdr-core` (`hc`) si no existe | igual | ejecutable `herdr-app` y archivo `.desktop` presentes | utilidades base (solo Ubuntu) |
| Neovim | `neovim` | binario oficial de GitHub en `/opt/nvim-linux-<arq>` + enlace en `/usr/local/bin/nvim`; `ripgrep fd-find`; retira el `neovim` antiguo de apt (módulo 06) | pacman `neovim ripgrep fd` (módulo 03) | `nvim --version` ≥ 0.10 (Ubuntu) / `nvim --version` | utilidades base (solo Ubuntu) |
| Neovim como editor de código (LazyVim) | `nvim-config` | copia `nvim/` (starter de LazyVim + extras neo-tree, TypeScript, Tailwind, JSON, ESLint, Prettier y `lua/plugins/aspecto.lua`) a `~/.config/nvim`; si había otra configuración mueve `~/.config/nvim` y los datos/estado/caché de Neovim a `*.bak-<fecha>`; `npm -g tree-sitter-cli`; descarga el diccionario de español `es.utf-8.spl/.sug` a `~/.local/share/nvim/site/spell` (corrector `es,en`); falla si no hay `npm` (Mason lo necesita para los LSP de JS/TS); descarga los plugins con `nvim --headless "+Lazy! sync"` (módulo 06) | igual + pacman `tree-sitter-cli ttf-jetbrains-mono-nerd` (módulo 03) | archivos idénticos a `nvim/` y LazyVim, snacks.nvim y neo-tree.nvim descargados, diccionario de español y `npm` disponible | `neovim` + `nvm-node` + `fuente-cascadia` (Ubuntu) / `neovim` + `nodejs` (Manjaro) |
| lazygit | `lazygit` | binario de la última release de GitHub → `/usr/local/bin` (módulo 06) | pacman `lazygit` (módulo 03) | `lazygit --version` | utilidades base (solo Ubuntu) |
| Yazi | `yazi` | binarios estáticos (musl) `yazi` y `ya` de GitHub → `/usr/local/bin` + `fd-find ripgrep fzf zoxide jq poppler-utils` (módulo 06) | pacman `yazi fd ripgrep fzf zoxide jq poppler` (módulo 03) | `yazi --version` | utilidades base (solo Ubuntu) |
| Claude Desktop (app de escritorio) | `claude-desktop` | **oficial** (beta, Ubuntu 22.04+, amd64/arm64): repositorio apt de Anthropic; la clave se acepta solo si su huella es `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE` | AUR `claude-desktop` (reempaquetado del `.deb` oficial: Anthropic no publica para Arch) | paquete `claude-desktop` y comando `claude-desktop` (Ubuntu) / comando | utilidades base / `yay` |
| Claude Code CLI (terminal) | `claude-code` | `npm -g @anthropic-ai/claude-code` | AUR `claude-code` | comando `claude` | `nvm-node` / `yay` |
| Status line de Claude Code | `claude-statusline` | copia `claude/statusline.py` a `~/.claude/statusline.py` y añade el bloque `statusLine` a `~/.claude/settings.json` con `claude/instalar-statusline.py` (conserva el resto de ajustes, hace copia `settings.json.bak-<fecha>` y no escribe nada si el JSON está roto); instala `python3` si falta (módulo 03) | igual, con `python` (módulo 06) | script idéntico al del repo, `statusLine.command` apuntándole y prueba con datos de ejemplo | — |
| uv (gestor de Python) | `uv` | instalador oficial `astral.sh/uv/install.sh` → `~/.local/bin` (sin tocar los rc; módulo 03) | pacman `uv` (módulo 06) | `uv --version` | utilidades base (solo Ubuntu) |
| Claude Code: ahorro de tokens | `claude-ahorro` | `claude/configurar-claude.py --ahorro`: añade reglas `permissions.deny` (node_modules, dist, lockfiles, minificados…) a `~/.claude/settings.json` (con copia `.bak-<fecha>`), un bloque con marcadores en `~/.claude/CLAUDE.md` e instala `claude/claude-proyecto.sh` como `~/.local/bin/claude-proyecto` | igual | reglas y bloque presentes, `claude-proyecto` idéntico al del repo | `claude-code` |
| Serena (índice de código, MCP) | `serena` | `uv tool install --force -p 3.13 serena-agent`; `claude mcp add --scope user serena -- <ruta>/serena start-mcp-server --context claude-code --project-from-cwd --open-web-dashboard False`; hooks `serena-hooks remind/activate/cleanup` y `env.MCP_TIMEOUT=60000` en `~/.claude/settings.json` | igual | `serena --help`, `serena-hooks` en el PATH, MCP registrado en `~/.claude.json` con ejecutable válido y hooks presentes | `uv` · `claude-code` |
| Docker + Compose + Buildx | `docker` | repositorio oficial `docker-ce` + servicio | pacman `docker docker-compose docker-buildx` + servicio | `docker --version`, `docker compose version` y servicio habilitado | utilidades base (solo Ubuntu) |
| Docker sin sudo | `docker-sin-sudo` | pasos post-instalación oficiales: grupo `docker` (lo crea si falta) + `usermod -aG docker`, `~/.docker` a tu nombre, `docker` y `containerd` al arranque | igual | grupo existe y te incluye, `~/.docker` es tuyo y servicio habilitado | `docker` |
| Espanso (expansor de texto) | `espanso` | `.deb` oficial de GitHub `espanso-debian-<wayland\|x11>-amd64` según la sesión; `setcap` en Wayland; `espanso service register` + `start` (módulo 08) | AUR `espanso-wayland` o `espanso-x11` según la sesión (se compila) + mismos pasos (módulo 07) | `espanso --version` y servicio de usuario registrado | utilidades base / `yay` |
| Antigravity IDE | `antigravity` | repositorio apt de Google | AUR `antigravity-ide` | comando `antigravity` | utilidades base / `yay` |
| Cursor | `cursor` | `.deb` oficial (solo amd64) | AUR `cursor-bin` | comando `cursor` | utilidades base / `yay` |
| VS Code | `vscode` | repositorio apt de Microsoft | AUR `visual-studio-code-bin` (el original de Microsoft) | comando `code` y paquete (Ubuntu) | utilidades base / `yay` |
| Limpieza final | `limpieza` | `autoremove` + `autoclean` + `clean` | caché de pacman/yay + huérfanos (`pacman -Qtdq`) | **Tarea**: se ejecuta siempre | — |

> **Claude** también son dos ítems independientes: marca `Claude Desktop`, `Claude Code CLI` o ambos.
> Para usar **Cowork** en la app de escritorio, tu usuario debe estar en el grupo `kvm` (el resumen
> final te lo indica si falta).
>
> **herdr** son dos ítems independientes: en la lista del PASO 3 marca `herdr CLI`, `herdr App` o
> ambos (`--solo herdr` / `--solo herdr-app` / `--omitir …` también funcionan).
>
> Los editores e IDEs se eligen en la misma lista del PASO 3 (uno, varios o ninguno). Si un editor que no elegiste está
> instalado, el instalador pregunta si conservarlo o desinstalarlo; en ese caso añade un ítem
> `purga-<editor>` justo antes de la limpieza. Ver [GUIA-DE-USO.md](GUIA-DE-USO.md#6-editores-de-código).

---

## 3. Solo en Ubuntu (linux conf)

| Programa / configuración | id | Cómo se instala | Verificación | Depende de |
|---|---|---|---|---|
| Gemini CLI | `gemini-cli` | `npm -g @google/gemini-cli` | `gemini --version` | `nvm-node` |
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
- `bun`, `hermes`, `tailscale`, `gh`, `herdr`, `herdr-app`, `neovim`, `lazygit`, `yazi`, `wave` y `docker` usan el instalador o
  repositorio oficial, no el repositorio de Ubuntu.

---

## 4. Acciones sobre el sistema

Todo lo que el instalador modifica fuera de «instalar paquetes». En la columna **Cómo se revierte**
se indica lo que el propio instalador deshace (si algo) y lo que queda a tu cargo.

| Recurso | Ubuntu | Manjaro | Cómo se revierte |
|---|---|---|---|
| Repositorios apt externos | `/etc/apt/sources.list.d/`: `brave-browser-nightly`, `docker.sources`, `vscode.list`, `antigravity.list`, `github-cli.list`; PPA de LibreOffice; `multiverse` | — | Borrar el archivo del repo y la clave de `/etc/apt/keyrings`. |
| Claves de repositorios | `/etc/apt/keyrings/`: Brave, `docker.asc`, `packages.microsoft.gpg`, `antigravity-repo-key.gpg`, `githubcli-archive-keyring.gpg` | Llavero de pacman (`pacman-key`) | Al desinstalar el paquete correspondiente. |
| Grupo `docker` (ítem `docker-sin-sudo`) | `groupadd docker` si falta + `usermod -aG docker $USER`; `chown` de `~/.docker` | igual | `sudo gpasswd -d $USER docker`. |
| Status line de Claude Code | `~/.claude/statusline.py` y bloque `statusLine` en `~/.claude/settings.json` | igual | Restaurar `settings.json.bak-<fecha>` o borrar el bloque `statusLine`. |
| Espanso | servicio de usuario `~/.config/systemd/user/espanso.service`; en Wayland, capacidad `cap_dac_override` en el binario | igual | `espanso service unregister` y desinstalar el paquete. |
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
| OpenCode | `opencode` | AUR `opencode-bin` | comando `opencode` | `yay` |
| WhatsDesk (WhatsApp) | `whatsdesk` | AUR `whatsdesk-bin` | comando `whatsdesk` | `yay` |
| Rutas globales de JS | `entorno-js` | `npm config set prefix ~/.npm-global` y líneas de PATH en `~/.zshrc` y `~/.bashrc` | prefijo de npm y líneas presentes | `nodejs` |

**Notas de Manjaro**

- **Todos** los paquetes de AUR (`brave`, `chrome`, `flutter`, `whatsdesk`, `espanso`, los tres
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
utilidades-base ──> bun · hermes · tailscale · gh · herdr · herdr-app · claude-desktop · docker · wave · uv
                   · espanso
docker ───────────> docker-sin-sudo
                   · neovim · lazygit · yazi
                   · libreoffice · codecs · vscode · antigravity · cursor
nvm-node ─────────> pnpm · gemini-cli · claude-code · codex · opencode · playwright-cli · nvim-config
neovim ───────────> nvim-config
fuente-cascadia ──> nvim-config
claude-code ──────> claude-ahorro · serena
uv ───────────────> serena
zsh-paquetes ─────> oh-my-zsh · fuente-cascadia · fuente-meslo · shell-zsh
oh-my-zsh ────────> p10k
p10k ─────────────> zshrc
```

**Manjaro**

```
base-devel ──> yay
yay ─────────> brave · chrome · flutter · whatsdesk · espanso · claude-desktop · claude-code
               · opencode · antigravity · cursor · vscode
nodejs ──────> entorno-js · nvim-config
neovim ──────> nvim-config
docker ──────> docker-sin-sudo
entorno-js ──> playwright-cli
claude-code ─> claude-ahorro · serena
uv ──────────> serena
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
| Wallpapers | `github.com/victorcarrillodev/wallpapers` |
| NVM | `raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh` |
| Oh My Zsh | instalador oficial de `ohmyzsh/ohmyzsh` |
| Fuentes Nerd | releases de `ryanoasis/nerd-fonts` y `romkatv/powerlevel10k-media` |
| Bun | `bun.sh/install` |
| Tailscale | `tailscale.com/install.sh` |
| Hermes Agent | `hermes-agent.nousresearch.com/install.sh` |
| herdr CLI | `herdr.dev/install.sh` |
| Espanso | última release de `espanso/espanso` (`espanso-debian-<wayland|x11>-amd64.deb`) |
| Claude Desktop | `downloads.claude.ai/claude-desktop/apt/stable` (clave `downloads.claude.ai/claude-desktop/key.asc`, huella verificada) |
| herdr App | `releases.herdr.dev/app/install.sh` |
| Neovim | `github.com/neovim/neovim/releases/latest` (`nvim-linux-x86_64` / `arm64`) |
| lazygit | última release de `jesseduffield/lazygit` (API de GitHub) |
| Yazi | `github.com/sxyazi/yazi/releases/latest` (`yazi-<arq>-unknown-linux-musl.zip`) |
| uv | `astral.sh/uv/install.sh` |

**Manjaro**

| Origen | Paquetes |
|---|---|
| Repositorios oficiales | `base-devel`, `git`, `nodejs-lts`, `pnpm`, `bun`, `rustup`, `tailscale`, `github-cli`, `docker`, `docker-compose`, `docker-buildx`, `yay`, `sqlite`, `uv` |
| AUR | `brave-nightly-bin`, `google-chrome`, `flutter-bin`, `whatsdesk-bin`, `espanso-wayland` / `espanso-x11`, `claude-desktop`, `claude-code`, `opencode-bin`, `antigravity-ide`, `cursor-bin`, `visual-studio-code-bin` |

Todas las descargas que se ejecutan como script se bajan primero a un archivo temporal
(`run_remote_script`): si la descarga falla, no se ejecuta nada a medias.

---

## 8. Mantener este documento actualizado

- **Añadir algo a una sola distro:** regístralo en su carpeta (`ubuntu/` o `manjaro/`).
- **Añadirlo a las dos:** regístralo en el módulo equivalente de **cada** distro con el **mismo id**
  (como hacen `gh`, `playwright-cli`, `herdr` y `herdr-app`); si el instalador es idéntico, define sus
  funciones una sola vez en `comun/10-herramientas-comunes.sh`.
- **Descripción en la lista del PASO 3:** tras registrarlo, añade `describe <id> "qué es y para qué
  sirve"`; se muestra abajo en la lista al pasar el cursor y en `./init.sh --listar`. Si es común a
  las dos distros, ponla en `comun/10-herramientas-comunes.sh` (como `describe_terminal_tools`).
- Después actualiza este archivo. Para comprobar qué ids comparten las dos distros:

```bash
diff <(./init.sh --listar --sistema ubuntu  | awk 'NF>=2 && $1 ~ /^[a-z][a-z0-9-]+$/ {print $1}' | sort) \
     <(./init.sh --listar --sistema manjaro | awk 'NF>=2 && $1 ~ /^[a-z][a-z0-9-]+$/ {print $1}' | sort)
```
