#!/bin/bash
# ShFlow Module Template Generator
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0

set -euo pipefail

# 📁 Rutas defensivas
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MODULE_NAME="${1:-}"
MODULE_DIR="$PROJECT_ROOT/core/modules"
MODULE_FILE="$MODULE_DIR/$MODULE_NAME.sh"

# 🧩 Cargar render_msg si no está disponible
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

# 🌐 Cargar traducciones
lang="${SHFLOW_LANG:-es}"
trfile="$PROJECT_ROOT/core/utils/module-template.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

# 🧪 Validar entrada
if [[ -z "$MODULE_NAME" ]]; then
  echo "${tr[usage]:-❌ Uso: module-template.sh <nombre_modulo>}"
  exit 1
fi

if [[ -f "$MODULE_FILE" ]]; then
  echo "$(render_msg "${tr[exists]}" "name=$MODULE_NAME" "dir=$MODULE_DIR")"
  exit 1
fi

mkdir -p "$MODULE_DIR"

cat > "$MODULE_FILE" <<EOF
#!/bin/bash
# Module: $MODULE_NAME
# Description: <descripción breve del módulo>
# License: GPLv3
# Author: Luis GuLo
# Version: 1.0
# Dependencies: <comandos externos si aplica>

${MODULE_NAME}_task() {
  local host="\$1"; shift
  declare -A args
  for arg in "\$@"; do
    key="\${arg%%=*}"
    value="\${arg#*=}"
    args["\$key"]="\$value"
  done

  echo "🚧 Ejecutando módulo '$MODULE_NAME' en \$host"
  # Aquí va la lógica principal
}

check_dependencies_$MODULE_NAME() {
  # Verifica herramientas necesarias
  for cmd in <comando1> <comando2>; do
    if ! command -v "\$cmd" &> /dev/null; then
      echo "    ❌ [$MODULE_NAME] Falta: \$cmd"
      return 1
    fi
  done
  echo "    ✅ [$MODULE_NAME] Dependencias OK"
  return 0
}
EOF

chmod +x "$MODULE_FILE"
echo "$(render_msg "${tr[created]}" "name=$MODULE_NAME" "path=$MODULE_FILE")"
