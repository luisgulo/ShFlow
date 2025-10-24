#!/usr/bin/env bash
# ShFlow Vault Manager
# License: GPLv3
# Author: Luis GuLo
# Version: 1.5.1
# Dependencies: gpg

set -euo pipefail

# 🧭 Detección de la raíz del proyecto
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# 📁 Rutas clave
VAULT_DIR="$PROJECT_ROOT/core/vault"
VAULT_KEY="${VAULT_KEY:-$HOME/.shflow.key}"
VAULT_PUBKEY="${VAULT_PUBKEY:-$HOME/.shflow.pub}"
VAULT_RECIPIENT="${VAULT_RECIPIENT:-}"

# 🧩 Cargar render_msg si no está disponible
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

# 🌐 Cargar traducciones
lang="${SHFLOW_LANG:-es}"
trfile="$PROJECT_ROOT/vault.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

encrypt_secret() {
  local key="$1"
  local value="$2"

  if [ -f "$VAULT_PUBKEY" ]; then
    echo "$(render_msg "${tr[encrypt_asym]:-🔐 Usando cifrado asimétrico para '{key}'}" "key=$key")"
    echo "$value" | gpg --encrypt --armor --batch --yes --recipient "$VAULT_RECIPIENT" -o "$VAULT_DIR/$key.gpg"
  elif [ -f "$VAULT_KEY" ]; then
    echo "$(render_msg "${tr[encrypt_sym]:-🔐 Usando cifrado simétrico para '{key}'}" "key=$key")"
    echo "$value" | gpg --symmetric --batch --yes --passphrase-file "$VAULT_KEY" -o "$VAULT_DIR/$key.gpg"
  else
    echo "${tr[missing_key]:-❌ No se encontró clave para cifrar. Ejecuta vault-init.sh primero.}"
    return 1
  fi

  echo "$(render_msg "${tr[secret_saved]:-✅ Secreto '{key}' guardado en {dir}}" "key=$key" "dir=$VAULT_DIR")"
}

decrypt_secret() {
  local key="$1"
  gpg --quiet --batch --yes --passphrase-file "$VAULT_KEY" -d "$VAULT_DIR/$key.gpg" 2>/dev/null || \
  gpg --quiet --batch --yes -d "$VAULT_DIR/$key.gpg"
}

list_secrets() {
  ls "$VAULT_DIR"/*.gpg 2>/dev/null | sed 's|.*/\(.*\)\.gpg|\1|'
}

secret_exists() {
  local key="$1"
  [[ -f "$VAULT_DIR/$key.gpg" ]]
}

remove_secret() {
  local key="$1"
  rm -f "$VAULT_DIR/$key.gpg" && echo "$(render_msg "${tr[secret_removed]:-🗑️ Secreto '{key}' eliminado.}" "key=$key")"
}

edit_secret() {
  local key="$1"
  local current
  current=$(decrypt_secret "$key")
  read -s -p "$(render_msg "${tr[edit_prompt]:-🔑 Nuevo valor para '{key}':}" "key=$key")" new_value
  echo ""
  encrypt_secret "$key" "$new_value"
}

export_secrets() {
  for file in "$VAULT_DIR"/*.gpg; do
    varname="$(basename "$file" .gpg)"
    value="$(decrypt_secret "$varname")"
    echo "export $varname=\"$value\""
  done
}

vault_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local action="${args[action]:-}"
  local key="${args[key]:-}"
  local value="${args[value]:-}"
  local become="${args[become]:-}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  case "$action" in
    get|show) decrypt_secret "$key" ;;
    add) encrypt_secret "$key" "$value" ;;
    edit) edit_secret "$key" ;;
    remove) remove_secret "$key" ;;
    exists) secret_exists "$key" ;;
    list) list_secrets ;;
    export) export_secrets ;;
    *) echo "$(render_msg "${tr[action_invalid]:-❌ [vault] Acción '{action}' no soportada.}" "action=$action")"; return 1 ;;
  esac
}

check_dependencies_vault() {
  if ! command -v gpg &> /dev/null; then
    echo "${tr[missing_dep]:-❌ [vault] gpg no está disponible.}"
    return 1
  fi
  echo "${tr[dep_ok]:-✅ [vault] gpg disponible.}"
  return 0
}

main() {
  case "${1:-}" in
    add)
      read -s -p "$(render_msg "${tr[cli_prompt]:-🔑 Valor para '{key}':}" "key=$2")" value
      echo ""
      encrypt_secret "$2" "$value"
      ;;
    get|show) decrypt_secret "$2" ;;
    edit) edit_secret "$2" ;;
    remove) remove_secret "$2" ;;
    list) list_secrets ;;
    export) export_secrets ;;
    exists)
      secret_exists "$2" && echo "${tr[exists]:-✅ Existe}" || echo "${tr[not_exists]:-❌ No existe}"
      ;;
    *)
      echo "${tr[usage]:-Uso: vault.sh {add|get|show|edit|remove|list|export|exists} <clave>}"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
