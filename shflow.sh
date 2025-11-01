#!/bin/bash
# ShFlow Playbook Runner
# License: GPLv3
# Author: Luis GuLo
# Version: 1.8.2

set -euo pipefail

# 📁 Rutas clave
PROJECT_ROOT="${SHFLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
INVENTORY="$PROJECT_ROOT/core/inventory/hosts.yaml"
VAULT_DIR="$PROJECT_ROOT/core/vault"
VAULT_KEY="${VAULT_KEY:-$HOME/.shflow.key}"

# 🌐 Cargar render_msg y traducciones
COMMON_LIB="$PROJECT_ROOT/core/lib/translate_msg.sh"
if ! declare -f render_msg &>/dev/null; then
  [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
fi

lang="${SHFLOW_LANG:-es}"
trfile="$PROJECT_ROOT/shflow.tr.${lang}"
declare -A tr
if [[ -f "$trfile" ]]; then while IFS='=' read -r k v; do tr["$k"]="$v"; done < "$trfile"; fi

# 🌀 Banner institucional
shflow_banner() {
  local banner=$(grep -E '^# Version:' "$0" | sed 's/^# Version:/ShFlow version:/')
  local padding="                                                     "
  echo "🌀 $banner$padding"
}
shflow_banner

# 🔧 Verbosidad y variables
SHFLOW_VERBOSITY=1
PLAYBOOK=""
HOST=""
GROUP=""
DEBUG=false
declare -A shflow_vars

# 📣 Trazas condicionales
echolog() {
  local level="$1"; shift
  local message="$*"
  local verbosity="${TASK_VERBOSITY:-$SHFLOW_VERBOSITY}"
  [[ "$verbosity" -ge "$level" ]] && echo "$message"
}

# 🔐 Resolución de secretos
resolve_vault_references() {
  local input="$1"
  local output="$input"
  local pattern='\{\{\s*vault\((["'\''])([^"'\''\)]+)\1\)\s*\}\}'
  while [[ "$output" =~ $pattern ]]; do
    local full="${BASH_REMATCH[0]}"
    local key="${BASH_REMATCH[2]}"
    local secret=""
    if [[ -f "$VAULT_DIR/$key.gpg" ]]; then
      secret=$(gpg --quiet --batch --yes --passphrase-file "$VAULT_KEY" -d "$VAULT_DIR/$key.gpg" 2>/dev/null || true)
    fi
    output="${output//$full/$secret}"
  done
  echo "$output"
}

# 🧠 Interpolación de argumentos
interpolate_args() {
  local raw="$1" host="$2" label="$3"
  local result="$raw"
  result="$(resolve_vault_references "$result")"
  result="${result//\{\{ name \}\}/$host}"
  result="${result//\{\{ label \}\}/$label}"
  for var in "${!shflow_vars[@]}"; do
    safe_value="${shflow_vars[$var]}"
    safe_value="${safe_value//$'\n'/\\n}"
    safe_value="${safe_value//$'\r'/\\r}"
    safe_value="${safe_value//$'\t'/\\t}"
    safe_value="${safe_value//$'\0'/ }"
    result="${result//\{\{ $var \}\}/$safe_value}"
  done
  echo "$result"
}

# 🧪 Validación de argumentos
if [[ $# -eq 0 ]]; then
  echo "${tr[no_args]:-❌ No se especificaron argumentos. Usa -f <archivo.yaml> y -h <host> o -g <grupo>}"
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file)
      [[ -z "${2:-}" || "${2:-}" == -* ]] && echo "${tr[missing_file]:-❌ Falta el nombre del archivo YAML tras $1}" && exit 1
      PLAYBOOK="$2"; shift 2 ;;
    -h|--host)
      [[ -z "${2:-}" || "${2:-}" == -* ]] && echo "${tr[missing_host]:-❌ Falta el nombre del host tras $1}" && exit 1
      HOST="$2"; shift 2 ;;
    -g|--group)
      [[ -z "${2:-}" || "${2:-}" == -* ]] && echo "${tr[missing_group]:-❌ Falta el nombre del grupo tras $1}" && exit 1
      GROUP="$2"; shift 2 ;;
    --quiet) SHFLOW_VERBOSITY=0; shift ;;
    --verbose) SHFLOW_VERBOSITY=2; shift ;;
    --debug) SHFLOW_VERBOSITY=3; DEBUG=true; shift ;;
    --version|version)
      echo "$(render_msg "${tr[version_path]:-Ubicación: {path}" "path=$(realpath "$0")")"
      exit 0 ;;
    --help)
      echo -e "${tr[help_header]:-ShFlow — Automatización ligera y extensible con Shell}\n"
      echo "${tr[help_usage]:-Uso: shflow -f <archivo.yaml> [-h <host> | -g <grupo>] [opciones]}"
      echo ""
      echo "${tr[help_options]:-Opciones:}"
      echo "${tr[help_opt_file]:-  -f, --file       Playbook YAML a ejecutar}"
      echo "${tr[help_opt_host]:-  -h, --host       Host individual del inventario}"
      echo "${tr[help_opt_group]:-  -g, --group      Grupo de hosts del inventario}"
      echo "${tr[help_opt_quiet]:-  --quiet          Silencia toda salida excepto errores}"
      echo "${tr[help_opt_verbose]:-  --verbose        Muestra trazas detalladas}"
      echo "${tr[help_opt_debug]:-  --debug          Modo depuración con trazas internas}"
      echo "${tr[help_opt_version]:-  --version        Muestra ubicación del ejecutable}"
      echo "${tr[help_opt_help]:-  --help           Muestra esta ayuda}"
      echo ""
      echo "${tr[help_example]:-Ejemplo:}"
      echo "${tr[help_example_cmd]:-  shflow -f tareas.yaml -g servidores --verbose}"
      exit 0 ;;
    *)
      $PROJECT_ROOT/core/utils/eg.sh "$@"
      echo "$(render_msg "${tr[unknown_option]:-❌ Opción desconocida: {opt}}" "opt=$1")"
      exit 1 ;;
  esac
done

# 📋 Validación de playbook
[ -z "$PLAYBOOK" ] && echo "${tr[no_playbook]:-❌ Playbook no especificado. Usa -f <archivo.yaml>}" && exit 1
[ ! -f "$PLAYBOOK" ] && echo "$(render_msg "${tr[playbook_not_found]:-❌ Playbook no encontrado: {file}}" "file=$PLAYBOOK")" && exit 1

TASKS_JSON=$(yq -r .tasks "$PLAYBOOK")
NUM_TASKS=$(echo "$TASKS_JSON" | jq 'length')
[ "$NUM_TASKS" -eq 0 ] && echo "${tr[no_tasks]:-❌ No se encontraron tareas en el playbook.}" && exit 1

# 🧠 Resolución de hosts
HOSTS=()
if [ -n "$HOST" ]; then
  HOSTS+=("$HOST")
elif [ -n "$GROUP" ]; then
  HOSTS_RAW=$(yq ".all.children.\"$GROUP\".hosts | keys | .[]" "$INVENTORY")
  [ -z "$HOSTS_RAW" ] && echo "$(render_msg "${tr[group_not_found]:-❌ Grupo '{group}' no encontrado en el inventario.}" "group=$GROUP")" && exit 1
  while IFS= read -r line; do HOSTS+=("$(echo "$line" | sed 's/^\"\(.*\)\"$/\1/')"); done <<< "$HOSTS_RAW"
else
  HOSTS_LINE=$(yq -r '.hosts // ""' "$PLAYBOOK")
  if [ -z "$HOSTS_LINE" ]; then
    HOSTGROUP=$(yq -r '.hostgroup // ""' "$PLAYBOOK")
    if [ -n "$HOSTGROUP" ]; then
      HOSTS_RAW=$(yq ".all.children.\"$HOSTGROUP\".hosts | keys | .[]" "$INVENTORY")
      [ -z "$HOSTS_RAW" ] && echo "$(render_msg "${tr[group_not_found]:-❌ Grupo '{group}' no encontrado en el inventario.}" "group=$HOSTGROUP")" && exit 1
      while IFS= read -r line; do HOSTS+=("$(echo "$line" | sed 's/^\"\(.*\)\"$/\1/')"); done <<< "$HOSTS_RAW"
    else
      echo "${tr[no_host_specified]:-❌ No se especificó ningún host. Usa -h, -g, 'hosts:' o 'hostgroup:' en el playbook.}"
      exit 1
    fi
  else
    IFS=',' read -ra HOSTS <<< "$HOSTS_LINE"
    for i in "${!HOSTS[@]}"; do HOSTS[$i]=$(echo "${HOSTS[$i]}" | xargs); done
  fi
fi

# 📦 Carga de variables globales
GLOBAL_VARS="$PROJECT_ROOT/core/inventory/vars/all.yaml"
if [[ -f "$GLOBAL_VARS" ]]; then
  GLOBAL_KEYS=$(yq -r 'keys[]' "$GLOBAL_VARS")
  for key in $GLOBAL_KEYS; do
    raw_value=$(yq -r ".\"$key\"" "$GLOBAL_VARS")
    resolved_value="$(resolve_vault_references "$raw_value")"
    shflow_vars["$key"]="$resolved_value"
  done
fi

# 📦 Carga de variables locales del playbook
VARS_KEYS=$(yq -r '.vars | keys[]' "$PLAYBOOK" 2>/dev/null || true)
for key in $VARS_KEYS; do
  raw_value=$(yq -r ".vars.\"$key\"" "$PLAYBOOK")
  resolved_value="$(resolve_vault_references "$raw_value")"
  shflow_vars["$key"]="$resolved_value"
done

# 👤 Usuario remoto
REMOTE_USER="${shflow_vars["remote_user"]:-$USER}"

# 🚀 Ejecución por host
run_for_host() {
  local CURRENT_HOST="$1"
  local HOST_IP LABEL
  local output_buffer=$(mktemp)

  {
    HOST_IP=$(yq ".all.hosts.\"$CURRENT_HOST\".ansible_host" "$INVENTORY" | sed 's/^\"\(.*\)\"$/\1/')
    LABEL=$(yq ".all.hosts.\"$CURRENT_HOST\".label" "$INVENTORY" | sed 's/^\"\(.*\)\"$/\1/')
    [[ "$HOST_IP" == "null" || -z "$HOST_IP" ]] && HOST_IP="$CURRENT_HOST"
    [[ "$LABEL" == "null" || -z "$LABEL" ]] && LABEL="$CURRENT_HOST"

    #echolog 1 "$(render_msg "${tr[host_info]:-🔧 Host: {host} ({ip})}" "host=$CURRENT_HOST" "ip=$HOST_IP")"
    #echolog 2 "$(render_msg "${tr[ssh_user]:-👤 Usuario SSH: {user}}" "user=$REMOTE_USER")"

    echo  "$(render_msg "${tr[host_info]:-🔧 Host: {host} ({ip})}" "host=$CURRENT_HOST" "ip=$HOST_IP")"
    echo "$(render_msg "${tr[ssh_user]:-👤 Usuario SSH: {user}}" "user=$REMOTE_USER")"

    for ((i=0; i<NUM_TASKS; i++)); do
      VERBOSITY_RAW=$(echo "$TASKS_JSON" | jq -r ".[$i].verbosity // empty")
      TASK_VERBOSITY="$SHFLOW_VERBOSITY"

      case "${VERBOSITY_RAW,,}" in
        quiet) TASK_VERBOSITY=0 ;;
        normal|default) TASK_VERBOSITY=1 ;;
        verbose) TASK_VERBOSITY=2 ;;
        debug) TASK_VERBOSITY=3 ;;
      esac

      NAME=$(echo "$TASKS_JSON" | jq -r ".[$i].name")
      MODULE=$(echo "$TASKS_JSON" | jq -r ".[$i].module")
      ARGS_RAW=$(echo "$TASKS_JSON" | jq -c ".[$i].args")
      COND_RAW=$(echo "$TASKS_JSON" | jq -r ".[$i].condition // \"\"")
      CAPTURE_LOG=$(echo "$TASKS_JSON" | jq -r ".[$i].capture_log // \"\"")
      CAPTURE_ERR=$(echo "$TASKS_JSON" | jq -r ".[$i].capture_err // \"\"")
      REGISTER=$(echo "$TASKS_JSON" | jq -r ".[$i].register // \"\"")

      if [ -n "$COND_RAW" ]; then
        COND_EVAL="$(resolve_vault_references "$COND_RAW")"
        for key in "${!shflow_vars[@]}"; do
          COND_EVAL="${COND_EVAL//\{\{ $key \}\}/${shflow_vars[$key]}}"
        done
        COND_EVAL="${COND_EVAL//\{\{ name \}\}/$CURRENT_HOST}"
        COND_EVAL="${COND_EVAL//\{\{ label \}\}/$LABEL}"

        if ! bash -c "$COND_EVAL"; then
          #echolog 2 "$(render_msg "${tr[task_skipped]:-⏭️  Tarea OMITIDA \"{name}\" por condición: {condition}}" "name=$NAME" "condition=$COND_EVAL")"
          echo "$(render_msg "${tr[task_skipped]:-⏭️  Tarea OMITIDA \"{name}\" por condición: {condition}}" "name=$NAME" "condition=$COND_EVAL")"
          continue
        else
          #echolog 2 "$(render_msg "${tr[condition_met]:-🔍 Condición cumplida: {condition}}" "condition=$COND_EVAL")"
          echo "$(render_msg "${tr[condition_met]:-🔍 Condición cumplida: {condition}}" "condition=$COND_EVAL")"
        fi
      fi

      #echolog 1 "$(render_msg "${tr[task_running]:-🔧 Ejecutando tarea: \"{name}\" (módulo: \"{module}\")}" "name=$NAME" "module=$MODULE")"
      echo "$(render_msg "${tr[task_running]:-🔧 Ejecutando tarea: \"{name}\" (módulo: \"{module}\")}" "name=$NAME" "module=$MODULE")"

      MODULE_PATH=""
      SEARCH_PATHS=("$PROJECT_ROOT/core/modules" "$PROJECT_ROOT/user_modules" "$PROJECT_ROOT/community_modules")
      for search_dir in "${SEARCH_PATHS[@]}"; do
        while IFS= read -r -d '' candidate; do
          [[ "$(basename "$candidate")" == "${MODULE}.sh" ]] && MODULE_PATH="$candidate" && break 2
        done < <(find "$search_dir" -type f -name "${MODULE}.sh" -print0)
      done

      [ -z "$MODULE_PATH" ] && echo "$(render_msg "${tr[module_not_found]:-❌ Módulo no encontrado: {module}.sh en rutas conocidas}" "module=$MODULE")" && continue
      source "$MODULE_PATH"
      ! declare -f "${MODULE}_task" > /dev/null && echo "$(render_msg "${tr[function_not_found]:-❌ Función '{function}' no encontrada en el módulo}" "function=${MODULE}_task")" && continue

      INTERPOLATED_ARGS="$(interpolate_args "$ARGS_RAW" "$CURRENT_HOST" "$LABEL")"
      ARG_KEYS=$(echo "$INTERPOLATED_ARGS" | jq -r 'keys[]')
      ARG_VALUES=()
      for key in $ARG_KEYS; do
        resolved=$(echo "$INTERPOLATED_ARGS" | jq -r ".[\"$key\"]")
        resolved=$(echo "$resolved" | sed 's/^\"\(.*\)\"$/\1/')
        ARG_VALUES+=("${key}=${resolved}")
      done

      for extra_key in become; do
        if [[ ! " ${ARG_KEYS[*]} " =~ " ${extra_key} " ]]; then
          value="${shflow_vars[$extra_key]:-}"
          [[ -n "$value" ]] && ARG_VALUES+=("${extra_key}=${value}")
        fi
      done

      local output exit_code
      set +e
      output=$("${MODULE}_task" "$REMOTE_USER@$HOST_IP" "${ARG_VALUES[@]}" 2>&1)
      exit_code=$?
      set -e

      [[ -n "$CAPTURE_LOG" ]] && shflow_vars["$CAPTURE_LOG"]="$output"
      [[ -n "$REGISTER" ]] && shflow_vars["$REGISTER"]="$output"
      [[ -n "$CAPTURE_ERR" ]] && shflow_vars["$CAPTURE_ERR"]="$exit_code"

      [[ -n "$CAPTURE_LOG" ]] && export "shflow_vars_${CAPTURE_LOG}=${shflow_vars[$CAPTURE_LOG]}"
      [[ -n "$REGISTER" ]] && export "shflow_vars_${REGISTER}=${shflow_vars[$REGISTER]}"
      [[ -n "$CAPTURE_ERR" ]] && export "shflow_vars_${CAPTURE_ERR}=${shflow_vars[$CAPTURE_ERR]}"

      echo "$output"
      [ "$exit_code" -ne 0 ] && echo "$(render_msg "${tr[task_failed]:-⚠️ Tarea '{name}' falló en host '{host}'}" "name=$NAME" "host=$CURRENT_HOST")"
      echo ""
    done
  } > "$output_buffer" 2>&1

  echo -e "\n🖥️ Host: $CURRENT_HOST\n$(cat "$output_buffer")"
  rm -f "$output_buffer"
}

PARALLELISM=false

# ⚙️ Ejecución paralela o secuencial
if [[ "$PARALLELISM" == "true" ]]; then
  for H in "${HOSTS[@]}"; do run_for_host "$H" & done
  wait
else
  for H in "${HOSTS[@]}"; do run_for_host "$H"; done
fi

# 🧹 Cierre defensivo
return 0 2>/dev/null || true
