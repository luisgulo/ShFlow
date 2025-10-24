#!/bin/bash
# Module: git
# Description: Gestiona repositorios Git en hosts remotos (clone, pull, checkout, fetch-file)
# License: GPLv3
# Author: Luis GuLo
# Version: 1.2.0
# Dependencies: ssh, git, curl, tar

git_task() {
  local host="$1"; shift
  declare -A args
  for arg in "$@"; do key="${arg%%=*}"; value="${arg#*=}"; args["$key"]="$value"; done

  local action="${args[action]}"
  local repo="${args[repo]}"
  local dest="${args[dest]}"
  local branch="${args[branch]}"
  local file_path="${args[file_path]}"
  local become="${args[become]}"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/git.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  case "$action" in
    clone)
      echo "$(render_msg "${tr[cloning]}" "repo=$repo" "dest=$dest")"
      ssh "$host" "[ -d '$dest/.git' ] || $prefix git clone '$repo' '$dest'"
      ;;
    pull)
      echo "$(render_msg "${tr[pulling]}" "dest=$dest")"
      ssh "$host" "[ -d '$dest/.git' ] && cd '$dest' && $prefix git pull"
      ;;
    checkout)
      echo "$(render_msg "${tr[checkout]}" "branch=$branch" "dest=$dest")"
      ssh "$host" "[ -d '$dest/.git' ] && cd '$dest' && $prefix git checkout '$branch'"
      ;;
    fetch-file)
      echo "$(render_msg "${tr[fetching]}" "file=$file_path" "repo=$repo" "branch=$branch")"
      fetch_file_from_repo "$host" "$repo" "$branch" "$file_path" "$dest" "$become"
      ;;
    *)
      echo "$(render_msg "${tr[unsupported]}" "action=$action")"
      return 1
      ;;
  esac
}

fetch_file_from_repo() {
  local host="$1"
  local repo="$2"
  local branch="$3"
  local file_path="$4"
  local dest="$5"
  local become="$6"
  local prefix=""
  [ "$become" = "true" ] && prefix="sudo"

  ssh "$host" "$prefix git archive --remote='$repo' '$branch' '$file_path' | $prefix tar -xO > '$dest'"
}

check_dependencies_git() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/git.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  local missing=()
  for cmd in ssh git curl tar; do
    command -v "$cmd" &> /dev/null || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$(render_msg "${tr[missing_deps]}" "cmds=${missing[*]}")"
    return 1
  fi

  echo "${tr[deps_ok]:-✅ [git] Todas las dependencias están disponibles}"
  return 0
}
