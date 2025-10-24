#!/usr/bin/env bash
# Module: api
# Description: Cliente declarativo para APIs REST y SOAP (GET, POST, PUT, DELETE, SOAP)
# License: GPLv3
# Author: Luis GuLo
# Version: 1.1.0
# Dependencies: curl, jq, xmllint

api_task() {
  local host="$1"; shift
  declare -A args
  local headers=()
  local method="" body="" url="" output="" parse=""

  for arg in "$@"; do
    key="${arg%%=*}"; value="${arg#*=}"
    case "$key" in
      headers) IFS=',' read -r -a headers <<< "$value" ;;
      body) body="$value" ;;
      url) url="$value" ;;
      method) method="${value,,}" ;;
      output) output="$value" ;;
      parse) parse="${value,,}" ;;
    esac
  done

  [[ -z "$method" ]] && method="get"
  [[ "$method" == "get" ]] && method="GET"
  [[ "$method" == "post" ]] && method="POST"
  [[ "$method" == "soap" ]] && method="POST"

  local header_args=""
  for h in "${headers[@]}"; do header_args+=" -H \"$h\""; done

  local curl_cmd="curl -sSL -X $method \"$url\"$header_args"
  [[ -n "$body" ]] && curl_cmd+=" --data-raw '$body'"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/api.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  echo "$(render_msg "${tr[start]}" "method=$method" "url=$url")"
  [[ "$DEBUG" == "true" ]] && echo "$(render_msg "${tr[debug_cmd]}" "cmd=$curl_cmd")"
  [[ "$DEBUG" == "true" && -n "$body" ]] && echo -e "$(render_msg "${tr[debug_body]}" "body=$body")"

  local response
  if [[ "$host" == "localhost" ]]; then
    response=$(eval "$curl_cmd")
  else
    response=$(ssh "$host" "$curl_cmd")
  fi

  if [[ -n "$output" ]]; then
    echo "$response" > "$output"
    echo "$(render_msg "${tr[saved]}" "output=$output")"
  fi

  case "$parse" in
    json)
      echo "$response" | jq '.' 2>/dev/null || echo "${tr[json_fail]:-⚠️ [api] No se pudo parsear como JSON}"
      ;;
    xml)
      echo "$response" | xmllint --format - 2>/dev/null || {
        echo "${tr[xml_fail]:-⚠️ [api] No se pudo parsear como XML}"
        echo "$response"
      }
      ;;
    *) echo "$response" ;;
  esac
}

check_dependencies_api() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/api.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  for cmd in curl jq xmllint; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "$(render_msg "${tr[missing_cmd]}" "cmd=$cmd")"
    else
      echo "$(render_msg "${tr[cmd_ok]}" "cmd=$cmd")"
    fi
  done
  return 0
}
