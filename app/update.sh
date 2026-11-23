#!/bin/sh
set -eu -o pipefail

[ -n "${S3_ACCESS_KEY}" -a -n "${S3_SECRET_KEY}" -a -n "${S3_HOST}" -a -n "${S3_BUCKET}" ] || \
    { 1>&2 echo "Error: Undefined need S3_* variables!" ; exit 1; }


s3_req() {
  object_key="$1"
  method="${2:-GET}"
  shift 2

  content_type="application/octet-stream"
  date_time=$(date -R)
  resource="/${S3_BUCKET}/${object_key}"
  signed_text="${method}\n\n${content_type}\n${date_time}\n${resource}"
  signature=$(echo -en "${signed_text}" | openssl sha1 -hmac "${S3_SECRET_KEY}" -binary | base64)

  url="${S3_PROTOCOL:-https}://${S3_HOST}:${S3_PORT:-443}${resource}"
  curl -k -s --connect-timeout "${S3_CONNECT_TIMEOUT:-10}" --max-time "${S3_MAX_TIME:-300}" \
    -X "${method}" "${url}" \
    -H "Date: ${date_time}" \
    -H "Content-Type: ${content_type}" \
    -H "Authorization: AWS ${S3_ACCESS_KEY}:${signature}" \
    "$@"
}


s3exp() {
    echo "Get and expand from S3 \"${S3_PROTOCOL:-https}://${S3_HOST}:${S3_PORT:-443}/${S3_BUCKET}/$1\" ..."
    s3_req "$1" GET -f | tar -xzf - && echo OK || { 1>&2 echo "Error: Get and  expand from S3!" ; exit 1; }
}

s3get() {
    local_filename="${2:-$1}"
    echo "Get file \"$local_filename\" from S3 \"${S3_PROTOCOL:-https}://${S3_HOST}:${S3_PORT:-443}/${S3_BUCKET}/$1\" ..."
    s3_req "$1" GET -f -o "$local_filename" && echo OK || { 1>&2 echo "Error: Get from S3!" ; exit 1; }
}

s3put() {
    local_filename="${2:-$1}"
    echo "Put file \"$local_filename\" to S3 \"${S3_PROTOCOL:-https}://${S3_HOST}:${S3_PORT:-443}/${S3_BUCKET}/$1\" ..."
    s3_req "$1" PUT -f --data-binary @"$local_filename" && echo OK || { 1>&2 echo "Error: Put to S3!" ; exit 1; }
}


TIMECODE=$(date +%Y%m%d%H%M%S)
WWW_LINK=/tmp/www
NEW_DIR="/tmp/www-${TIMECODE}"
ARCHIVE="/tmp/www-${TIMECODE}.zip"
TEMP_LINK=/tmp/www.link.$$
UPDATED=0

cleanup() {
    rm -f "$ARCHIVE" "$TEMP_LINK"
    if [ "$UPDATED" -eq 0 ]; then
        rm -rf "$NEW_DIR"
    fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM


s3get "$S3_WWW_ZIP" "$ARCHIVE"

CONTENT_PATH="$(realpath -m "${NEW_DIR}/${SERVICE_PATH}")"
mkdir -p "${CONTENT_PATH}"
unzip -q -o "$ARCHIVE" -d "${CONTENT_PATH}"

OLD_DIR=""
if [ -L "$WWW_LINK" ]; then
    OLD_DIR=$(readlink "$WWW_LINK")
    case "$OLD_DIR" in
        /*) ;;
        *) OLD_DIR=$(cd /tmp && readlink -f "$OLD_DIR") ;;
    esac
elif [ -d "$WWW_LINK" ]; then
    rm -rf "$WWW_LINK"
fi

ln -sfnT "$NEW_DIR" "$TEMP_LINK"
mv -Tf "$TEMP_LINK" "$WWW_LINK"
UPDATED=1

printf '%s\n' "$TIMECODE" > "${CONTENT_PATH}/last_update.txt"

case "$OLD_DIR" in
    /tmp/www-*)
        if [ "$OLD_DIR" != "$NEW_DIR" ] && [ -d "$OLD_DIR" ]; then
            rm -rf "$OLD_DIR"
        fi
        ;;
esac
