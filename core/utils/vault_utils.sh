#!/bin/bash
# Utility: vault_utils
# Description: Funciones para acceso seguro al vault de ShFlow
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: gpg

VAULT_DIR="${VAULT_DIR:-core/vault}"
VAULT_KEY="${VAULT_KEY:-$HOME/.shflow.key}"

# 🧩 Cargar render_msg si no está disponible
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

# 🌐 Cargar traducciones
lang="${SHFLOW_LANG:-es}"
trfile="$PROJECT_ROOT/core/utils/vault_utils.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

get_secret() {
  local key="$1"
  local value

  if [ ! -f "$VAULT_DIR/$key.gpg" ]; then
    echo "$(render_msg "${tr[missing]}" "key=$key" "dir=$VAULT_DIR")"
    return 1
  fi

  value=$(gpg --quiet --batch --yes --passphrase-file "$VAULT_KEY" -d "$VAULT_DIR/$key.gpg" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "$(render_msg "${tr[decrypt_fail]}" "key=$key")"
    return 1
  fi

  echo "$value"
}
