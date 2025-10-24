#!/usr/bin/env bash
# Module: wait
# Description: Pausa la ejecución durante un número de segundos (soporta decimales)
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: sleep

wait_task() {
  local host="$1"; shift
  declare -A args; for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local seconds="${args[seconds]:-1}"

  # Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/wait.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r key val; do tr["$key"]="$val"; done < "$trfile"
  fi

  if ! [[ "$seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "${tr[invalid]:-❌ [wait] El parámetro 'seconds' debe ser un número válido (entero o decimal)}"
    return 1
  fi

  echo "$(render_msg "${tr[start]}" "seconds=$seconds")"
  sleep "$seconds"
  echo "${tr[done]:-✅ [wait] Pausa completada}"
}

check_dependencies_wait() {
  command -v sleep &>/dev/null || {
    echo "${tr[missing_deps]:-❌ [wait] El comando 'sleep' no está disponible}"
    return 1
  }
  echo "${tr[deps_ok]:-✅ [wait] Dependencias OK}"
  return 0
}
