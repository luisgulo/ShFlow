#!/bin/bash
# License: GPLv3
# Module: docker
# Description: Gestiona contenedores Docker (run, stop, remove, build, exec)
# Author: Luis GuLo
# Version: 1.7.0
# Dependencies: ssh, docker

docker_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local action="${args[action]}"
  local become="${args[become]:-false}"
  local detach="${args[detach]:-true}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"
  local detached="-d"
  [ "$detach" = "false" ] && detached=""

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/docker.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  local name="" image="" path="" command=""
  case "$action" in present|stopped|absent|exec) name="${args[name]}" ;; esac
  case "$action" in present|build) image="${args[image]}" ;; esac
  [[ "$action" == "build" ]] && path="${args[path]}"
  [[ "$action" == "exec" ]] && command="${args[command]}"

  case "$action" in
    present)
      local extra="${args[run_args]:-${args[extra_args]:-}}"
      echo "$(render_msg "${tr[run]}" "name=$name" "image=$image")"
      ssh "$host" "$prefix docker ps -a --format '{{.Names}}' | grep -q '^$name$' || $prefix docker run $detached --name '$name' $extra '$image'"
      ;;
    stopped)
      echo "$(render_msg "${tr[stop]}" "name=$name")"
      ssh "$host" "$prefix docker ps --format '{{.Names}}' | grep -q '^$name$' && $prefix docker stop '$name'"
      ;;
    absent)
      echo "$(render_msg "${tr[remove]}" "name=$name")"
      ssh "$host" "$prefix docker ps -a --format '{{.Names}}' | grep -q '^$name$' && $prefix docker rm -f '$name'"
      ;;
    build)
      echo "$(render_msg "${tr[build]}" "image=$image" "path=$path")"
      ssh "$host" "cd '$path' && $prefix docker build -t '$image' ."
      ;;
    exec)
      echo "$(render_msg "${tr[exec]}" "name=$name" "command=$command")"
      ssh "$host" "$prefix docker exec '$name' $command"
      ;;
    *)
      echo "$(render_msg "${tr[unsupported]}" "action=$action")"
      return 1
      ;;
  esac
}

check_dependencies_docker() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/docker.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if ! command -v ssh &> /dev/null; then
    echo "${tr[missing_ssh]:-❌ [docker] ssh no está disponible.}"
    return 1
  fi
  echo "${tr[ssh_ok]:-✅ [docker] ssh disponible.}"

  if ! command -v docker &> /dev/null; then
    echo "${tr[missing_docker]:-⚠️ [docker] docker no disponible localmente. Se asumirá que existe en el host remoto.}"
  else
    echo "${tr[docker_ok]:-✅ [docker] docker disponible localmente.}"
  fi
  return 0
}
