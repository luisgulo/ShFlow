#!/bin/bash
# Module: winremote_check
# Description: Verifica conectividad y ejecución remota básica en equipos Windows mediante SSH y PowerShell
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: ssh, powershell (en el host remoto)

winremote_check_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local winuser="${args[winuser]}"
  local winpassword="${args[winpassword]}"
  local port="${args[port]:-22}"
  local command="Write-Output 'Conexión establecida desde ShFlow'"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/winremote_check.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ -z "$host" || -z "$winuser" || -z "$winpassword" ]]; then
    echo "${tr[missing_args]:-❌ [winremote_check] Parámetros incompletos. Se requiere host, winuser y winpassword.}"
    return 1
  fi

  [[ "$host" == *@* ]] && host=$(echo "$host" | awk -F '@' '{print $2}')

  echo "$(render_msg "${tr[start]}" "host=$host")"

  if sshpass -p "$winpassword" ssh -o PreferredAuthentications=password -o StrictHostKeyChecking=no -p "$port" "$winuser@$host" powershell -Command "\"$command\"" &>/dev/null; then
    echo "$(render_msg "${tr[success]}" "host=$host")"
    return 0
  else
    echo "$(render_msg "${tr[fail]}" "host=$host")"
    return 1
  fi
}

check_dependencies_winremote_check() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/winremote_check.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if ! command -v ssh &> /dev/null; then
    echo "${tr[missing_ssh]:-❌ [winremote_check] ssh no está disponible.}"
    return 1
  fi
  echo "${tr[ssh_ok]:-✅ [winremote_check] ssh disponible.}"
  return 0
}
