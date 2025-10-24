#!/usr/bin/env bash
# Module: loop
# Description: Ejecuta un módulo sobre una lista o matriz de valores
# Author: Luis GuLo
# Version: 0.3.0
# Dependencies: echo, tee

loop_task() {
  local host="$1"; shift
  declare -A args
  local items_raw="" secondary_raw="" target_module=""
  local fail_fast="true"
  declare -A module_args

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/loop.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  # Parsear argumentos
  for arg in "$@"; do
    key="${arg%%=*}"
    value="${arg#*=}"
    case "$key" in
      items) items_raw="$value" ;;
      secondary) secondary_raw="$value" ;;
      module) target_module="$value" ;;
      fail_fast) fail_fast="$value" ;;
      *) module_args["$key"]="$value" ;;
    esac
  done

  if [[ -z "$items_raw" || -z "$target_module" ]]; then
    echo "${tr[missing_args]:-❌ [loop] Faltan argumentos obligatorios: items=... module=...}"
    return 1
  fi

  IFS=',' read -r -a items <<< "$items_raw"
  IFS=',' read -r -a secondary <<< "$secondary_raw"

  for item in "${items[@]}"; do
    if [[ "$item" == *:* ]]; then
      item_key="${item%%:*}"
      item_value="${item#*:}"
    else
      item_key="$item"
      item_value=""
    fi

    if [[ -n "$secondary_raw" ]]; then
      for sec in "${secondary[@]}"; do
        run_module "$host" "$target_module" "$item" "$item_key" "$item_value" "$sec" module_args || {
          echo "$(render_msg "${tr[fail_secondary]}" "item=$item" "secondary=$sec")"
          [[ "$fail_fast" == "true" ]] && return 1
        }
      done
    else
      run_module "$host" "$target_module" "$item" "$item_key" "$item_value" "" module_args || {
        echo "$(render_msg "${tr[fail_item]}" "item=$item")"
        [[ "$fail_fast" == "true" ]] && return 1
      }
    fi
  done
}

run_module() {
  local host="$1"
  local module="$2"
  local item="$3"
  local item_key="$4"
  local item_value="$5"
  local secondary_item="$6"
  declare -n args_ref="$7"

  local call_args=()
  for key in "${!args_ref[@]}"; do
    value="${args_ref[$key]}"
    value="${value//\{\{item\}\}/$item}"
    value="${value//\{\{item_key\}\}/$item_key}"
    value="${value//\{\{item_value\}\}/$item_value}"
    value="${value//\{\{secondary_item\}\}/$secondary_item}"
    call_args+=("$key=$value")
  done

  echo "🔁 [loop] → $module con item='$item' secondary='$secondary_item'"

  local PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  local MODULE_PATH=""
  local SEARCH_PATHS=("$PROJECT_ROOT/core/modules" "$PROJECT_ROOT/user_modules" "$PROJECT_ROOT/community_modules")
  for search_dir in "${SEARCH_PATHS[@]}"; do
    while IFS= read -r -d '' candidate; do
      [[ "$(basename "$candidate")" == "${module}.sh" ]] && MODULE_PATH="$candidate" && break 2
    done < <(find "$search_dir" -type f -name "${module}.sh" -print0)
  done

  if [[ -z "$MODULE_PATH" ]]; then
    echo "$(render_msg "${tr[module_not_found]}" "module=$module")"
    return 1
  fi

  source "$MODULE_PATH"
  ! declare -f "${module}_task" > /dev/null && echo "$(render_msg "${tr[task_not_found]}" "module=$module")" && return 1

  "${module}_task" "$host" "${call_args[@]}"
}

check_dependencies_loop() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/loop.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  local missing=()
  for cmd in echo tee; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [loop] Dependencias disponibles.}"
  return 0
}
