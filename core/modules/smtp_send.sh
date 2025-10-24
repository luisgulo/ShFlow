#!/bin/bash
# Module: smtp_send
# Description: Envía un correo de prueba usando SMTP con netcat o openssl s_client
# License: GPLv3
# Author: Luis GuLo
# Version: 0.2.0
# Dependencies: nc o openssl, base64

smtp_send_task() {
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local smtp_server="${args[smtp_server]}"
  local smtp_port="${args[smtp_port]:-587}"
  local smtp_user="${args[smtp_user]}"
  local smtp_pass="${args[smtp_pass]}"
  local from="${args[from]}"
  local to="${args[to]}"
  local subject="${args[subject]:-Prueba desde ShFlow}"
  local body="${args[body]:-Este es un correo de prueba enviado desde el módulo smtp_send.}"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/smtp_send.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if [[ -z "$smtp_server" || -z "$smtp_user" || -z "$smtp_pass" || -z "$from" || -z "$to" ]]; then
    echo "${tr[missing_args]:-❌ [smtp_send] Faltan argumentos obligatorios: smtp_server, smtp_user, smtp_pass, from, to}"
    return 1
  fi

  echo "$(render_msg "${tr[start]}" "to=$to" "server=$smtp_server" "port=$smtp_port")"

  local auth_user auth_pass
  auth_user=$(echo -n "$smtp_user" | base64)
  auth_pass=$(echo -n "$smtp_pass" | base64)

  local smtp_script
  smtp_script=$(cat <<EOF
EHLO localhost
AUTH LOGIN
$auth_user
$auth_pass
MAIL FROM:<$from>
RCPT TO:<$to>
DATA
Subject: $subject
From: $from
To: $to

$body
.
QUIT
EOF
)

  if command -v nc &>/dev/null; then
    echo "${tr[using_nc]:-🔧 Usando netcat para conexión SMTP...}"
    echo "$smtp_script" | nc "$smtp_server" "$smtp_port"
  elif command -v openssl &>/dev/null; then
    echo "${tr[using_openssl]:-🔧 Usando openssl para conexión STARTTLS...}"
    echo "$smtp_script" | openssl s_client -starttls smtp -crlf -connect "$smtp_server:$smtp_port" 2>/dev/null
  else
    echo "${tr[missing_tools]:-❌ [smtp_send] No se encontró ni netcat (nc) ni openssl en el sistema.}"
    return 1
  fi

  echo "${tr[done]:-✅ [smtp_send] Comando ejecutado. Verifica si el correo fue recibido.}"
}

check_dependencies_smtp_send() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/smtp_send.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if command -v nc &>/dev/null || command -v openssl &>/dev/null; then
    if ! command -v base64 &>/dev/null; then
      echo "${tr[missing_base64]:-❌ [smtp_send] Falta base64 en el sistema.}"
      return 1
    fi
    local tool=$(command -v nc &>/dev/null && echo "nc" || echo "openssl")
    echo "$(render_msg "${tr[deps_ok]}" "tool=$tool")"
    return 0
  else
    echo "${tr[missing_tools]:-❌ [smtp_send] No se encontró ni nc ni openssl.}"
    return 1
  fi
}
