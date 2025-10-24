#!/usr/bin/env bash
# Module: download
# Description: Descarga ficheros remotos con soporte para reintentos, proxy y reanudación
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: wget o curl, sudo (si become=true)

download_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local url="${args[url]}"
  local dest="${args[dest]:-$(basename "$url")}"
  local proxy="${args[proxy]:-}"
  local continue="${args[continue]:-true}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/download.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ -z "$url" ]]; then
    echo "${tr[missing_url]:-❌ [download] Falta el parámetro obligatorio 'url'}"
    return 1
  fi

  local cmd=""
  if command -v wget &>/dev/null; then
    echo "${tr[using_wget]:-📦 [download] Usando wget}"
    cmd="$prefix wget \"$url\" -O \"$dest\""
    [[ "$continue" == "true" ]] && cmd="$cmd -c"
    [[ -n "$proxy" ]] && cmd="$cmd -e use_proxy=yes -e http_proxy=\"$proxy\""
  elif command -v curl &>/dev/null; then
    echo "${tr[using_curl]:-📦 [download] Usando curl}"
    cmd="$prefix curl -L \"$url\" -o \"$dest\""
    [[ "$continue" == "true" ]] && cmd="$cmd -C -"
    [[ -n "$proxy" ]] && cmd="$cmd --proxy \"$proxy\""
  else
    echo "${tr[missing_tool]:-❌ [download] Ni wget ni curl están disponibles}"
    return 1
  fi

  echo "$(render_msg "${tr[start]}" "url=$url" "dest=$dest")"
  eval "$cmd" && echo "$(render_msg "${tr[done]}" "dest=$dest")"
}

check_dependencies_download() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/download.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
    echo "${tr[missing_tool]:-❌ [download] Se requiere 'wget' o 'curl'}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [download] Herramienta de descarga disponible}"
  return 0
}
