#!/bin/bash
# Module: file_read
# Description: Lee el contenido de un archivo remoto, con opción de filtrado por patrón
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: ssh, cat, grep

file_read_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local path="${args[path]}"
  local grep="${args[grep]}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/file_read.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if [[ -z "$path" ]]; then
    echo "${tr[missing_path]:-❌ [file_read] Parámetro 'path' obligatorio}"
    return 1
  fi

  echo "$(render_msg "${tr[start]}" "path=$path" "host=$host")"

  if [[ -n "$grep" ]]; then
    ssh "$host" "$prefix grep -E '$grep' '$path'"
  else
    ssh "$host" "$prefix cat '$path'"
  fi
}

check_dependencies_file_read() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/file_read.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if ! command -v ssh &> /dev/null || ! command -v grep &> /dev/null; then
    echo "${tr[missing_deps]:-❌ [file_read] ssh o grep no están disponibles.}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [file_read] ssh y grep disponibles.}"
  return 0
}
