#!/bin/bash
# ShFlow Vault Initializer
# License: GPLv3
# Author: Luis GuLo
# Version: 1.3.0
# Dependencies: gpg

set -euo pipefail

# 📁 Rutas defensivas
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VAULT_DIR="$PROJECT_ROOT/core/vault"
VAULT_KEY="${VAULT_KEY:-$HOME/.shflow.key}"
VAULT_PUBKEY="${VAULT_PUBKEY:-$HOME/.shflow.pub}"

# 🧩 Cargar render_msg si no está disponible
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

# 🌐 Cargar traducciones
lang="${SHFLOW_LANG:-es}"
trfile="$PROJECT_ROOT/core/utils/vault-init.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

generate_key() {
  echo "${tr[gen_key]:-🔐 Generando nueva clave simétrica...}"
  head -c 64 /dev/urandom | base64 > "$VAULT_KEY"
  chmod 600 "$VAULT_KEY"
  echo "$(render_msg "${tr[key_created]}" "path=$VAULT_KEY")"
}

rotate_key() {
  echo "${tr[rotate_start]:-🔄 Rotando clave y re-cifrando secretos...}"
  local OLD_KEY="$VAULT_KEY.old"

  cp "$VAULT_KEY" "$OLD_KEY"
  generate_key

  for file in "$VAULT_DIR"/*.gpg; do
    key=$(basename "$file" .gpg)
    echo "$(render_msg "${tr[recrypt]}" "key=$key")"
    gpg --quiet --batch --yes --passphrase-file "$OLD_KEY" -d "$file" | \
      gpg --symmetric --batch --yes --passphrase-file "$VAULT_KEY" -o "$VAULT_DIR/$key.gpg.new"
    mv "$VAULT_DIR/$key.gpg.new" "$VAULT_DIR/$key.gpg"
  done

  echo "$(render_msg "${tr[rotate_done]}" "path=$OLD_KEY")"
}

status() {
  echo "${tr[status_title]:-📊 Estado del Vault}"
  echo "-------------------"
  echo "$(render_msg "${tr[sym_key]}" "status=$( [ -f "$VAULT_KEY" ] && echo "${tr[present]}" || echo "${tr[absent]}")")"
  echo "$(render_msg "${tr[pub_key]}" "status=$( [ -f "$VAULT_PUBKEY" ] && echo "${tr[present]}" || echo "${tr[absent]}")")"
  echo "$(render_msg "${tr[vault_path]}" "path=$VAULT_DIR")"
  echo "$(render_msg "${tr[secrets]}" "count=$(ls "$VAULT_DIR"/*.gpg 2>/dev/null | wc -l)")"
  echo "$(render_msg "${tr[last_mod]}" "date=$(date -r "$VAULT_KEY" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)")"
}

generate_pubkey() {
  echo "${tr[asym_start]:-🔐 Configurando cifrado asimétrico...}"
  echo "${tr[asym_hint]:-⚠️ Se requiere que la clave pública esté exportada previamente.}"
  echo "    gpg --export -a 'usuario@dominio' > $VAULT_PUBKEY"
  if [ -f "$VAULT_PUBKEY" ]; then
    echo "$(render_msg "${tr[pubkey_found]}" "path=$VAULT_PUBKEY")"
  else
    echo "${tr[pubkey_missing]:-❌ Clave pública no encontrada. Exporta primero con GPG.}"
    exit 1
  fi
}

main() {
  case "${1:-}" in
    --rotate)
      [ -f "$VAULT_KEY" ] || { echo "${tr[no_key]:-❌ No existe clave actual. Ejecuta sin --rotate primero.}"; exit 1; }
      rotate_key
      ;;
    --status)
      status
      ;;
    --asymmetric)
      generate_pubkey
      ;;
    *)
      if [ -f "$VAULT_KEY" ]; then
        echo "$(render_msg "${tr[key_exists]}" "path=$VAULT_KEY")"
      else
        generate_key
      fi
      ;;
  esac
}

main "$@"
