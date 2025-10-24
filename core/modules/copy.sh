#!/bin/bash
# Module: copy
# Description: Copia archivos locales al host remoto usando scp
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: scp, ssh

copy_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local src="${args[src]}"
  local dest="${args[dest]}"
  local mode="${args[mode]}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/copy.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ -z "$src" || -z "$dest" ]]; then
    echo "${tr[missing_args]:-❌ [copy] Faltan parámetros: src y dest son obligatorios}"
    return 1
  fi

  echo "$(render_msg "${tr[copying]}" "src=$src" "host=$host")"
  scp "$src" "$host:/tmp/shflow_tmpfile" || {
    echo "$(render_msg "${tr[scp_fail]}" "src=$src" "host=$host")"
    return 1
  }

  echo "$(render_msg "${tr[moving]}" "dest=$dest")"
  ssh "$host" "$prefix mv /tmp/shflow_tmpfile '$dest' && $prefix chmod $mode '$dest'" && \
  echo "$(render_msg "${tr[done]}" "dest=$dest")"
}

check_dependencies_copy() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/copy.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  local missing=()
  for cmd in scp ssh; do
    command -v "$cmd" &> /dev/null || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [copy] Todas las dependencias están disponibles}"
  return 0
}
