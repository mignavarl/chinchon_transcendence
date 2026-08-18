#!/bin/bash
set -e

echo "Exportando proyecto Godot con preset: ${GODOT_EXPORT_PRESET}"
echo "Directorio de build: $(pwd)"

godot4 --headless --path /godotbuildspace --export-release "${GODOT_EXPORT_PRESET}" /godotapp/index.html

if [ ! -f /godotapp/index.html ]; then
    echo "ERROR: la exportación no generó index.html" >&2
    exit 1
fi

echo "Exportación completada correctamente."
sleep infinity