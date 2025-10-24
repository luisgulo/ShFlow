#!/usr/bin/env bash
# Module: replace
# Description: Reemplaza texto en archivos usando expresiones regulares
# Author: Luis GuLo
# Version: 0.2.0
# Dependencies: sed, cp, tee

replace_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local path="${args[path]}"
  local regexp="${args[regexp]}"
  local replace="${args[replace]}"
  local backup="${args[backup]:-true}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/replace.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if [[ ! -f "$path" ]]; then
    echo "$(render_msg "${tr[missing_file]}" "path=$path")"
    return 1
  fi

  if [[ "$backup" == "true" ]]; then
    cp "$path" "$path.bak"
    echo "$(render_msg "${tr[backup_created]}" "path=$path")"
  fi

  $prefix sed -i "s|$regexp|$replace|g" "$path"
  echo "$(render_msg "${tr[replaced]}" "path=$path")"
}

check_dependencies_replace() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/replace.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  local missing=()
  for cmd in sed cp tee; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [replace] Todas las dependencias están disponibles}"
  return 0
}
