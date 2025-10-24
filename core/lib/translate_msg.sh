render_msg() {
  local template="$1"; shift
  for pair in "$@"; do
    local key="${pair%%=*}"
    local val="${pair#*=}"
    template="${template//\{$key\}/$val}"
  done
  echo "$template"
}
