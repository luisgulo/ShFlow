#!/usr/bin/env bash
# Module: lineinfile
# Description: Asegura la presencia o reemplazo de una línea en un archivo
# Author: Luis GuLo
# Version: 0.2.0
# Dependencies: grep, sed, tee, awk

lineinfile_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local path="${args[path]}"
  local line="${args[line]}"
  local regexp="${args[regexp]}"
  local insert_after="${args[insert_after]}"
  local create="${args[create]:-true}"
  local backup="${args[backup]:-true}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/lineinfile.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

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

  if [[ -n "$regexp" && $(grep -Eq "$regexp" "$path" && echo "yes") == "yes" ]]; then
    echo "$(render_msg "${tr[replacing]}" "regexp=$regexp")"
    $prefix sed -i "s|$regexp|$line|" "$path"
    return 0
  fi

  if [[ -n "$insert_after" && $(grep -q "$insert_after" "$path" && echo "yes") == "yes" ]]; then
    echo "$(render_msg "${tr[inserting]}" "after=$insert_after")"
    $prefix sed -i "/$insert_after/a $line" "$path"
    return 0
  fi

  if grep -Fxq "$line" "$path"; then
    echo "$(render_msg "${tr[exists]}" "line=$line")"
    return 0
  fi

  echo "${tr[appending]:-➕ [lineinfile] Añadiendo línea al final}"
  echo "$line" | $prefix tee -a "$path" > /dev/null
}

check_dependencies_lineinfile() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/lineinfile.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  local missing=()
  for cmd in grep sed tee awk; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [lineinfile] Todas las dependencias están disponibles}"
  return 0
}
