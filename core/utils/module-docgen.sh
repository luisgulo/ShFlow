#!/bin/bash
# ShFlow Module Documentation Generator
# License: GPLv3
# Author: Luis GuLo
# Version: 1.4.0

set -euo pipefail

# 🧭 Detección de la raíz del proyecto
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUTPUT="$PROJECT_ROOT/docs/modules-list.md"
MODULE_DIRS=("$PROJECT_ROOT/core/modules" "$PROJECT_ROOT/user_modules" "$PROJECT_ROOT/community_modules")

export SHFLOW_LANG="${SHFLOW_LANG:-es}"

# 🧩 Cargar render_msg si no está disponible
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

# 🌐 Cargar traducciones
lang="${SHFLOW_LANG:-es}"

trfile="$PROJECT_ROOT/core/utils/module-docgen.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

# 📝 Encabezado del documento
{
  echo "${tr[title]:-# 🧩 Módulos en ShFlow}"
  echo ""
  echo "**$(render_msg "${tr[generated]}" "date=$(date '+%Y-%m-%d %H:%M:%S')")**"
  echo ""
  echo "| ${tr[col_module]:-Módulo} | ${tr[col_desc]:-Descripción} | ${tr[col_type]:-Tipo} | ${tr[col_author]:-Autor} | ${tr[col_version]:-Versión} | ${tr[col_deps]:-Dependencias} |"
  echo "|--------|-------------|------|-------|---------|--------------|"
} > "$OUTPUT"

# 🔁 Procesar módulos
for dir in "${MODULE_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  TYPE=$(echo "$dir" | sed "s#$PROJECT_ROOT/##g")
  while IFS= read -r -d '' file; do
    name=$(basename "$file" .sh)
    desc=$(grep -E '^# Description:' "$file" | sed 's/^# Description:[[:space:]]*//')
    author=$(grep -E '^# Author:' "$file" | sed 's/^# Author:[[:space:]]*//')
    version=$(grep -E '^# Version:' "$file" | sed 's/^# Version:[[:space:]]*//')
    deps=$(grep -E '^# Dependencies:' "$file" | sed 's/^# Dependencies:[[:space:]]*//')

    # Asegurar valor minimo
    name=${name:-""}
    desc=${desc:-""}
    author=${author:-""}
    version=${version:-""}
    deps=${deps:-""}

    [[ -z "$name" ]] && continue

    echo "| $name | $desc | $TYPE | $author | $version | $deps |" >> "$OUTPUT"
  done < <(find "$dir" -type f -name "*.sh" -print0)
done

# 📌 Pie de página
{
  echo ""
  echo "${tr[footer]:-_Para actualizar esta tabla, ejecuta: \`module-docgen\`_}"
} >> "$OUTPUT"

echo "$(render_msg "${tr[done]}" "path=$OUTPUT")"
