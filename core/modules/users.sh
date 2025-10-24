#!/usr/bin/env bash
# Module: users
# Description: Gestiona usuarios del sistema (crear, modificar, eliminar)
# Author: Luis GuLo
# Version: 1.4.0
# Dependencies: id, useradd, usermod, userdel, groupadd, sudo

users_task() {
  local host="$1"; shift
  declare -A args; for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local username="${args[username]}"
  local home="${args[home]:-/home/$username}"
  local shell="${args[shell]:-/bin/bash}"
  local groups="${args[groups]:-}"
  local state="${args[state]:-create}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/users.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  # 🛡️ Validación
  if [[ "$become" != "true" && "$EUID" -ne 0 ]]; then
    echo "${tr[priv_required]:-❌ [users] Se requieren privilegios para gestionar usuarios. Usa 'become: true'.}"
    return 1
  fi

  if [[ -z "$username" ]]; then
    echo "${tr[missing_username]:-❌ [users] Falta el parámetro obligatorio 'username'}"
    return 1
  fi

  case "$state" in
    create)
      echo "${tr[enter_create]:-🔧 [users] Entrando en create}"
      if id "$username" &>/dev/null; then
        echo "$(render_msg "${tr[exists]}" "username=$username")"
        return 0
      fi
      if [[ -n "$groups" && "$groups" != "$username" ]]; then
        if ! getent group "$groups" &>/dev/null; then
          echo "$(render_msg "${tr[group_create]}" "groups=$groups")"
          $prefix groupadd "$groups"
        fi
      fi
      local cmd="$prefix useradd -m \"$username\" -s \"$shell\" -d \"$home\""
      [[ -n "$groups" ]] && cmd="$cmd -G \"$groups\""
      eval "$cmd" && echo "$(render_msg "${tr[created]}" "username=$username")"
      ;;
    modify)
      echo "${tr[enter_modify]:-🔧 [users] Entrando en modify}"
      if ! id "$username" &>/dev/null; then
        echo "$(render_msg "${tr[not_exists]}" "username=$username")"
        return 1
      fi
      local cmd="$prefix usermod \"$username\""
      [[ -n "$shell" ]] && cmd="$cmd -s \"$shell\""
      [[ -n "$home" ]] && cmd="$cmd -d \"$home\""
      [[ -n "$groups" ]] && cmd="$cmd -G \"$groups\""
      eval "$cmd" && echo "$(render_msg "${tr[modified]}" "username=$username")"
      ;;
    absent)
      echo "${tr[enter_absent]:-🔧 [users] Entrando en absent}"
      if ! id "$username" &>/dev/null; then
        echo "$(render_msg "${tr[already_deleted]}" "username=$username")"
        return 0
      fi
      eval "$prefix userdel -r \"$username\"" && echo "$(render_msg "${tr[deleted]}" "username=$username")"
      ;;
    *)
      echo "$(render_msg "${tr[unsupported_state]}" "state=$state")"
      return 1
      ;;
  esac
}

check_dependencies_users() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/users.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  local missing=()
  for cmd in id sudo; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [users] Todas las dependencias están presentes}"
  return 0
}
