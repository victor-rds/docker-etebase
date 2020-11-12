FROM python:3.9.0-slim

LABEL maintainer="Victor R. Santos <victor-rds@users.noreply.github.com>"

ARG PUID=373
ARG PGID=373

ENV BASE_DIR /etebase
ENV DATA_DIR /data

ENV WEB_DIR /srv/etebase
ENV STATIC_ROOT $WEB_DIR/static
ENV MEDIA_ROOT $WEB_DIR/media

ENV ETEBASE_EASY_CONFIG_PATH $DATA_DIR/etebase-server.ini
ENV SECRET_FILE $DATA_DIR/secret.txt

ENV SERVER="http"
ENV PORT 3735

COPY --chown=${PUID}:${PGID} server /etebase

# OS packages and deps installation
# hadolint ignore=DL3008,DL3018
RUN set -e && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libffi6 libpq5 libssl1.1 && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential libffi-dev libpq-dev libssl-dev && \
    pip install -r $BASE_DIR/requirements.txt uwsgi daphne 'Twisted[tls,http2]' && \
    apt-get remove --purge -y build-essential libffi-dev libpq-dev libssl-dev && \
    apt-get autoremove --purge -y && \
    rm -rf /var/lib/apt/lists/*

# Etebase directories and user setup 
RUN set -e && \
    addgroup --system --gid ${PGID} etebase && \
    adduser --system --no-create-home --disabled-password \
    --gecos '' --home $BASE_DIR --ingroup etebase --uid ${PUID} etebase && \
    mkdir -p $DATA_DIR $WEB_DIR/static $WEB_DIR/media /etc/etebase-server && \
    ln -s ${ETEBASE_EASY_CONFIG_PATH} /etc/etebase-server/etebase-server.ini && \
    chown -R ${PUID}:${PGID} $DATA_DIR $WEB_DIR /etc/etebase-server && \
    chmod 750 $DATA_DIR && \
    $BASE_DIR/manage.py collectstatic --no-input && \
    rm $BASE_DIR/secret.txt

COPY --chown=${PUID}:${PGID} context /

USER etebase:etebase

WORKDIR $BASE_DIR

EXPOSE 3735

ENTRYPOINT ["/entrypoint.sh"]