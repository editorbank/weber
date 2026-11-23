#!/bin/sh
set -eu -o pipefail

UPDATE_INTERVAL_MINUTES=${UPDATE_INTERVAL_MINUTES:-60}
UPDATE_VERSION=${UPDATE_VERSION:-}
export SERVICE_PATH=${SERVICE_PATH:-}
export SERVICE_PORT=${SERVICE_PORT:-8080}
export NGINX_ERROR_LOG=${NGINX_ERROR_LOG:-"/dev/stdout warn"}
export NGINX_ACCESS_LOG=${NGINX_ACCESS_LOG:-off}


case "$UPDATE_INTERVAL_MINUTES" in
    ''|*[!0-9]*) echo "UPDATE_INTERVAL_MINUTES must be a positive integer" >&2; exit 1 ;;
esac
if [ "$UPDATE_INTERVAL_MINUTES" -eq 0 ]; then
    echo "UPDATE_INTERVAL_MINUTES must be a positive integer" >&2
    exit 1
fi

mkdir -p /tmp/nginx/client_body \
         /tmp/nginx/proxy \
         /tmp/nginx/fastcgi \
         /tmp/nginx/uwsgi \
         /tmp/nginx/scgi
#chown -R www-data:www-data /tmp/nginx

if [ -n "$DEBUG" ] ; then
    echo "$(date -Iseconds) Parts from nginx.conf: "
    envsubst '$SERVICE_PATH $SERVICE_PORT $NGINX_ERROR_LOG $NGINX_ACCESS_LOG' < "/app/nginx.conf.template" > "/tmp/nginx/nginx.conf" 
    cat "/tmp/nginx/nginx.conf" | grep -E 'listen|location|_log'
    echo "$(date -Iseconds) Environments:"
    env|sort
fi

echo "$(date -Iseconds) Update www-data ..."
/app/update${UPDATE_VERSION}.sh

(
    while :; do
        sleep "$((UPDATE_INTERVAL_MINUTES * 60))"
        if ! /app/update${UPDATE_VERSION}.sh; then
            echo "$(date -Iseconds) Content update failed" >&2
        fi
    done
) &

echo "$(date -Iseconds) Run nginx ..."
exec nginx -g 'daemon off;' -c "/tmp/nginx/nginx.conf" "$@"
