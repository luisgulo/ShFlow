#!/bin/bash
# Module: openssl
# Description: Gestiona certificados y claves con OpenSSL (convertir, inspeccionar, instalar como CA)
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: openssl, sudo, bash

openssl_task() {
  local host="$1"; shift
  check_dependencies_openssl || return 1

  local state="" src="" dest="" format="" password="" alias="" trust_path="" become="false"
  for arg in "$@"; do
    case "$arg" in
      state=*) state="${arg#state=}" ;;
      src=*) src="${arg#src=}" ;;
      dest=*) dest="${arg#dest=}" ;;
      format=*) format="${arg#format=}" ;;
      password=*) password="${arg#password=}" ;;
      alias=*) alias="${arg#alias=}" ;;
      trust_path=*) trust_path="${arg#trust_path=}" ;;
      become=*) become="${arg#become=}" ;;
    esac
  done

  local sudo_cmd=""
  [[ "$become" == "true" ]] && sudo_cmd="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/openssl.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  case "$state" in
    convert)
      if [[ -z "$src" || -z "$dest" || -z "$format" ]]; then
        echo "${tr[missing_convert]:-❌ [openssl] Faltan argumentos para conversión: src, dest, format}"
        return 1
      fi
      if [[ ! -f "$src" ]]; then
        echo "$(render_msg "${tr[src_not_found]}" "src=$src")"
        return 1
      fi
      echo "$(render_msg "${tr[converting]}" "src=$src" "format=$format")"

      case "$format" in
        pem)
          $sudo_cmd openssl pkcs12 -in "$src" -out "$dest" -nodes -password pass:"$password" && \
          echo "$(render_msg "${tr[converted]}" "dest=$dest")"
          ;;
        pfx)
          $sudo_cmd openssl pkcs12 -export -out "$dest" -inkey "$src" -in "$src" -password pass:"$password" && \
          echo "$(render_msg "${tr[converted]}" "dest=$dest")"
          ;;
        key)
          $sudo_cmd openssl pkey -in "$src" -out "$dest" && \
          echo "$(render_msg "${tr[key_extracted]}" "dest=$dest")"
          ;;
        cer)
          $sudo_cmd openssl x509 -in "$src" -out "$dest" -outform DER && \
          echo "$(render_msg "${tr[cer_converted]}" "dest=$dest")"
          ;;
        *)
          echo "$(render_msg "${tr[unsupported_format]}" "format=$format")"
          return 1
          ;;
      esac
      ;;

    inspect)
      if [[ -z "$src" || ! -f "$src" ]]; then
        echo "$(render_msg "${tr[missing_inspect]}" "src=$src")"
        return 1
      fi
      echo "$(render_msg "${tr[inspecting]}" "src=$src")"
      $sudo_cmd openssl x509 -in "$src" -noout -text | grep -E 'Subject:|Issuer:|Not Before:|Not After :|Fingerprint' || echo "${tr[inspect_fail]:-⚠️ [openssl] No se pudo extraer información}"
      ;;

    trust)
      if [[ -z "$src" || -z "$alias" || -z "$trust_path" ]]; then
        echo "${tr[missing_trust]:-❌ [openssl] Faltan argumentos para instalación como CA: src, alias, trust_path}"
        return 1
      fi
      if [[ ! -f "$src" ]]; then
        echo "$(render_msg "${tr[src_not_found]}" "src=$src")"
        return 1
      fi
      echo "$(render_msg "${tr[trusting]}" "alias=$alias")"
      $sudo_cmd cp "$src" "$trust_path/$alias.crt" && \
      $sudo_cmd update-ca-certificates && \
      echo "${tr[trusted]:-✅ [openssl] Certificado instalado y CA actualizada}"
      ;;

    untrust)
      if [[ -z "$alias" || -z "$trust_path" ]]; then
        echo "${tr[missing_untrust]:-❌ [openssl] Faltan argumentos para eliminación: alias, trust_path}"
        return 1
      fi
      local cert_path="$trust_path/$alias.crt"
      if [[ ! -f "$cert_path" ]]; then
        echo "$(render_msg "${tr[untrust_not_found]}" "alias=$alias" "trust_path=$trust_path")"
        return 0
      fi
      echo "$(render_msg "${tr[untrusting]}" "alias=$alias")"
      $sudo_cmd rm -f "$cert_path" && \
      $sudo_cmd update-ca-certificates && \
      echo "${tr[untrusted]:-✅ [openssl] Certificado eliminado y CA actualizada}"
      ;;

    *)
      echo "$(render_msg "${tr[unknown_state]}" "state=$state")"
      return 1
      ;;
  esac
}

check_dependencies_openssl() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/openssl.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  local missing=()
  for cmd in openssl sudo; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [openssl] Todas las dependencias están disponibles}"
  return 0
}
