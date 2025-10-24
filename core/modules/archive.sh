#!/usr/bin/env bash
# Module: archive
# Description: Comprime, descomprime y extrae archivos en remoto (tar, zip, gzip, bzip2)
# License: GPLv3
# Author: Luis GuLo
# Version: 1.6.0
# Dependencies: ssh, tar, gzip, bzip2, zip, unzip

archive_task() {
  local host="$1"; shift
  declare -A args
  local files=()

  for arg in "$@"; do
    key="${arg%%=*}"; value="${arg#*=}"
    [[ "$key" == "files" ]] && IFS=',' read -r -a files <<< "$value" || args["$key"]="$value"
  done

  local action="${args[action]}"
  local format="${args[format]:-tar}"
  local become="${args[become]:-false}"
  local prefix=""
  [[ "$become" == "true" ]] && prefix="sudo"

  local output="" archive="" dest=""
  case "$action" in
    compress) output="${args[output]}" ;;
    decompress|extract) archive="${args[archive]}"; dest="${args[dest]:-$(dirname "$archive")}" ;;
  esac

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/archive.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  if [[ "$action" == "extract" || "$action" == "decompress" ]]; then
    ssh "$host" "[ -d '$dest' ] || $prefix mkdir -p '$dest'" || {
      echo "$(render_msg "${tr[mkdir_fail]}" "dest=$dest")"
      return 1
    }
  fi

  case "$action" in
    compress)
      case "$format" in
        tar)
          ssh "$host" "$prefix tar -czf '$output' ${files[*]}" && echo "$(render_msg "${tr[compressed_tar]}" "output=$output")"
          ;;
        zip)
          ssh "$host" "$prefix zip -r '$output' ${files[*]}" && echo "$(render_msg "${tr[compressed_zip]}" "output=$output")"
          ;;
        gzip)
          for file in "${files[@]}"; do
            ssh "$host" "$prefix gzip -f '$file'" && echo "$(render_msg "${tr[compressed_gzip]}" "file=$file")"
          done
          ;;
        bzip2)
          for file in "${files[@]}"; do
            ssh "$host" "$prefix bzip2 -f '$file'" && echo "$(render_msg "${tr[compressed_bzip2]}" "file=$file")"
          done
          ;;
        *) echo "$(render_msg "${tr[unsupported_format]}" "format=$format")"; return 1 ;;
      esac
      ;;
    decompress)
      case "$format" in
        gzip)
          ssh "$host" "$prefix gunzip -f '$archive'" && echo "$(render_msg "${tr[decompressed_gzip]}" "archive=$archive")"
          ;;
        bzip2)
          ssh "$host" "$prefix bunzip2 -f '$archive'" && echo "$(render_msg "${tr[decompressed_bzip2]}" "archive=$archive")"
          ;;
        zip)
          ssh "$host" "$prefix unzip -o '$archive' -d '$dest'" && echo "$(render_msg "${tr[decompressed_zip]}" "dest=$dest")"
          ;;
        *) echo "$(render_msg "${tr[unsupported_format]}" "format=$format")"; return 1 ;;
      esac
      ;;
    extract)
      case "$format" in
        tar)
          if [[ ${#files[@]} -gt 0 ]]; then
            ssh "$host" "$prefix tar -xzf '$archive' -C '$dest' ${files[*]}" && echo "$(render_msg "${tr[extracted_tar]}" "dest=$dest")"
          else
            ssh "$host" "$prefix tar -xzf '$archive' -C '$dest'" && echo "$(render_msg "${tr[extracted_tar]}" "dest=$dest")"
          fi
          ;;
        zip)
          ssh "$host" "$prefix unzip -o '$archive' -d '$dest'" && echo "$(render_msg "${tr[extracted_zip]}" "dest=$dest")"
          ;;
        *) echo "$(render_msg "${tr[unsupported_format]}" "format=$format")"; return 1 ;;
      esac
      ;;
    *) echo "$(render_msg "${tr[unsupported_action]}" "action=$action")"; return 1 ;;
  esac
}

check_dependencies_archive() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/archive.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  for cmd in ssh tar gzip bzip2 zip unzip; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "$(render_msg "${tr[missing_cmd]}" "cmd=$cmd")"
    else
      echo "$(render_msg "${tr[cmd_ok]}" "cmd=$cmd")"
    fi
  done
  return 0
}
