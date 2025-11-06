#!/bin/bash
# Utility: shflow-ssh-init
# Description: Inicializa acceso SSH sin contraseña en los hosts del inventario
# Author: Luis GuLo
# Version: 0.2.1

set -euo pipefail

# 📁 Rutas defensivas
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
INVENTORY="$PROJECT_ROOT/core/inventory/hosts.yaml"
TIMEOUT=5
USER="${USER:-$(whoami)}"
KEY="${KEY:-$HOME/.ssh/id_rsa.pub}"

# 🔧 yq segun arquitectura
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) YQ_BIN="$PROJECT_ROOT/core/utils/yq_linux_amd64" ;;
  i686|i386) YQ_BIN="$PROJECT_ROOT/core/utils/yq_linux_386" ;;
  aarch64) YQ_BIN="$PROJECT_ROOT/core/utils/yq_linux_arm64" ;;
  armv7l|armv6l) YQ_BIN="$PROJECT_ROOT/core/utils/yq_linux_arm" ;;
  *) echo "❌ Arquitectura no soportada: $ARCH"; exit 1 ;;
esac

# 🧩 Cargar render_msg si no está disponible
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

export SHFLOW_LANG="${SHFLOW_LANG:-es}"
# 🌐 Cargar traducciones
lang="${SHFLOW_LANG:-es}"

trfile="$PROJECT_ROOT/core/utils/shflow-ssh-init.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

echo "$(render_msg "${tr[start]}" "user=$USER")"
echo "$(render_msg "${tr[inventory]}" "path=$INVENTORY")"
echo "$(render_msg "${tr[key]}" "key=$KEY")"
echo ""

# 🧪 Validar dependencias
for cmd in $YQ_BIN ssh ssh-copy-id; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "$(render_msg "${tr[missing_dep]}" "cmd=$cmd")"
    exit 1
  fi
done

# 🔁 Extraer hosts
HOSTS=()
HOSTS_RAW=$($YQ_BIN eval -o=json ".all.hosts | keys | .[]" "$INVENTORY")
[ -z "$HOSTS_RAW" ] && echo "${tr[no_hosts]:-❌ No se encontraron hosts en el inventario.}" && exit 1

while IFS= read -r line; do
  HOSTS+=("$(echo "$line" | sed 's/^\"\(.*\)\"$/\1/')")  # Eliminar comillas
done <<< "$HOSTS_RAW"

# 🔍 Evaluar cada host
for host in "${HOSTS[@]}"; do
  IP=$($YQ_BIN eval -o=json ".all.hosts.\"$host\".ansible_host" "$INVENTORY")
  [[ "$IP" == "null" || -z "$IP" ]] && echo "$(render_msg "${tr[missing_ip]}" "host=$host")" && continue

  echo "$(render_msg "${tr[checking]}" "host=$host" "ip=$IP")"

  if ssh -o BatchMode=yes -o ConnectTimeout=$TIMEOUT "$USER@$IP" 'true' &>/dev/null; then
    echo "${tr[skip]:-   🔁 Inicialización SSH no es necesaria}"
    continue
  fi

  echo "$(render_msg "${tr[copying]}" "user=$USER" "ip=$IP")"
  if ssh-copy-id -i "$KEY" "$USER@$IP"; then
    echo "${tr[success]:-   ✅ Clave pública instalada correctamente}"
  else
    echo "${tr[fail]:-   ❌ Fallo al instalar clave pública}"
  fi

  echo ""
done

echo "${tr[done]:-✅ Proceso de inicialización SSH completado}"
