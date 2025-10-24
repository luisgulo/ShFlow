#!/usr/bin/env bash
# Module: groups
# Description: Gestiona grupos del sistema (crear, modificar, eliminar)
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: getent, groupadd, groupmod, groupdel, sudo

groups_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local groupname="${args[groupname]}"
  local gid="${args[gid]:-}"
  local state="${args[state]:-create}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/groups.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  # 🛡️ Validación
  if [[ "$become" != "true" && "$EUID" -ne 0 ]]; then
    echo "${tr[priv_required]:-❌ [groups] Se requieren privilegios para gestionar grupos. Usa 'become: true'.}"
    return 1
  fi

  if [[ -z "$groupname" ]]; then
    echo "${tr[missing_groupname]:-❌ [groups] Falta el parámetro obligatorio 'groupname'}"
    return 1
  fi

  case "$state" in
    create)
      echo "${tr[enter_create]:-🔧 [groups] Entrando en create}"
      if getent group "$groupname" &>/dev/null; then
        echo "$(render_msg "${tr[exists]}" "groupname=$groupname")"
        return 0
      fi
      local cmd="$prefix groupadd \"$groupname\""
      [[ -n "$gid" ]] && cmd="$cmd -g \"$gid\""
      eval "$cmd" && echo "$(render_msg "${tr[created]}" "groupname=$groupname")"
      ;;
    modify)
      echo "${tr[enter_modify]:-🔧 [groups] Entrando en modify}"
      if ! getent group "$groupname" &>/dev/null; then
        echo "$(render_msg "${tr[not_exists]}" "groupname=$groupname")"
        return 1
      fi
      [[ -z "$gid" ]] && echo "${tr[nothing_to_modify]:-⚠️ [groups] Nada que modificar: falta 'gid'}" && return 0
      eval "$prefix groupmod -g \"$gid\" \"$groupname\"" && echo "$(render_msg "${tr[modified]}" "groupname=$groupname")"
      ;;
    absent)
      echo "${tr[enter_absent]:-🔧 [groups] Entrando en absent}"
      if ! getent group "$groupname" &>/dev/null; then
        echo "$(render_msg "${tr[already_deleted]}" "groupname=$groupname")"
        return 0
      fi
      eval "$prefix groupdel \"$groupname\"" && echo "$(render_msg "${tr[deleted]}" "groupname=$groupname")"
      ;;
    *)
      echo "$(render_msg "${tr[unsupported_state]}" "state=$state")"
      return 1
      ;;
  esac
}

check_dependencies_groups() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/groups.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  local missing=()
  for cmd in getent sudo; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [groups] Todas las dependencias están presentes}"
  return 0
}
