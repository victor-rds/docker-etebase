FROM python:3.9.0-buster

LABEL maintainer="Victor R. Santos <victor-rds@users.noreply.github.com>"

ARG PUID=373
ARG PGID=373

ENV BASE_DIR /etebase
ENV DATA_DIR /data
ENV STATIC_ROOT $BASE_DIR/static
ENV MEDIA_ROOT $BASE_DIR/media

ENV ETEBASE_EASY_CONFIG_PATH $DATA_DIR/etebase-server.ini
ENV SECRET_FILE $DATA_DIR/secret.txt

ENV SERVER="http"
ENV PORT 3735

COPY --chown=${PUID}:${PGID} server /etebase

# OS packages and deps installation
# hadolint ignore=DL3008,DL3018
RUN set -e && \
    pip install -r $BASE_DIR/requirements.txt uwsgi daphne 'Twisted[tls,http2]'

# Etebase directories and user setup 
RUN set -e && \
    addgroup --system --gid ${PGID} etebase && \
    adduser --system --no-create-home --disabled-password \
    --gecos '' --home $BASE_DIR --ingroup etebase --uid ${PUID} etebase && \
    mkdir -p $DATA_DIR $STATIC_ROOT $MEDIA_ROOT && \
    chown -R ${PUID}:${PGID} $DATA_DIR $MEDIA_ROOT $STATIC_ROOT && \
    chmod 750 $DATA_DIR

COPY --chown=${PUID}:${PGID} context /

USER etebase:etebase

WORKDIR $BASE_DIR

# Etebase collect static
RUN set -e && \
    $BASE_DIR/manage.py collectstatic --no-input && \
    rm $BASE_DIR/secret.txt

EXPOSE 3735

ENTRYPOINT ["/entrypoint.sh"]