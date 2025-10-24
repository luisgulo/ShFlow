#!/usr/bin/env bash
# Module: facts
# Description: Extrae información del sistema con opciones de formato, filtrado y salida
# License: GPLv3
# Author: Luis GuLo
# Version: 1.4.0
# Dependencies: lscpu, ip, free, lsblk, uname, hostnamectl

facts_task() {
  local host="$1"; shift
  declare -A args
  local field="" format="plain" output="" append="false" host_label=""

  for arg in "$@"; do
    key="${arg%%=*}"; value="${arg#*=}"
    case "$key" in
      field) field="$value" ;;
      format) format="${value,,}" ;;
      output) output="$value" ;;
      append) append="$value" ;;
      host_label) host_label="$value" ;;
    esac
  done

  [[ -z "$host_label" ]] && host_label="$host"

  # 🌐 Cargar traducciones
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/facts.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then
    while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"
  fi

  local prefix=""
  [[ "$host" != "localhost" ]] && prefix="ssh $host"

  [[ "$DEBUG" == "true" ]] && echo "$(render_msg "${tr[debug_prefix]}" "prefix=$prefix")"

  local raw
  raw=$($prefix bash --noprofile --norc <<'EOF'
    cd /tmp || cd ~
    echo "hostname=$(hostname)"
    lscpu | awk '/^CPU\(s\):/ {print "cpu_count="$2}'
    free -m | awk '/Mem:/ {print "ram_total_mb="$2}'
    if command -v hostnamectl &> /dev/null; then
      hostnamectl | awk -F: '/Operating System/ {print "os_name=" $2}' | sed 's/^ *//'
      hostnamectl | awk -F: '/Kernel/ {print "os_version=" $2}' | sed 's/^ *//'
    else
      echo "os_name=$(uname -s)"
      echo "os_version=$(uname -r)"
    fi
    ip link show | awk -F: '/^[0-9]+: / {print $2}' | grep -Ev 'docker|virbr|lo|veth|br-' | while read -r dev; do
      ip=$(ip -4 addr show "$dev" | awk '/inet / {print $2}' | cut -d/ -f1)
      mac=$(ip link show "$dev" | awk '/ether/ {print $2}')
      [[ -n "$ip" || -n "$mac" ]] && echo "net_$dev=IP:$ip MAC:$mac"
    done
    ip -4 addr show | awk '/inet / {print $2}' | cut -d/ -f1 | paste -sd ' ' - | awk '{print "ip_addresses="$0}'
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep -Ev 'loop|tmpfs|overlay|docker' | awk 'NR>1 && NF>0 {print "partition_list=" $1 " " $2 " " $3 " " $4}'
EOF
)

  [[ -n "$field" ]] && raw=$(echo "$raw" | grep "^$field=")

  local partitions=() facts=()
  while IFS= read -r line; do
    [[ "$line" == partition_list=* ]] && partitions+=("${line#*=}") || facts+=("$line")
  done <<< "$raw"

  local formatted=""
  case "$format" in
    plain)
      formatted+="Host: $host_label\n"
      for f in "${facts[@]}"; do formatted+="${f%%=*}: ${f#*=}\n"; done
      [[ ${#partitions[@]} -gt 0 ]] && formatted+="partitions:\n" && for p in "${partitions[@]}"; do formatted+="  - $p\n"; done
      ;;
    md)
      formatted+="### $host_label\n"
      for f in "${facts[@]}"; do formatted+="- **${f%%=*}:** ${f#*=}\n"; done
      [[ ${#partitions[@]} -gt 0 ]] && formatted+="- **partitions:**\n" && for p in "${partitions[@]}"; do formatted+="  - $p\n"; done
      ;;
    kv)
      for f in "${facts[@]}"; do formatted+="$f\n"; done
      [[ ${#partitions[@]} -gt 0 ]] && formatted+="partitions=$(IFS=';'; echo "${partitions[*]}")\n"
      ;;
    json)
      local json="{"
      for f in "${facts[@]}"; do json+="\"${f%%=*}\":\"${f#*=}\","; done
      [[ ${#partitions[@]} -gt 0 ]] && json+="\"partitions\":[" && for p in "${partitions[@]}"; do json+="\"$p\","; done && json="${json%,}]" || json="${json%,}"
      json+="}"
      formatted="$json"
      ;;
    *)
      echo "$(render_msg "${tr[unsupported_format]}" "format=$format")"
      return 1
      ;;
  esac

  if [[ -n "$output" ]]; then
    [[ "$append" == "true" ]] && echo -e "$formatted" >> "$output" || echo -e "$formatted" > "$output"
    echo "$(render_msg "${tr[saved]}" "output=$output")"
  else
    echo -e "$formatted"
  fi
}

check_dependencies_facts() {
  local lang="${shflow_vars[language]:-es}"
  local trfile="$(dirname "${BASH_SOURCE[0]}")/facts.tr.${lang}"
  declare -A tr
  if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

  for cmd in lscpu ip free lsblk uname hostnamectl; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "$(render_msg "${tr[missing_cmd]}" "cmd=$cmd")"
    else
      echo "$(render_msg "${tr[cmd_ok]}" "cmd=$cmd")"
    fi
  done
  return 0
}
