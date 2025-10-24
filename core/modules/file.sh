#!/bin/bash
# Module: file
# Description: Gestiona archivos y directorios remotos (crear, eliminar, permisos)
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: ssh

file_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local path="${args[path]}"
  local state="${args[state]}"
  local type="${args[type]}"
  local mode="${args[mode]}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/file.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  case "$state" in
    present)
      if [[ "$type" == "directory" ]]; then
        echo "$(render_msg "${tr[creating_dir]}" "path=$path")"
        ssh "$host" "[ -d '$path' ] || $prefix mkdir -p '$path'"
      elif [[ "$type" == "file" ]]; then
        echo "$(render_msg "${tr[creating_file]}" "path=$path")"
        ssh "$host" "[ -f '$path' ] || $prefix touch '$path'"
      fi
      if [[ -n "$mode" ]]; then
        echo "$(render_msg "${tr[setting_mode]}" "mode=$mode" "path=$path")"
        ssh "$host" "$prefix chmod $mode '$path'"
      fi
      ;;
    absent)
      if [[ "$type" == "directory" ]]; then
        echo "$(render_msg "${tr[removing_dir]}" "path=$path")"
        ssh "$host" "[ -d '$path' ] && $prefix rm -rf '$path'"
      elif [[ "$type" == "file" ]]; then
        echo "$(render_msg "${tr[removing_file]}" "path=$path")"
        ssh "$host" "[ -f '$path' ] && $prefix rm -f '$path'"
      fi
      ;;
    *)
      echo "$(render_msg "${tr[unsupported_state]}" "state=$state")"
      return 1
      ;;
  esac
}

check_dependencies_file() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/file.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if ! command -v ssh &> /dev/null; then
    echo "${tr[missing_deps]:-❌ [file] ssh no está disponible.}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [file] ssh disponible.}"
  return 0
}
