docker rm -f weber-test

docker run -d \
  --add-host=host.docker.internal:host-gateway \
  -e TZ="Europe/Moscow" \
  -e DEBUG="1" \
  -e NGINX_ACCESS_LOG="/dev/stdout" \
  -e S3_PROTOCOL="http" \
  -e S3_HOST="host.docker.internal" \
  -e S3_PORT="8888" \
  -e S3_BUCKET="bucket1" \
  -e S3_WWW_ZIP="dbt_docs.zip" \
  -e S3_ACCESS_KEY="S3_ACCESS_KEY" \
  -e S3_SECRET_KEY="S3_SECRET_KEY" \
  -e UPDATE_INTERVAL_MINUTES=5 \
  -e SERVICE_PATH="/dbt_docs/ift" \
  -e SERVICE_PORT=81 \
  -p 8080:81 \
  -u 11111 \
  --name weber-test \
  weber
