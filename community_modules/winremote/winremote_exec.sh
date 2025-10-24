#!/bin/bash
# Module: winremote_exec
# Description: Ejecuta comandos PowerShell en un host Windows remoto vía SSH
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: sshpass, ssh

winremote_exec_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local winuser="${args[winuser]}"
  local winpassword="${args[winpassword]}"
  local port="${args[port]:-22}"
  local command="${args[command]}"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/winremote_exec.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ -z "$host" || -z "$winuser" || -z "$winpassword" || -z "$command" ]]; then
    echo "${tr[missing_args]:-❌ [winremote_exec] Parámetros incompletos. Se requiere host, winuser, winpassword y command.}"
    return 1
  fi

  [[ "$host" == *@* ]] && host=$(echo "$host" | awk -F '@' '{print $2}')
  local safe_command=$(printf "%q" "$command")

  echo "$(render_msg "${tr[start]}" "host=$host" "port=$port" "user=$winuser")"

  sshpass -p "$winpassword" ssh -o PreferredAuthentications=password -o StrictHostKeyChecking=no -p "$port" "$winuser@$host" \
    "powershell -Command \"$safe_command\""

  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    echo "${tr[success]:-✅ [winremote_exec] Comando ejecutado correctamente.}"
    return 0
  else
    echo "$(render_msg "${tr[fail]}" "code=$exit_code")"
    return $exit_code
  fi
}

check_dependencies_winremote_exec() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/winremote_exec.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if ! command -v sshpass &> /dev/null || ! command -v ssh &> /dev/null; then
    echo "${tr[missing_deps]:-❌ [winremote_exec] sshpass o ssh no están disponibles.}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [winremote_exec] sshpass y ssh disponibles.}"
  return 0
}
