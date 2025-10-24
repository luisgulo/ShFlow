#!/bin/bash
# Module: service
# Description: Controla servicios del sistema remoto (start, stop, restart, enable, disable) con idempotencia
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: ssh, systemctl

service_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local name="${args[name]}"
  local state="${args[state]}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/service.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  case "$state" in
    start|stop|restart|enable|disable)
      echo "$(render_msg "${tr[executing]}" "state=$state" "name=$name" "host=$host")"
      ssh "$host" "$prefix systemctl $state '$name'"
      ;;
    *)
      echo "$(render_msg "${tr[unsupported]}" "state=$state")"
      return 1
      ;;
  esac
}

check_dependencies_service() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/service.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if ! command -v ssh &> /dev/null; then
    echo "${tr[missing_ssh]:-❌ [service] ssh no está disponible.}"
    return 1
  fi
  echo "${tr[ssh_ok]:-✅ [service] ssh disponible.}"

  if ! command -v systemctl &> /dev/null; then
    echo "${tr[missing_systemctl]:-⚠️ [service] systemctl no está disponible localmente. Se asumirá que existe en el host remoto.}"
  else
    echo "${tr[systemctl_ok]:-✅ [service] systemctl disponible localmente.}"
  fi
  return 0
}
