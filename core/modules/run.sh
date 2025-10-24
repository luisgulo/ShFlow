#!/bin/bash
# Module: run
# Description: Ejecuta comandos remotos vía SSH, con soporte para vault y sudo
# License: GPLv3
# Author: Luis GuLo
# Version: 2.0.0
# Dependencies: ssh, core/utils/vault_utils.sh

# Detectar raíz del proyecto si no está definida
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Cargar utilidades
source "$PROJECT_ROOT/core/utils/vault_utils.sh"

run_task() {
  local host="$1"; shift
  declare -A args

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      *=*)
        key="${1%%=*}"
        value="${1#*=}"
        args["$key"]="$value"
        ;;
    esac
    shift
  done

  local command="${args[command]}"
  local become="${args[become]:-}"
  local vault_key="${args[vault_key]:-}"

  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/run.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$val"; done < "$trfile"
  fi

  # 🧠 Comandos que no deben ejecutarse con sudo
  local safe_cmds=("echo" "true" "false" "command" "which" "exit" "test")
  local first_cmd="${command%% *}"
  for safe in "${safe_cmds[@]}"; do
    if [[ "$first_cmd" == "$safe" ]]; then
      prefix=""
      break
    fi
  done

  # 🔁 Interpolación de variables ShFlow
  for var in $(compgen -A variable | grep '^shflow_vars_'); do
    key="${var#shflow_vars_}"
    value="${!var}"
    command="${command//\{\{ $key \}\}/$value}"
  done

  echo "$(render_msg "${tr[start]}" "host=$host" "command=$command" "prefix=$prefix")"

  if [ -n "$vault_key" ]; then
    local secret
    secret=$(get_secret "$vault_key") || {
      echo "$(render_msg "${tr[vault_fail]}" "vault_key=$vault_key")"
      return 1
    }
    ssh "$host" "$prefix TOKEN='$secret' $command"
  else
    ssh "$host" "$prefix $command"
  fi
}

check_dependencies_run() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/run.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if ! command -v ssh &> /dev/null; then
    echo "${tr[missing_deps]:-❌ [run] ssh no está disponible.}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [run] ssh disponible.}"
  return 0
}
