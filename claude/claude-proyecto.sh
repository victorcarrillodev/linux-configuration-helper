#!/usr/bin/env bash
# claude-proyecto — Prepara un proyecto para trabajar con Claude Code gastando menos tokens.
#   · Crea CLAUDE.md (plantilla) si no existe.
#   · Crea el proyecto de Serena (.serena/project.yml) y construye su índice de símbolos.
#
# Uso:  claude-proyecto [carpeta]     (por defecto, la carpeta actual)
#       claude-proyecto --reindexar   vuelve a construir el índice de Serena
#
# Lo instala linux-conf (ítem «claude-ahorro») en ~/.local/bin.
set -euo pipefail

reindex=0
dir="$PWD"
for a in "$@"; do
    case "$a" in
        --reindexar) reindex=1 ;;
        -h|--help|--ayuda) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) dir="$a" ;;
    esac
done
cd "$dir"
dir="$PWD"

if [ "$dir" = "$HOME" ] || [ "$dir" = "/" ]; then
    echo "✘ Ejecútalo dentro de la carpeta de un proyecto, no en ${dir}." >&2
    exit 1
fi

echo "▸ Proyecto: ${dir}"

# 1) CLAUDE.md: el «índice» que Claude lee gratis al empezar cada sesión
if [ ! -f CLAUDE.md ]; then
    cat > CLAUDE.md <<'EOF'
# CLAUDE.md

<!-- Mantén este archivo corto (50–150 líneas). Claude lo lee al inicio de cada sesión.
     Puedes pedirle a Claude que lo complete: abre «claude» aquí y ejecuta /init -->

## Qué es este proyecto
(una o dos frases)

## Mapa de carpetas
- `src/` —
- `tests/` —

## Comandos
- Instalar:
- Desarrollo:
- Tests (rápidos/silenciosos):
- Lint/formato:

## Convenciones
-

## No tocar / no leer
- (archivos generados, datos grandes, secretos…)
EOF
    echo "✔ CLAUDE.md creado (plantilla). Complétalo o ejecuta /init dentro de Claude Code."
else
    echo "✔ CLAUDE.md ya existe."
fi

# 2) Índice de Serena
if ! command -v serena >/dev/null 2>&1; then
    echo "○ Serena no está instalado: se omite el índice (instálalo con ./init.sh --solo serena)."
    exit 0
fi
if [ ! -f .serena/project.yml ]; then
    echo "▸ Creando el proyecto de Serena e indexando (la primera vez descarga el servidor de lenguaje)…"
    serena project create --index "$dir"
elif [ "$reindex" = 1 ]; then
    echo "▸ Reindexando con Serena…"
    serena project index
else
    echo "✔ Serena ya conoce este proyecto (.serena/project.yml). Su índice se actualiza solo;"
    echo "  usa «claude-proyecto --reindexar» si quieres reconstruirlo."
fi
echo "✔ Listo. Abre «claude» en esta carpeta: Serena se activa sola para este proyecto."
