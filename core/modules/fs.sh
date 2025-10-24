#!/usr/bin/env bash
# Module: fs
# Description: Operaciones remotas sobre ficheros (mover, renombrar, copiar, borrar, truncar)
# License: GPLv3
# Author: Luis GuLo
# Version: 1.3.0
# Dependencies: ssh

fs_task() {
  local host="$1"; shift
  declare -A args
  local files=()

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/fs.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  # Parseo de argumentos
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    if [[ "$key" == "files" ]]; then
      if [[ "$value" == *'*'* || "$value" == *'?'* || "$value" == *'['* ]]; then
        mapfile -t files < <(ssh "$host" "ls -1 $value 2>/dev/null")
      else
        IFS=',' read -r -a files <<< "$value"
      fi
    else
      args["$key"]="$value"
    fi
  done

  local action="${args[action]}"
  local src="${args[src]}"
  local dest="${args[dest]}"
  local path="${args[path]}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  case "$action" in
    move|rename|copy)
      if [[ ${#files[@]} -gt 0 ]]; then
        for file in "${files[@]}"; do
          base="$(basename "$file")"
          target="$dest/$base"
          cmd="$prefix mv"; [[ "$action" == "copy" ]] && cmd="$prefix cp"
          ssh "$host" "$cmd '$file' '$target'" && echo "$(render_msg "${tr[action_ok]}" "action=$action" "src=$file" "dest=$target")"
        done
      else
        cmd="$prefix mv"; [[ "$action" == "copy" ]] && cmd="$prefix cp"
        ssh "$host" "$cmd '$src' '$dest'" && echo "$(render_msg "${tr[action_ok]}" "action=$action" "src=$src" "dest=$dest")"
      fi
      ;;
    delete|truncate)
      if [[ ${#files[@]} -gt 0 ]]; then
        for file in "${files[@]}"; do
          cmd="$prefix rm -f"; [[ "$action" == "truncate" ]] && cmd="$prefix truncate -s 0"
          ssh "$host" "$cmd '$file'" && echo "$(render_msg "${tr[action_ok]}" "action=$action" "src=$file")"
        done
      else
        cmd="$prefix rm -f"; [[ "$action" == "truncate" ]] && cmd="$prefix truncate -s 0"
        ssh "$host" "$cmd '$path'" && echo "$(render_msg "${tr[action_ok]}" "action=$action" "src=$path")"
      fi
      ;;
    *)
      echo "$(render_msg "${tr[unsupported]}" "action=$action")"
      return 1
      ;;
  esac
}

check_dependencies_fs() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/fs.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  if ! command -v ssh &> /dev/null; then
    echo "${tr[missing_deps]:-❌ [fs] ssh no está disponible.}"
    return 1
  fi
  echo "${tr[deps_ok]:-✅ [fs] ssh disponible.}"
  return 0
}
