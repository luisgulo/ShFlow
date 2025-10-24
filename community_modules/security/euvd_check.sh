#!/bin/bash
# Module: euvd_check
# Description: Verifica si un host remoto está afectado por una vulnerabilidad EUVD consultando la base europea ENISA
# License: GPLv3
# Author: Luis GuLo
# Version: 0.6.0
# Dependencies: curl, jq, ssh, dpkg o rpm

euvd_check_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local enisa_id="${args[enisa_id]}"
  local package="${args[package]}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/euvd_check.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ -z "$enisa_id" || -z "$package" ]]; then
    echo "${tr[missing_args]:-❌ [euvd_check] Faltan argumentos: enisa_id y package son obligatorios.}"
    return 1
  fi

  echolog 1 "$(render_msg "${tr[start]}" "id=$enisa_id" "package=$package" "host=$host")"

  local pkg_cmd=""
  if ssh "$host" "command -v dpkg" &>/dev/null; then
    pkg_cmd="dpkg -s"
    echolog 1 "${tr[detected_dpkg]:-🔧 Gestor de paquetes detectado: dpkg}"
  elif ssh "$host" "command -v rpm" &>/dev/null; then
    pkg_cmd="rpm -q"
    echolog 1 "${tr[detected_rpm]:-🔧 Gestor de paquetes detectado: rpm}"
  else
    echo "${tr[no_pkg]:-❌ [euvd_check] No se detectó gestor de paquetes compatible en el host}"
    return 1
  fi

  local version_cmd="$pkg_cmd $package"
  [[ "$become" = "true" ]] && version_cmd="sudo $version_cmd"

  local version
  version=$(ssh "$host" "$version_cmd" 2>/dev/null | grep -E 'Version|version|^'"$package" | head -n1 | awk '{print $2}')

  if [[ -z "$version" ]]; then
    echolog 1 "$(render_msg "${tr[version_fail]}" "package=$package" "host=$host")"
    return 1
  fi

  echolog 1 "$(render_msg "${tr[version_ok]}" "version=$version")"

  local enisa_url="https://euvdservices.enisa.europa.eu/api/enisaid?id=$enisa_id"
  echolog 1 "$(render_msg "${tr[query_enisa]}" "id=$enisa_id")"
  local response
  response=$(curl -s -X GET "$enisa_url")

  if ! echo "$response" | jq -e .description &>/dev/null; then
    echolog 1 "$(render_msg "${tr[invalid_response]}" "id=$enisa_id")"
    echolog 1 "$(render_msg "${tr[response_trunc]}" "snippet=$(echo "$response" | head -c 120 | tr '\n' ' ')")"
    return 1
  fi

  local score desc aliases
  score=$(echo "$response" | jq -r '.baseScore // empty')
  desc=$(echo "$response" | jq -r '.description // empty')
  aliases=$(echo "$response" | jq -r '.aliases[]?')

  [[ -n "$score" ]] && echolog 1 "$(render_msg "${tr[score]}" "score=$score")"
  echolog 2 "$(render_msg "${tr[desc]}" "desc=$desc")"
  [[ -n "$aliases" ]] && echolog 1 "$(render_msg "${tr[aliases]}" "aliases=$aliases")"

  if echo "$desc" | grep -iq "$package" && echo "$desc" | grep -q "$version"; then
    echo "$(render_msg "${tr[vulnerable]}" "host=$host" "id=$enisa_id")"
    return 1
  else
    echo "$(render_msg "${tr[safe]}" "host=$host" "id=$enisa_id")"
    return 0
  fi
}

check_dependencies_euvd_check() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/euvd_check.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  for cmd in ssh curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "$(render_msg "${tr[missing_dep]}" "cmd=$cmd")"
      return 1
    fi
  done
  echo "${tr[deps_ok]:-✅ [euvd_check] ssh, curl y jq disponibles.}"
  return 0
}
