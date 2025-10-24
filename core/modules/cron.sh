#!/bin/bash
# Module: cron
# Description: Gestiona entradas de cron para usuarios del sistema (crear, modificar, eliminar, listar)
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: bash, crontab, grep, id, sudo

cron_task() {
  local host="$1"; shift
  local alias="" user="" state="" schedule="" command=""
  for arg in "$@"; do
    case "$arg" in
      alias=*) alias="${arg#alias=}" ;;
      user=*) user="${arg#user=}" ;;
      state=*) state="${arg#state=}" ;;
      schedule=*) schedule="${arg#schedule=}" ;;
      command=*) command="${arg#command=}" ;;
    esac
  done

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/cron.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ -z "$user" || -z "$state" ]]; then
    echo "${tr[missing_args]:-❌ [cron] Faltan argumentos obligatorios: 'user' y 'state'}"
    return 1
  fi

  if ! id "$user" &>/dev/null; then
    echo "$(render_msg "${tr[user_not_found]}" "user=$user")"
    return 1
  fi

  local tag="# shflow:$alias"
  local tmpfile
  tmpfile=$(mktemp)

  echo "$(render_msg "${tr[checking]}" "user=$user")"
  sudo crontab -u "$user" -l 2>/dev/null > "$tmpfile" || true

  case "$state" in
    list)
      echo "$(render_msg "${tr[list]}" "user=$user")"
      grep -E "^.*$tag|^[^#]" "$tmpfile" || echo "${tr[no_entries]:-⚠️ [cron] No hay entradas visibles}"
      rm -f "$tmpfile"
      return 0
      ;;
    absent)
      if grep -q "$tag" "$tmpfile"; then
        grep -v "$tag" "$tmpfile" > "${tmpfile}.new"
        sudo crontab -u "$user" "${tmpfile}.new"
        echo "$(render_msg "${tr[removed]}" "alias=$alias")"
        rm -f "${tmpfile}.new"
      else
        echo "$(render_msg "${tr[not_found]}" "alias=$alias")"
      fi
      rm -f "$tmpfile"
      return 0
      ;;
    present)
      if [[ -z "$alias" || -z "$schedule" || -z "$command" ]]; then
        echo "${tr[missing_present]:-❌ [cron] Para 'present' se requieren: alias, schedule y command}"
        rm -f "$tmpfile"
        return 1
      fi
      grep -v "$tag" "$tmpfile" > "${tmpfile}.new"
      echo "$schedule $command $tag" >> "${tmpfile}.new"
      sudo crontab -u "$user" "${tmpfile}.new"
      echo "$(render_msg "${tr[added]}" "alias=$alias")"
      rm -f "$tmpfile" "${tmpfile}.new"
      return 0
      ;;
    *)
      echo "$(render_msg "${tr[unsupported]}" "state=$state")"
      rm -f "$tmpfile"
      return 1
      ;;
  esac
}

check_dependencies_cron() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/cron.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if ! command -v sudo &>/dev/null; then
    echo "${tr[missing_sudo]:-❌ [cron] El comando 'sudo' no está disponible}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [cron] Dependencias OK}"
  return 0
}
