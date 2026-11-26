ARG BASE_IMAGE=registry.astralinux.ru/library/astra/ubi18:latest
FROM ${BASE_IMAGE}

ARG SERVICE_PORT="8080"
ENV DEBIAN_FRONTEND=noninteractive \
    S3_PROTOCOL=https \
    S3_HOST="" \
    S3_PORT="443" \
    S3_BUCKET="" \
    S3_WWW_ZIP="" \
    S3_ACCESS_KEY="" \
    S3_SECRET_KEY="" \
    SERVICE_PORT="${SERVICE_PORT}" \
    UPDATE_INTERVAL_MINUTES=60

COPY . /
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        nginx \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && chmod 0755 /app/*.sh

EXPOSE ${SERVICE_PORT}

ENTRYPOINT ["/app/entrypoint.sh"]
