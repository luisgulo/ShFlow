#!/usr/bin/env bash
# ShFlow Doc Generator
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0

set -e

# ─────────────────────────────────────────────
# 🧭 Detección de la raíz del proyecto
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 🧩 Cargar funciones comunes si no están disponibles
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

# 🌐 Cargar traducciones
lang="${shflow_vars[language]:-es}"
trfile="$PROJECT_ROOT/core/utils/shflow-doc.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

MODULE_PATHS=(
  "$PROJECT_ROOT/core/modules"
  "$PROJECT_ROOT/user_modules"
  "$PROJECT_ROOT/community_modules"
)

extract_metadata() {
  local file="$1"
  local module desc author version deps

  module=$(grep -m1 '^# Module:' "$file" | cut -d':' -f2- | xargs)
  desc=$(grep -m1 '^# Description:' "$file" | cut -d':' -f2- | xargs)
  author=$(grep -m1 '^# Author:' "$file" | cut -d':' -f2- | xargs)
  version=$(grep -m1 '^# Version:' "$file" | cut -d':' -f2- | xargs)
  deps=$(grep -m1 '^# Dependencies:' "$file" | cut -d':' -f2- | xargs)

  echo "$(render_msg "${tr[module]}" "name=$module")"
  echo "$(render_msg "${tr[desc]}" "desc=$desc")"
  echo "$(render_msg "${tr[author]}" "author=$author")"
  echo "$(render_msg "${tr[version]}" "version=$version")"
  echo "$(render_msg "${tr[deps]}" "deps=$deps")"
  echo "${tr[separator]:-  ————————————————————————}"
}

main() {
  echo "${tr[title]:-📚 ShFlow Modules Documentation}"
  echo "${tr[separator_line]:-=================================}"

  for dir in "${MODULE_PATHS[@]}"; do
    [ -d "$dir" ] || continue
    ROUTE=$(echo "$dir" | sed "s#$PROJECT_ROOT/##g")
    echo -e "\n$(render_msg "${tr[section]}" "type=$ROUTE")"
    while IFS= read -r -d '' file; do
      extract_metadata "$file"
    done < <(find "$dir" -type f -name "*.sh" -print0)
  done
}

main "$@"
