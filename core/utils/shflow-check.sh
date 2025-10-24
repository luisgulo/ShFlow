#!/usr/bin/env bash
# ShFlow Environment Checker
# License: GPLv3
# Author: Luis GuLo
# Version: 1.5.0

set -e

PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

MODULE_PATHS=(
  "$PROJECT_ROOT/core/modules"
  "$PROJECT_ROOT/user_modules"
  "$PROJECT_ROOT/community_modules"
)

# 🧩 Cargar funciones comunes si no están disponibles
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

GLOBAL_TOOLS=("bash" "ssh" "scp" "git" "curl" "jq" "yq" "gpg")

REQUIRED_PATHS=(
  "$PROJECT_ROOT/core/modules"
  "$PROJECT_ROOT/core/utils"
  "$PROJECT_ROOT/core/inventory"
  "$PROJECT_ROOT/examples"
  "$PROJECT_ROOT/user_modules"
  "$PROJECT_ROOT/community_modules"
  "$PROJECT_ROOT/shflow.sh"
  "$PROJECT_ROOT/vault.sh"
)

# 🌐 Cargar traducciones
lang="${shflow_vars[language]:-es}"
trfile="$PROJECT_ROOT/core/utils/shflow-check.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

check_global_tools() {
  echo "${tr[tools_header]:-🔍 Verificando herramientas globales...}"
  local missing=0
  for tool in "${GLOBAL_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      echo "$(render_msg "${tr[tool_missing]}" "tool=$tool")"
      missing=1
    else
      echo "$(render_msg "${tr[tool_ok]}" "tool=$tool")"
    fi
  done
  return $missing
}

check_structure() {
  echo ""
  echo "${tr[structure_header]:-📁 Verificando estructura de ShFlow...}"
  local missing=0
  for path in "${REQUIRED_PATHS[@]}"; do
    if [ ! -e "$path" ]; then
      echo "$(render_msg "${tr[path_missing]}" "path=$path")"
      missing=1
    else
      echo "$(render_msg "${tr[path_ok]}" "path=$path")"
    fi
  done
  return $missing
}

load_and_check_modules() {
  echo ""
  echo "${tr[modules_header]:-🔍 Verificando módulos ShFlow...}"
  for dir in "${MODULE_PATHS[@]}"; do
    [ -d "$dir" ] || continue
    while IFS= read -r -d '' mod; do
      source "$mod"
    done < <(find "$dir" -type f -name "*.sh" -print0)
  done

  for func in $(declare -F | awk '{print $3}' | grep '^check_dependencies_'); do
    echo ""
    echo "$(render_msg "${tr[checking_func]}" "func=$func")"
    $func || echo "$(render_msg "${tr[func_warn]}" "func=$func")"
  done
}

main() {
  echo "${tr[title]:-🧪 ShFlow Environment Check}"
  echo "${tr[separator]:-=============================}"

  check_global_tools
  check_structure
  load_and_check_modules

  echo ""
  echo "${tr[done]:-✅ Verificación completada.}"
}

main "$@"
