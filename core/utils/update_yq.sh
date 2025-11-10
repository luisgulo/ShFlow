#!/bin/bash

# Ruta de instalación por defecto
SHFLOW_HOME="${SHFLOW_HOME:-$HOME/shflow}"
UTILS_DIR="$SHFLOW_HOME/core/utils"
mkdir -p "$UTILS_DIR"

# Versión de yq a descargar
YQ_VERSION="v4.48.1"
BASE_URL="https://github.com/mikefarah/yq/releases/download/$YQ_VERSION"

# Lista de binarios a descargar
BINARIES=(
  "yq_linux_386"
  "yq_linux_amd64"
  "yq_linux_arm"
  "yq_linux_arm64"
)

# Descargar cada binario y darle permisos de ejecución
for binary in "${BINARIES[@]}"; do
  url="$BASE_URL/$binary"
  target="$UTILS_DIR/$binary"
  echo "⬇️ Descargando $url..."
  curl -sSL "$url" -o "$target"
  chmod +x "$target"
  echo "✅ Guardado en $target"
done

echo "🎉 Todos los binarios de yq $YQ_VERSION han sido descargados en $UTILS_DIR"
