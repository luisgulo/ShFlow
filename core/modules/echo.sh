#!/bin/bash
# Module: echo
# Description: Muestra un mensaje en consola con soporte para variables ShFlow
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: -

echo_task() {
  local host="$1"; shift
  declare -A args

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      *=*)
        key="${1%%=*}"
        value="${1#*=}"
        args["$key"]="$value"
        ;;
    esac
    shift
  done

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/echo.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  # 🔁 Interpolar usando argumentos explícitos
  for key in "${!args[@]}"; do
    for var in "${!args[@]}"; do
      args["$key"]="${args[$key]//\{\{ $var \}\}/${args[$var]}}"
    done
  done

  local message="${args[message]}"
  echo "$(render_msg "${tr[output]}" "message=$message")"
}

check_dependencies_echo() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/echo.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  echo "${tr[deps_ok]:-✅ [echo] No requiere dependencias.}"
  return 0
}
