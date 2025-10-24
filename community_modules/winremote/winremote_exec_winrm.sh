#!/bin/bash
# Module: winremote_exec_winrm
# Description: Ejecuta comandos en un host Windows remoto vía WSMan (WinRM) desde Linux
# License: GPLv3
# Author: Luis GuLo
# Version: 1.3.0
# Dependencies: wsman

winremote_exec_winrm_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local winuser="${args[winuser]}"
  local winpassword="${args[winpassword]}"
  local port="${args[port]:-5985}"
  local command="${args[command]}"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/winremote_exec_winrm.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ -z "$host" || -z "$winuser" || -z "$winpassword" || -z "$command" ]]; then
    echo "${tr[missing_args]:-❌ [winremote_exec_winrm] Parámetros incompletos. Se requiere host, winuser, winpassword y command.}"
    return 1
  fi

  [[ "$host" == *@* ]] && host=$(echo "$host" | awk -F '@' '{print $2}')

  local xml_file=$(mktemp --suffix=.xml)
  trap '[[ -n "$xml_file" && -f "$xml_file" ]] && rm -f "$xml_file"' EXIT

  cat > "$xml_file" <<EOF
<p:Create_INPUT xmlns:p="http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/Win32_Process">
  <p:CommandLine>${command}</p:CommandLine>
</p:Create_INPUT>
EOF

  echo "$(render_msg "${tr[start]}" "host=$host" "port=$port" "user=$winuser")"

  wsman invoke http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/Win32_Process \
    -a Create \
    -h "$host" \
    -P "$port" \
    -u "$winuser" \
    -p "$winpassword" \
    -y basic \
    -J "$xml_file"

  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    echo "${tr[success]:-✅ [winremote_exec_winrm] Comando ejecutado correctamente vía WSMan.}"
    return 0
  else
    echo "$(render_msg "${tr[fail]}" "code=$exit_code")"
    return $exit_code
  fi
}

check_dependencies_winremote_exec_winrm() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/winremote_exec_winrm.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if ! command -v wsman &> /dev/null; then
    echo "${tr[missing_wsman]:-❌ [winremote_exec_winrm] El cliente 'wsman' no está disponible.}"
    return 1
  fi
  echo "${tr[wsman_ok]:-✅ [winremote_exec_winrm] Cliente 'wsman' disponible.}"
  return 0
}
