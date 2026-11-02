# Inicio rápido

Primera instalación de **LINUX CONF** en Ubuntu o Manjaro, de principio a fin.
Duración: depende de la conexión y de cuántos programas falten (Flutter, LibreOffice y los
wallpapers son los más pesados).

---

## 1. Antes de empezar

| Necesitas | Detalle |
|---|---|
| Ubuntu o Manjaro | La configuración de una distro no se aplica sobre la otra (el instalador lo comprueba). |
| Tu usuario normal | **No uses `sudo ./init.sh`**. El script pedirá la contraseña cuando haga falta. |
| `sudo` funcionando | Se usa para instalar paquetes, servicios y archivos de `/etc`. |
| Internet | Solo `--simular` funciona sin conexión. |
| Bash, `curl`, `git` | Ya vienen en ambas distros; el módulo 01 instala el resto de utilidades base. |

## 2. Descargar el instalador

```bash
git clone https://github.com/victorcarrillodev/linux-configuration-helper.git
cd linux-configuration-helper
```

## 3. Ejecutar

```bash
./init.sh
```

## 4. Responder las tres preguntas

**PASO 1 · ¿Para qué sistema es esta configuración?**
`1) Ubuntu (linux conf)` o `2) Manjaro (manjaro conf)`. El instalador detecta el sistema actual y lo
propone con solo pulsar Enter. Si eliges una distro que no corresponde a este equipo, vuelve a
preguntar.

**PASO 2 · ¿Dónde vas a instalar?**
`1) Escritorio` (PC o portátil con disco interno) o `2) USB` (sistema portable, con optimizaciones
para reducir escrituras). Si detecta que el sistema actual está en una USB, propone `2`.

**PASO 3 · ¿Qué editores de código quieres?**
Antigravity IDE, Cursor y/o VS Code. Puedes elegir varios con `1 3`, `1,3`, `13` o `todos`;
siempre al menos uno. Si un editor que **no** elegiste ya está instalado, más adelante te preguntará
si lo conservas o lo desinstala.

## 5. Revisar la auditoría y confirmar

Antes de tocar nada verás una tabla con tres marcas:

| Marca | Significado |
|---|---|
| `✔` | Ya está instalado y **funcionando** (se omitirá). |
| `✘` | Pendiente (se instalará). |
| `○` | Tarea que se ejecuta siempre (actualizar el sistema, limpiar la caché). |

Responde `s` a **«¿Continuar con la instalación?»**. A partir de aquí el instalador pide `sudo`
una vez y lo mantiene activo mientras trabaja.

## 6. Lo que verás mientras instala

- Un título por **sección** (SISTEMA, NAVEGADORES, DESARROLLO, DOCKER, EDITORES, TERMINAL,
  MULTIMEDIA, PRODUCTIVIDAD, LIMPIEZA) y un encabezado por **ítem**, con su número y total.
- El resultado de cada ítem: **✔ instalado y verificado**, **○ omitido** (con el motivo) o
  **✘ falló**, en cuyo caso verás la causa probable y los reintentos.
- Una pausa de 2 s tras cada ítem para que el resultado quede visible (`--sin-pausa` la quita).

## 7. Al terminar

1. **Resumen**: lista final ítem por ítem, ya re-verificada, con el total
   `N instalados ahora · N ya estaban · N omitidos · N con fallos`.
2. **PENDIENTE**: los pasos manuales que te corresponden, calculados según el estado real del
   equipo (no solo lo que se instaló ahora). Suelen incluir:
   ```bash
   gh auth login                 # GitHub CLI
   newgrp docker                 # Docker sin sudo (o cerrar sesión)
   sudo tailscale up             # conectar la VPN
   exec $SHELL                   # cargar las rutas de Node, pnpm, bun…
   ```
3. **¿Borrar el instalador?** Siempre se pregunta y por defecto es **No**. Si la carpeta es un
   repositorio git con cambios o commits sin subir, avisa y pide una segunda confirmación.
4. **Registro completo** de la ejecución en
   `~/.local/state/new-linux-conf/instalacion-AAAAMMDD-HHMMSS.log`.

> El código de salida es `0` solo si no quedó ningún fallo, de modo que puedes usarlo en un script.

## 8. Primeros minutos después de instalar

| Si instalaste… | Haz esto |
|---|---|
| Zsh / Oh My Zsh / Powerlevel10k | Elige la fuente **MesloLGS NF** en tu terminal y ejecuta `p10k configure`. |
| Node, pnpm, Bun, Rust, herdr | Abre una **terminal nueva** (o `exec $SHELL`). |
| Docker | `newgrp docker` o cierra sesión y vuelve a entrar. |
| GitHub CLI | `gh auth login`. |
| Playwright CLI | `playwright-cli install-browser` (en Ubuntu, añade `--with-deps`). |
| Tailscale | `sudo tailscale up` y autoriza la URL. |
| CLIs de IA (Claude Code, Gemini, Codex, OpenCode) | Ejecuta cada una una vez para iniciar sesión. |
| AppFlowy y su respaldo | `appflowy-data-backup.sh` para el menú; comprueba que el repo sea **privado**. |

## 9. Instalación sin preguntas

```bash
# Todo con los valores por defecto (los tres editores), sin borrar el instalador
./init.sh --yes --sistema ubuntu --destino escritorio

# Ver el plan completo sin instalar ni modificar nada
./init.sh --simular --sistema manjaro --destino usb
```

`--yes` acepta las respuestas por defecto: nunca desinstala editores ya instalados y nunca borra el
instalador.

## 10. Problemas típicos

| Síntoma | Qué hacer |
|---|---|
| «No ejecutes este script como root» | Sal de `sudo`: `./init.sh` con tu usuario. |
| «Elegiste Ubuntu, pero este equipo no tiene apt» | Elige la distro que corresponde (o revisa `--sistema`). |
| Un ítem falla y se reintenta | Es normal: el instalador repara el gestor de paquetes y reintenta. Lee la causa probable. |
| Sigue fallando tras la revisión final | Vuelve a ejecutar `./init.sh`: solo repite lo pendiente. El motivo exacto está en el log. |
| «Otro proceso usa el gestor de paquetes» | Cierra tu gestor de software o espera; el script reintenta 2 minutos. |
| Falta conexión | Se espera hasta 30 s al empezar y hasta 90 s durante las reparaciones. |
| Un editor no elegido está instalado | Responde si quieres conservarlo; si no, se desinstala antes de la limpieza. |

Para el detalle de cada opción y de cada tipo de fallo, consulta
[GUIA-DE-USO.md](GUIA-DE-USO.md). Para saber qué se instala en cada distro, consulta
[INSTALACIONES.md](INSTALACIONES.md).
