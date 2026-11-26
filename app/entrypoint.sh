#!/bin/sh
set -eu -o pipefail
APP_DIR="$(dirname $0)"
source $APP_DIR/loglib.sh

log_info "Start ..."

DEBUG=${DEBUG:-}
UPDATE_VERSION="${UPDATE_VERSION:-}"
UPDATE_INTERVAL_MINUTES="${UPDATE_INTERVAL_MINUTES:-60}"
export SERVICE_PATH="${SERVICE_PATH:-}"
export SERVICE_PORT="${SERVICE_PORT:-8080}"
export NGINX_ERROR_LOG="${NGINX_ERROR_LOG:-/dev/stdout warn}"
export NGINX_ACCESS_LOG="${NGINX_ACCESS_LOG:-off}"
export NGINX_AUTH_REQUEST_URL="${NGINX_AUTH_REQUEST_URL:-http://127.0.0.1:$SERVICE_PORT/}"

case "$UPDATE_INTERVAL_MINUTES" in
    ''|*[!0-9]*) log_error "UPDATE_INTERVAL_MINUTES must be a positive integer" ;;
esac
if [ "$UPDATE_INTERVAL_MINUTES" -eq 0 ]; then
    log_error "UPDATE_INTERVAL_MINUTES must be a positive integer"
fi

mkdir -p /tmp/nginx/client_body \
         /tmp/nginx/proxy \
         /tmp/nginx/fastcgi \
         /tmp/nginx/uwsgi \
         /tmp/nginx/scgi

log_info "Rendering nginx.conf ..."
envsubst '$SERVICE_PATH $SERVICE_PORT $NGINX_ERROR_LOG $NGINX_ACCESS_LOG' < "/app/nginx.conf.template" > "/tmp/nginx/nginx.conf" 
if [ -n "$DEBUG" ] ; then
    log_info "Debug: Parts from nginx.conf: "
    cat "/tmp/nginx/nginx.conf" | grep -E 'listen|location|_log'
    log_info "Debug: Environments:"
    env|sort
fi

log_info "Update www-data ..."
$APP_DIR/update${UPDATE_VERSION}.sh

if [ "$UPDATE_INTERVAL_MINUTES" -ne 0 ]; then
    (
        while :; do
            sleep "$((UPDATE_INTERVAL_MINUTES * 60))"
            if ! $APP_DIR//update${UPDATE_VERSION}.sh; then
                log_info "Content update failed"
            fi
        done
    ) &
fi


log_info "Run nginx ..."
exec nginx -g 'daemon off;' -c "/tmp/nginx/nginx.conf" "$@"
