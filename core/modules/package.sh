#!/bin/bash
# Module: package
# Description: Instala, actualiza o elimina paquetes .deb/.rpm y permite actualizar el sistema
# License: GPLv3
# Author: Luis GuLo
# Version: 2.2.0
# Dependencies: ssh

package_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    args["$key"]="$value"
  done

  local name="${args[name]:-}"
  local state="${args[state]:-present}"
  local become="${args[become]:-false}"
  local update_type="${args[update_type]:-full}"  # full | security

  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/package.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r key val; do tr["$key"]="$val"; done < "$trfile"
  fi

  echo "$(render_msg "${tr[start]}" "state=$state" "name=${name:-<sistema>}")"

  local pkg_mgr
  pkg_mgr=$(ssh "$host" "command -v apt-get || command -v apt || command -v dnf || command -v yum")

  if [ -z "$pkg_mgr" ]; then
    echo "${tr[no_pkg_mgr]:-❌ [package] No se detectó gestor de paquetes compatible en el host.}"
    return 1
  fi

  case "$pkg_mgr" in
    *apt*)
      if [ "$state" = "system-update" ]; then
        system_update_apt "$host" "$prefix"
      else
        package_apt "$host" "$name" "$state" "$prefix"
      fi
      ;;
    *yum*|*dnf*)
      if [ "$state" = "system-update" ]; then
        system_update_rpm "$host" "$prefix" "$update_type"
      else
        package_rpm "$host" "$name" "$state" "$prefix"
      fi
      ;;
    *)
      echo "$(render_msg "${tr[unsupported_mgr]}" "mgr=$pkg_mgr")"
      return 1
      ;;
  esac
}

package_apt() {
  local host="$1"
  local name="$2"
  local state="$3"
  local prefix="$4"

  local check_cmd="dpkg -s '$name' &> /dev/null"
  local install_cmd="$prefix apt-get update && $prefix apt-get install -y '$name'"
  local remove_cmd="$prefix apt-get remove -y '$name'"
  local upgrade_cmd="$prefix apt-get update && $prefix apt-get install --only-upgrade -y '$name'"

  case "$state" in
    present) ssh "$host" "$check_cmd || $install_cmd" ;;
    absent)  ssh "$host" "$check_cmd && $remove_cmd" ;;
    latest)  ssh "$host" "$check_cmd && $upgrade_cmd || $install_cmd" ;;
    *) echo "$(render_msg "${tr[unsupported_state_apt]}" "state=$state")"; return 1 ;;
  esac
}

package_rpm() {
  local host="$1"
  local name="$2"
  local state="$3"
  local prefix="$4"

  local check_cmd="rpm -q '$name' &> /dev/null"
  local install_cmd="$prefix yum install -y '$name' || $prefix dnf install -y '$name'"
  local remove_cmd="$prefix yum remove -y '$name' || $prefix dnf remove -y '$name'"
  local upgrade_cmd="$prefix yum update -y '$name' || $prefix dnf upgrade -y '$name'"

  case "$state" in
    present) ssh "$host" "$check_cmd || $install_cmd" ;;
    absent)  ssh "$host" "$check_cmd && $remove_cmd" ;;
    latest)  ssh "$host" "$check_cmd && $upgrade_cmd || $install_cmd" ;;
    *) echo "$(render_msg "${tr[unsupported_state_rpm]}" "state=$state")"; return 1 ;;
  esac
}

system_update_apt() {
  local host="$1"
  local prefix="$2"
  echo "${tr[update_apt]:-🔄 [package] Actualización completa del sistema (.deb)}"
  ssh "$host" "$prefix apt-get update && $prefix apt-get upgrade -y"
}

system_update_rpm() {
  local host="$1"
  local prefix="$2"
  local update_type="$3"

  if [ "$update_type" = "security" ]; then
    echo "${tr[update_rpm_security]:-🔐 [package] Actualización de seguridad (.rpm)}"
    ssh "$host" "$prefix dnf update --security -y || $prefix yum update --security -y"
  else
    echo "${tr[update_rpm_full]:-🔄 [package] Actualización completa del sistema (.rpm)}"
    ssh "$host" "$prefix dnf upgrade --refresh -y || $prefix yum update -y"
  fi
}

check_dependencies_package() {
  if ! command -v ssh &> /dev/null; then
    echo "${tr[missing_deps]:-❌ [package] ssh no está disponible.}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [package] ssh disponible.}"
  return 0
}
