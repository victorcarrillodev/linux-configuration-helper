# Qué se instala en cada sistema

Este documento separa lo que `./init.sh` instala **solo en Ubuntu**, **solo en Manjaro** y **en las dos distros**.
La lista exacta y siempre actualizada sale de:

```bash
./init.sh --listar --sistema ubuntu
./init.sh --listar --sistema manjaro
```

Convención: **Ubuntu** = `linux conf` (apt, snap, repositorios externos) · **Manjaro** = `manjaro conf` (pacman + AUR con yay).

---

## 1. En las dos distros (Ubuntu y Manjaro)

El programa es el mismo; cambia **cómo** se instala en cada sistema.

| Programa | Ubuntu (linux conf) | Manjaro (manjaro conf) |
|---|---|---|
| Actualización del sistema | `apt update` + `apt upgrade` | `pacman -Syu` |
| Herramientas base y git | curl, wget, git, gnupg, build-essential, htop, net-tools, unzip, zip, xz-utils… | base-devel + git |
| Eliminar Firefox | deb y snap, con su perfil | `pacman -Rns firefox` |
| Brave Nightly | repositorio apt oficial de Brave | AUR `brave-nightly-bin` |
| Google Chrome | **canal Dev** (`.deb` oficial) | **canal estable** (AUR `google-chrome`) |
| Node.js | NVM + Node 24 | `nodejs` + `npm` (pacman) |
| pnpm | `npm -g` | pacman |
| Bun | instalador oficial | pacman |
| Flutter | snap + dependencias de escritorio Linux | AUR `flutter-bin` |
| Claude Code (CLI) | `npm -g @anthropic-ai/claude-code` | AUR `claude-code` |
| OpenCode | `npm -g opencode-ai` | AUR `opencode-bin` |
| Tailscale | instalador oficial | pacman |
| Docker + Compose + Buildx | repositorio oficial de Docker (`docker-ce`) | pacman |
| Antigravity | repositorio apt oficial | AUR `antigravity-ide` |
| **GitHub CLI (`gh`)** | repositorio apt oficial de GitHub | pacman `github-cli` |
| **Playwright CLI (`playwright-cli`)** | `npm -g @playwright/cli` | `npm -g @playwright/cli` (prefijo `~/.npm-global`, sin sudo) |
| **herdr** (multiplexor para agentes de IA) | instalador oficial → `~/.local/bin` | instalador oficial → `~/.local/bin` |
| **AppFlowy** | `.deb` oficial de GitHub (última versión) | AUR `appflowy-bin` |
| **Respaldo semanal de AppFlowy** (`appflowy-data-backup.sh` + daemon) | script copiado a `~/.local/bin`, servicio de usuario de systemd y `sqlite3` | igual (con `sqlite`) |
| Limpieza final | `autoremove` + `autoclean` + `clean` | caché de pacman/yay + paquetes huérfanos |
| Modo **Escritorio / USB** | idéntico en ambas: USB aplica sysctl, logs en RAM, BFQ, zram, `noatime`, `/tmp` en RAM y profile-sync-daemon; Escritorio revierte lo anterior | |

---

## 2. Solo en Ubuntu (linux conf)

| Programa / configuración | Detalle |
|---|---|
| PostgreSQL | `postgresql` + `postgresql-contrib`, servicio habilitado |
| Gemini CLI | `npm -g @google/gemini-cli` |
| Codex CLI | `npm -g @openai/codex` |
| Hermes Agent (Nous Research) | instalador oficial (sin asistente interactivo; queda como paso manual) |
| Visual Studio Code | repositorio apt de Microsoft |
| Variety + wallpapers | Variety y el repositorio de fondos clonado en `~/wallpapers` (~260 MB, por eso tarda) |
| Terminal | Zsh, Oh My Zsh, Powerlevel10k, autosuggestions y syntax-highlighting, fuentes CascadiaCode NF y MesloLGS NF, Wave Terminal, `~/.zshrc` con banner, Zsh como shell por defecto |
| LibreOffice | PPA oficial, en español |
| Códecs multimedia | ffmpeg, GStreamer, `ubuntu-restricted-extras` |
| VLC y MPV | reproductores |
| Rutas (PATH) en bash | `~/.local/bin`, `~/.cargo/bin`, `~/.bun/bin`, pnpm en `~/.profile` y `~/.bashrc` |

---

## 3. Solo en Manjaro (manjaro conf)

| Programa / configuración | Detalle |
|---|---|
| yay | ayudante de AUR (se instala antes que cualquier paquete de AUR) |
| Rust | `rustup` con toolchain `stable` |
| Cursor IDE | AUR `cursor-bin` |
| Claude Desktop | AUR `claude-desktop` |
| WhatsDesk (WhatsApp) | AUR `whatsdesk-bin` |
| Rutas globales de npm / pnpm / bun | `npm` con prefijo `~/.npm-global` para instalar paquetes globales **sin sudo**, más las rutas en `~/.zshrc` y `~/.bashrc` |

---

## Cómo mover algo de una sección a otra

- **Añadir algo a una sola distro:** regístralo en su carpeta (`ubuntu/` o `manjaro/`).
- **Añadirlo a las dos:** regístralo en el módulo equivalente de **cada** distro con el **mismo id**
  (como hacen `gh`, `playwright-cli`, `herdr` y `appflowy`); si el instalador es idéntico, define sus
  funciones una sola vez en `comun/10-herramientas-comunes.sh`.
- Después actualiza este archivo. Para comprobar qué ids comparten las dos distros:

```bash
diff <(./init.sh --listar --sistema ubuntu  | awk 'NF>=2 && $1 ~ /^[a-z][a-z0-9-]+$/ {print $1}' | sort) \
     <(./init.sh --listar --sistema manjaro | awk 'NF>=2 && $1 ~ /^[a-z][a-z0-9-]+$/ {print $1}' | sort)
```

---

## Respaldo semanal de AppFlowy a GitHub (`appflowy-data-backup.sh`)

Se instala igual en las dos distros y se ejecuta con ese nombre desde cualquier terminal
(queda en `~/.local/bin`). Tiene un **menú**: hacer una copia de seguridad ahora, restaurar tu información,
ver los respaldos, y activar o desactivar el respaldo semanal automático.

```bash
appflowy-data-backup.sh                 # menú interactivo
appflowy-data-backup.sh --backup        # respaldo ahora (--hot si AppFlowy está abierto y aceptas una copia «en caliente»)
appflowy-data-backup.sh --restore       # restaurar (elige cuál; --restore <hash> --yes para uno concreto)
appflowy-data-backup.sh --status        # repo, visibilidad, daemon, último respaldo
appflowy-data-backup.sh --install-daemon / --uninstall-daemon
```

- **Qué guarda:** todo `~/.local/share/io.appflowy.appflowy` (notas, bases de datos, imágenes), con las bases SQLite
  copiadas de forma consistente. Excluye logs, archivos de bloqueo y `shared_preferences.json` (puede contener tu sesión).
  Además **vacía los tokens de sesión** (`user_table.token`) en la *copia* de la base de datos —tu original no se toca—,
  así que tras restaurar hay que iniciar sesión en AppFlowy de nuevo. Los archivos de más de 90 MB se omiten
  porque GitHub rechaza más de 100 MB.
- **Daemon:** un servicio de usuario de systemd (`appflowy-data-backup.service`) comprueba cada 30 minutos si pasaron
  7 días desde el último respaldo; si el equipo estuvo apagado, respalda al volver. Si AppFlowy está abierto espera
  (hasta 24 h) para copiar con la aplicación cerrada. Los fallos se reintentan con espera creciente.
- **Restaurar:** antes de pisar nada guarda tu estado actual en `~/.local/share/appflowy-data-backup/pre-restore/`
  y exige que AppFlowy esté cerrado. Conserva tu sesión local.
- **Repositorio:** `https://github.com/victorcarrillodev/appflowy-backup.git` (cámbialo en
  `~/.config/appflowy-data-backup/config` con `REPO_URL=...`). Usa tu sesión de `gh` (`gh auth login`).

> **El repositorio debe ser PRIVADO.** Tus notas se suben tal cual. Antes de cada subida el script comprueba la
> visibilidad y **se niega a subir si es público** (o si no puede comprobarlo).
> Hazlo privado con `gh repo edit victorcarrillodev/appflowy-backup --visibility private --accept-visibility-change-consequences`.

