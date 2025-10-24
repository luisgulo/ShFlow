#!/bin/bash
# Module: vault-remote
# Description: Sincroniza secretos cifrados entre vault local y remoto
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: ssh, scp, gpg

VAULT_DIR="core/vault"

vault_remote_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local action="${args[action]}"
  local key="${args[key]}"
  local remote_path="${args[remote_path]:-/tmp/shflow_vault}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/vault-remote.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  case "$action" in
    push)
      if [ ! -f "$VAULT_DIR/$key.gpg" ]; then
        echo "$(render_msg "${tr[missing_local]}" "key=$key")"
        return 1
      fi
      scp "$VAULT_DIR/$key.gpg" "$host:$remote_path/$key.gpg"
      ssh "$host" "$prefix mkdir -p '$remote_path'"
      echo "$(render_msg "${tr[pushed]}" "key=$key" "host=$host" "path=$remote_path")"
      ;;
    pull)
      ssh "$host" "$prefix test -f '$remote_path/$key.gpg'" || {
        echo "$(render_msg "${tr[missing_remote]}" "key=$key")"
        return 1
      }
      scp "$host:$remote_path/$key.gpg" "$VAULT_DIR/$key.gpg"
      echo "$(render_msg "${tr[pulled]}" "key=$key" "host=$host")"
      ;;
    sync)
      ssh "$host" "$prefix mkdir -p '$remote_path'"
      scp "$VAULT_DIR/"*.gpg "$host:$remote_path/"
      echo "$(render_msg "${tr[synced]}" "host=$host" "path=$remote_path")"
      ;;
    *)
      echo "$(render_msg "${tr[unsupported]}" "action=$action")"
      return 1
      ;;
  esac
}

check_dependencies_vault_remote() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/vault-remote.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  for cmd in ssh scp gpg; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "$(render_msg "${tr[missing_deps]}" "cmd=$cmd")"
      return 1
    fi
  done
  echo "${tr[deps_ok]:-✅ [vault-remote] Dependencias disponibles.}"
  return 0
}
