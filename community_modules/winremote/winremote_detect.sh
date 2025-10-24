#!/bin/bash
# Module: winremote_detect
# Description: Detecta si un host Windows tiene habilitado SSH, WinRM, ambos o ninguno
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: nc, curl, pwsh (opcional)

winremote_detect_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local ssh_port="${args[ssh_port]:-22}"
  local winrm_port="${args[winrm_port]:-5985}"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/winremote_detect.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  [[ "$host" == *@* ]] && host=$(echo "$host" | awk -F '@' '{print $2}')

  echo "$(render_msg "${tr[start]}" "host=$host")"

  local ssh_status="${tr[ssh_off]:-❌ SSH no disponible}"
  local winrm_status="${tr[winrm_off]:-❌ WinRM no disponible}"

  if nc -z -w2 "$host" "$ssh_port" &>/dev/null; then
    ssh_status="$(render_msg "${tr[ssh_on]}" "port=$ssh_port")"
  fi

  if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://$host:$winrm_port/wsman" | grep -q "405"; then
    winrm_status="$(render_msg "${tr[winrm_on]}" "port=$winrm_port")"
  fi

  echo "    $ssh_status"
  echo "    $winrm_status"

  if [[ "$ssh_status" == *✅* && "$winrm_status" == *✅* ]]; then
    echo "$(render_msg "${tr[both]}" "host=$host")"
    return 0
  elif [[ "$ssh_status" == *✅* || "$winrm_status" == *✅* ]]; then
    echo "${tr[one]:-🟡 Uno de los protocolos está disponible}"
    return 0
  else
    echo "$(render_msg "${tr[none]}" "host=$host")"
    return 1
  fi
}

check_dependencies_winremote_detect() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/winremote_detect.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if ! command -v nc &> /dev/null || ! command -v curl &> /dev/null; then
    echo "${tr[missing_deps]:-❌ [winremote_detect] nc o curl no están disponibles.}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [winremote_detect] nc y curl disponibles.}"
  return 0
}
