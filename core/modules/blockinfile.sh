#!/usr/bin/env bash
# Module: blockinfile
# Description: Inserta o actualiza bloques de texto delimitados en archivos
# Author: Luis GuLo
# Version: 0.2.0
# Dependencies: grep, sed, tee, awk

blockinfile_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"
  done

  local path="${args[path]}"
  local block="${args[block]}"
  local marker="${args[marker]:-SHFLOW}"
  local create="${args[create]:-true}"
  local backup="${args[backup]:-true}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  local start="# BEGIN $marker"
  local end="# END $marker"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/blockinfile.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ ! -f "$path" ]]; then
    if [[ "$create" == "true" ]]; then
      echo "$(render_msg "${tr[creating]}" "path=$path")"
      touch "$path"
    else
      echo "$(render_msg "${tr[missing_file]}" "path=$path")"
      return 1
    fi
  fi

  if [[ "$backup" == "true" ]]; then
    cp "$path" "$path.bak"
    echo "$(render_msg "${tr[backup]}" "path=$path")"
  fi

  if grep -q "$start" "$path"; then
    echo "$(render_msg "${tr[replacing]}" "marker=$marker")"
    $prefix sed -i "/$start/,/$end/d" "$path"
  fi

  echo "$(render_msg "${tr[inserting]}" "marker=$marker")"
  {
    echo "$start"
    echo "$block"
    echo "$end"
  } | $prefix tee -a "$path" > /dev/null
}

check_dependencies_blockinfile() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/blockinfile.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  local missing=()
  for cmd in grep sed tee awk; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [blockinfile] Todas las dependencias están disponibles}"
  return 0
}
