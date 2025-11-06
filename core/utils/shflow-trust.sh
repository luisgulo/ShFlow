#!/bin/bash
# Utility: shflow-trust
# Description: Evalúa acceso SSH y privilegios sudo para cada host del inventario
# Author: Luis GuLo
# Version: 0.4.1

set -euo pipefail

# 📁 Rutas defensivas
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
INVENTORY="$PROJECT_ROOT/core/inventory/hosts.yaml"
REPORT="$PROJECT_ROOT/core/inventory/trust_report.yaml"
TIMEOUT=5
USER="${USER:-$(whoami)}"

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

trfile="$PROJECT_ROOT/core/utils/shflow-trust.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

echo "$(render_msg "${tr[start]}" "user=$USER")"
echo "$(render_msg "${tr[inventory]}" "path=$INVENTORY")"
echo "$(render_msg "${tr[report]}" "path=$REPORT")"
echo ""

# 🧪 Validar dependencia yq
if ! command -v $YQ_BIN &>/dev/null; then
  echo "$(render_msg "${tr[missing_dep]}" "cmd=$YQ_BIN")"
  exit 1
fi

# 🧹 Regenerar informe
{
  echo "# $(render_msg "${tr[report_title]}")"
  echo "# $(render_msg "${tr[report_date]}" "date=$(date)")"
  echo ""
} > "$REPORT"

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

  if ssh -o BatchMode=yes -o ConnectTimeout=$TIMEOUT "$USER@$IP" 'echo ok' &>/dev/null; then  
    echo "${tr[ssh_ok]:-   ✅ SSH: ok}"
    SSH_STATUS="ok"

    if ssh -o BatchMode=yes "$USER@$IP" 'sudo -n true' &>/dev/null; then
      echo "${tr[sudo_ok]:-   ✅ SUDO: ok}"
      SUDO_STATUS="ok"
    else
      echo "${tr[sudo_pw]:-   ⚠️ SUDO: requiere contraseña o no permitido}"
      SUDO_STATUS="password_required"
    fi
  else
    echo "${tr[ssh_fail]:-   ❌ SSH: fallo de conexión}"
    SSH_STATUS="failed"
    SUDO_STATUS="unknown"
  fi

  {
    echo "$host:"
    echo "  ip: $IP"
    echo "  ssh: $SSH_STATUS"
    echo "  sudo: $SUDO_STATUS"
    echo ""
  } >> "$REPORT"
done

echo "$(render_msg "${tr[done]}" "path=$REPORT")"
