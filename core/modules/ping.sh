#!/bin/bash
# Module: ping
# Description: Verifica conectividad desde el host remoto hacia un destino específico
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2
# Dependencies: ping, ssh

ping_task() {
  local host="$1"; shift
  declare -A args; for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local count="${args[count]:-2}"
  local timeout="${args[timeout]:-3}"
  local target="${args[target]:-127.0.0.1}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

   # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/ping.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r key val; do tr["$key"]="$val"; done < "$trfile"
  else
    echo "⚠️ [ping] Archivo de traducción no encontrado: $trfile"
  fi

  echo "$(render_msg "${tr[start]}" "host=$host" "target=$target")"

  if ssh "$host" "$prefix ping -c $count -W $timeout $target &>/dev/null"; then
    echo "    $(render_msg "${tr[success]}" "host=$host" "target=$target")"
    return 0
  else
    echo "    $(render_msg "${tr[fail]}" "host=$host" "target=$target")"
    return 1
  fi
}

check_dependencies_ping() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/ping.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r key val; do tr["$key"]="$val"; done < "$trfile"
  fi

  if ! command -v ssh &> /dev/null || ! command -v ping &> /dev/null; then
    echo "    ${tr[missing_deps]:-❌ [ping] ssh o ping no están disponibles.}"
    return 1
  fi
  echo "    ${tr[deps_ok]:-✅ [ping] ssh y ping disponibles.}"
  return 0
}
