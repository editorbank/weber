
log_info() {
  echo "$(date -Iseconds) $1"
}

log_error() {
  echo "$(date -Iseconds) Error: $1" 1>&2
  exit 1
}
