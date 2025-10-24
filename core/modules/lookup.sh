#!/usr/bin/env bash
# Module: lookup
# Description: Recupera secretos cifrados del vault local
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: gpg

lookup_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local vault_key="${args[key]}"
  local vault_dir="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/core/vault"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/lookup.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if [[ -f "$vault_dir/$vault_key.gpg" ]]; then
    gpg --quiet --batch --yes --passphrase-file "$HOME/.shflow.key" -d "$vault_dir/$vault_key.gpg" 2>/dev/null || \
    gpg --quiet --batch --yes -d "$vault_dir/$vault_key.gpg"
  else
    echo "$(render_msg "${tr[not_found]}" "key=$vault_key" "path=$vault_dir")"
    return 1
  fi
}

check_dependencies_lookup() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/lookup.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if ! command -v gpg &> /dev/null; then
    echo "${tr[missing_deps]:-❌ [lookup] gpg no disponible.}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [lookup] gpg disponible.}"
  return 0
}
