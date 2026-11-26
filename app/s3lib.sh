APP_DIR="$(dirname $0)"
source $APP_DIR/loglib.sh

S3_PROTOCOL="${S3_PROTOCOL:-https}"
S3_HOST="${S3_HOST:-}"
S3_PORT="${S3_PORT:-443}"
S3_BUCKET="${S3_BUCKET:-}"
S3_FILE="${S3_FILE:-}"

S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"

S3_UNPACK_TYPE="${S3_UNPACK_TYPE:-auto}"
S3_CONNECT_TIMEOUT="${S3_CONNECT_TIMEOUT:-30}"
S3_MAX_TIME="${S3_MAX_TIME:-300}"
S3_CONTENT_TYPE=${S3_CONTENT_TYPE:-"application/octet-stream"}

[ -n "${S3_HOST}" ] || log_error "Undefined environment variable S3_HOST!"
[ -n "${S3_FILE}" ] || log_error "Undefined environment variable S3_FILE!"


s3_req() {
  resource="/${1:-}"
  method="${2:-GET}"
  shift 2

  [ -z "${S3_BUCKET}" ] || resource="/${S3_BUCKET}${resource}"
  date_time=$(date -R)
  signed_text="${method}\n\n${S3_CONTENT_TYPE}\n${date_time}\n${resource}"
  signature=$(echo -en "${signed_text}" | openssl sha1 -hmac "${S3_SECRET_KEY}" -binary | base64)
  url="${S3_PROTOCOL}://${S3_HOST}:${S3_PORT}${resource}"
  curl -k -s --connect-timeout "${S3_CONNECT_TIMEOUT}" --max-time "${S3_MAX_TIME}" \
    -X "${method}" "${url}" \
    -H "Date: ${date_time}" \
    -H "Content-Type: ${S3_CONTENT_TYPE}" \
    -H "Authorization: AWS ${S3_ACCESS_KEY}:${signature}" \
    "$@"
}


s3unzip() {
    destination_directory="${2:-.}"
    log_info "Get and unzip from S3 \"${S3_PROTOCOL}://${S3_HOST}:${S3_PORT}/${S3_BUCKET}/$1\" ..."
    temp_file="$destination_directory/$RANDOM$RANDOM.tmp"
    mkdir -p "${destination_directory}" \
        && s3_req "$1" GET -f -o "$temp_file" \
        && unzip -q -o "$temp_file" -d "${$destination_directory}" \
        && rm -f "$temp_file" \
        && log_info "OK" || log_error "Get and unzip from S3!"
}

s3untar() {
    destination_directory="${2:-.}"
    log_info "Get and untar from S3 \"${S3_PROTOCOL}://${S3_HOST}:${S3_PORT}/${S3_BUCKET}/$1\" ..."
    mkdir -p "${destination_directory}" \
        && s3_req "$1" GET -f | tar -xz -C "$destination_directory" -f - \
        && log_info "OK" || log_error "Get and untar from S3!"
}

s3get() {
    local_filename="${2:-$1}"
    destination_directory="$(dirname "$local_filename")"
    log_info "Get file \"$local_filename\" from S3 \"${S3_PROTOCOL}://${S3_HOST}:${S3_PORT}/${S3_BUCKET}/$1\" ..."
    mkdir -p "${destination_directory}" \
        && s3_req "$1" GET -f -o "$local_filename" \
        && log_info "OK" || log_error "Get from S3!"
}

s3put() {
    local_filename="${2:-$1}"
    log_info "Put file \"$local_filename\" to S3 \"${S3_PROTOCOL}://${S3_HOST}:${S3_PORT}/${S3_BUCKET}/$1\" ..."
    s3_req "$1" PUT -f --data-binary @"$local_filename" && log_info OK || log_error "Put to S3!"
}

s3exp() {
    s3_file="$1"
    content_path="$2"
    s3_unpack_type="${3:-auto}"

    if [ "auto" = "${s3_unpack_type}" ] ; then
        if [ "${s3_file}" != "${s3_file%".zip"}" ] ; then
            s3_unpack_type="zip"
        elif [ "${s3_file}" != "${s3_file%".tar"}" -o "${s3_file}" != "${s3_file%".tar.gz"}" -o "${s3_file}" != "${s3_file%".tar.gz"}" ] ; then
            s3_unpack_type="tar"
        else
            s3_unpack_type=""
        fi
    fi
    if [ -z "${s3_unpack_type}" ] ; then
        s3get "${s3_file}" "${content_path}/${s3_file}"
    elif [ "${s3_unpack_type}" = "zip" ] ; then
        s3unzip "${s3_file}" "${content_path}"
    elif [ "${s3_unpack_type}" = "tar" -o "${s3_unpack_type}" = "tgz" -o "${s3_unpack_type}" = "tar.gz" ] ; then
        s3untar "${s3_file}" "${content_path}"
    else
        log_error "\"${s3_unpack_type}\" is an invalid S3_UNPACK_TYPE!"
    fi
}
