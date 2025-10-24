#!/bin/bash
# Module: ldap_ad
# Description: Realiza búsquedas filtradas en servidores Active Directory usando ldapsearch
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: ldapsearch

ldap_ad_task() {
  local host="$1"
  shift

  check_dependencies_ldap_ad || return 1

  local state="" server="" port="389" base_dn="" filter="" attributes="" bind_dn="" password=""
  for arg in "$@"; do
    case "$arg" in
      state=*) state="${arg#state=}" ;;
      server=*) server="${arg#server=}" ;;
      port=*) port="${arg#port=}" ;;
      base_dn=*) base_dn="${arg#base_dn=}" ;;
      filter=*) filter="${arg#filter=}" ;;
      attributes=*) attributes="${arg#attributes=}" ;;
      bind_dn=*) bind_dn="${arg#bind_dn=}" ;;
      password=*) password="${arg#password=}" ;;
    esac
  done

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/ldap_ad.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ "$state" != "search" ]]; then
    echo "$(render_msg "${tr[unsupported_state]}" "state=$state")"
    return 1
  fi

  if [[ -z "$server" || -z "$base_dn" || -z "$filter" ]]; then
    echo "${tr[missing_args]:-❌ [ldap_ad] Faltan argumentos obligatorios: server, base_dn, filter}"
    return 1
  fi

  echo "$(render_msg "${tr[connecting]}" "server=$server" "port=$port")"
  local cmd=(ldapsearch -LLL -H "$server" -p "$port" -b "$base_dn" "$filter")
  [[ -n "$bind_dn" && -n "$password" ]] && cmd=(-D "$bind_dn" -w "$password" "${cmd[@]}")
  [[ -n "$attributes" ]] && IFS=',' read -ra attr_list <<< "$attributes" && cmd+=("${attr_list[@]}")

  if "${cmd[@]}" 2>/tmp/ldap_ad_error.log | grep -E '^(dn:|cn:|mail:|sAMAccountName:)' ; then
    echo "${tr[success]:-✅ [ldap_ad] Búsqueda completada con éxito}"
  else
    echo "${tr[no_results]:-⚠️ [ldap_ad] No se encontraron resultados o hubo un error}"
    cat /tmp/ldap_ad_error.log
    return 1
  fi
}

check_dependencies_ldap_ad() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/ldap_ad.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if ! command -v ldapsearch &>/dev/null; then
    echo "${tr[missing_dep]:-❌ [ldap_ad] El comando 'ldapsearch' no está disponible}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [ldap_ad] Dependencias OK}"
  return 0
}
