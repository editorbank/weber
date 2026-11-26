#!/bin/sh
set -eu -o pipefail

APP_DIR="$(dirname $0)"
source $APP_DIR/s3lib.sh

TIMECODE=$(date +%Y%m%d%H%M%S)
WWW_LINK=/tmp/www
NEW_DIR="/tmp/www-${TIMECODE}"
TEMP_LINK="/tmp/www-${TIMECODE}.link.tmp"
UPDATED=0

cleanup() {
    rm -f "$TEMP_LINK"
    if [ "$UPDATED" -eq 0 ]; then
        rm -rf "$NEW_DIR"
    fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

CONTENT_PATH="$(realpath -m "${NEW_DIR}/${SERVICE_PATH}")"
s3exp "${S3_FILE}" "${CONTENT_PATH}" "${S3_UNPACK_TYPE}"

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
